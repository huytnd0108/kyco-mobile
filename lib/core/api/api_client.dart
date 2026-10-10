import 'dart:async';
import 'package:dio/dio.dart';

import '../config.dart';
import 'problem.dart';
import 'token_store.dart';

/// Signalled when the session can no longer be recovered (refresh failed /
/// revoked). The app listens and routes back to sign-in.
typedef OnAuthLost = void Function();

/// A meta-aware read result: the unwrapped `data` plus the envelope `meta`
/// (paging cursors, unread counts). `meta` is never null (empty map when absent).
class Envelope {
  const Envelope(this.data, this.meta);
  final dynamic data;
  final Map<String, dynamic> meta;
}

/// Low-level HTTP client for the kyco /api/v1 backend:
///  - attaches the Bearer access token,
///  - on 401, refreshes ONCE (single-flight) via /auth/refresh and retries,
///  - unwraps the `{ ok, data, meta }` envelope (throws ApiException on !ok),
///  - never loops: the refresh + retry are marked so a second 401 gives up.
class KycoApiClient {
  KycoApiClient(
      {required this.tokens, this.onAuthLost, this.acceptLanguage, Dio? dio, DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiBase,
              connectTimeout: AppConfig.requestTimeout,
              receiveTimeout: AppConfig.requestTimeout,
              // We validate status ourselves so error envelopes are parsed, not thrown raw.
              validateStatus: (_) => true,
              headers: {'accept': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _attachAuth));
  }

  final Dio _dio;
  final DateTime Function() _now;
  final TokenStore tokens;

  /// Refresh this long BEFORE the stored access expiry (clock skew + latency).
  static const Duration refreshSkew = Duration(seconds: 60);
  final OnAuthLost? onAuthLost;

  /// Resolves the language code ('vi'/'en') for the Accept-Language header so
  /// the backend returns content_translations in the app's active language.
  final String Function()? acceptLanguage;

  // Single-flight refresh: concurrent 401s share one in-flight refresh.
  Future<_RefreshResult>? _refreshing;

  Future<void> _attachAuth(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['noAuth'] != true) {
      await _refreshIfExpiring();
      final t = await tokens.accessToken;
      if (t != null) options.headers['authorization'] = 'Bearer $t';
    }
    options.headers['accept-language'] = acceptLanguage?.call() ?? 'vi';
    handler.next(options);
  }

  /// Proactive refresh (UX-M65): when the persisted access expiry is within
  /// [refreshSkew], refresh BEFORE sending, through the same single-flight as the
  /// 401 path. Best-effort: any failure (offline, rejected) is ignored here and
  /// the request goes out; the reactive 401 path then decides sign-out vs retry.
  Future<void> _refreshIfExpiring() async {
    try {
      final exp = await tokens.accessExpiresAt;
      if (exp == null) return;
      if (_now().toUtc().isBefore(exp.subtract(refreshSkew))) return;
      if ((await tokens.refreshToken) == null) return;
      await _refreshOnce();
    } catch (_) {/* never block the request on the proactive path */}
  }

  /// GET → unwrapped `data`. [auth] attaches the Bearer token + enables refresh.
  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  /// POST → unwrapped `data`.
  ///
  /// [idempotencyKey] is sent as the `Idempotency-Key` header (required by the
  /// backend on every money POST, MQA-36) and reused verbatim on the 401 →
  /// refresh → retry, so the retry replays rather than re-executes.
  Future<dynamic> post(String path, {Object? body, bool auth = true, String? idempotencyKey}) =>
      _send('POST', path, body: body, auth: auth, idempotencyKey: idempotencyKey);

  /// PUT → unwrapped `data`.
  Future<dynamic> put(String path, {Object? body, bool auth = true}) =>
      _send('PUT', path, body: body, auth: auth);

  /// PATCH → unwrapped `data`. Note: several kyco PATCH routes REPLACE every
  /// column (MQA-2) — callers must send the full object, never a partial.
  Future<dynamic> patch(String path, {Object? body, bool auth = true}) =>
      _send('PATCH', path, body: body, auth: auth);

  /// DELETE → unwrapped `data`.
  Future<dynamic> delete(String path, {bool auth = true}) => _send('DELETE', path, auth: auth);

  /// GET → the full `{data, meta}` envelope (for cursor-paged reads). Shares
  /// the same single-flight 401 → refresh → retry behaviour as [get].
  Future<Envelope> getWithMeta(String path,
          {Map<String, String>? query, bool auth = true}) =>
      _sendMeta('GET', path, query: query, auth: auth);

  /// GET a raw binary body (e.g. a `text/csv` export) — NOT the JSON envelope.
  /// Bearer-attached with the same single-flight 401 → refresh → retry as [get].
  /// Returns the response bytes; throws [ApiException] on a non-2xx status.
  Future<List<int>> getBytes(String path,
      {Map<String, dynamic>? query, bool auth = true, bool retried = false}) async {
    final Response<List<int>> res;
    try {
      res = await _dio.request<List<int>>(
        path,
        queryParameters: query,
        options: Options(
          method: 'GET',
          responseType: ResponseType.bytes,
          extra: {'noAuth': !auth},
        ),
      );
    } on DioException catch (e) {
      throw ApiException('network', e.message ?? 'Network error');
    }
    final status = res.statusCode ?? 0;
    if (status == 401 && auth) {
      if (await _recoverSession(retried)) {
        return getBytes(path, query: query, auth: auth, retried: true);
      }
    }
    if (status >= 200 && status < 300) return res.data ?? const <int>[];
    // Error bodies come back as bytes here; surface a generic typed failure.
    throw ApiException('http_$status', 'Request failed', status: status);
  }

  Future<Envelope> _sendMeta(String method, String path,
      {Map<String, dynamic>? query, Object? body, required bool auth, bool retried = false}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(method: method, extra: {'noAuth': !auth}),
      );
    } on DioException catch (e) {
      throw ApiException('network', e.message ?? 'Network error');
    }

    final status = res.statusCode ?? 0;
    final envelope = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;

    if (status == 401 && auth) {
      if (await _recoverSession(retried)) {
        // Dio FormData is single-use (finalized by the first send); rebuild it
        // for the retry so we don't hit StateError "already finalized".
        final retryBody = body is FormData ? body.clone() : body;
        return _sendMeta(method, path, query: query, body: retryBody, auth: auth, retried: true);
      }
    }

    if (status >= 200 && status < 300 && envelope?['ok'] == true) {
      final meta = envelope!['meta'];
      return Envelope(envelope['data'], meta is Map<String, dynamic> ? meta : const {});
    }
    throw ApiException.fromEnvelope(envelope, status, retryAfter: _retryAfter(res));
  }

  Future<dynamic> _send(String method, String path,
      {Map<String, dynamic>? query,
      Object? body,
      required bool auth,
      bool retried = false,
      String? idempotencyKey}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          extra: {'noAuth': !auth},
          headers: {'Idempotency-Key': ?idempotencyKey},
        ),
      );
    } on DioException catch (e) {
      throw ApiException('network', e.message ?? 'Network error');
    }

    final status = res.statusCode ?? 0;
    final envelope = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;

    // 401 on an authed call → refresh once, then retry once.
    if (status == 401 && auth) {
      if (await _recoverSession(retried)) {
        // Dio FormData is single-use (finalized by the first send); rebuild it
        // for the retry so we don't hit StateError "already finalized".
        final retryBody = body is FormData ? body.clone() : body;
        return _send(method, path,
            query: query, body: retryBody, auth: auth, retried: true, idempotencyKey: idempotencyKey);
      }
    }

    if (status >= 200 && status < 300 && envelope?['ok'] == true) {
      return envelope!['data'];
    }
    throw ApiException.fromEnvelope(envelope, status, retryAfter: _retryAfter(res));
  }

  /// `Retry-After` in whole seconds (the HTTP-date form is ignored).
  static Duration? _retryAfter(Response<dynamic> res) {
    final secs = int.tryParse(res.headers.value('retry-after')?.trim() ?? '');
    return secs == null || secs <= 0 ? null : Duration(seconds: secs);
  }

  /// After a 401 on an authed call: true = refreshed, retry the request once.
  ///
  /// False = the session is unrecoverable (the refresh was DEFINITIVELY
  /// rejected, or we already refreshed and STILL got 401: revoked / banned) —
  /// tokens are cleared and the app signs out; the caller then throws the 401.
  /// A TRANSIENT refresh failure (offline, timeout, 5xx, 429) keeps the tokens,
  /// does not sign out, and throws that retryable [ApiException] instead.
  Future<bool> _recoverSession(bool retried) async {
    if (!retried) {
      final r = await _refreshOnce();
      if (r.refreshed) return true;
      final transient = r.transientError;
      if (transient != null) throw transient;
    }
    await tokens.clear();
    onAuthLost?.call();
    return false;
  }

  /// Refresh the access token exactly once for any number of concurrent 401s.
  Future<_RefreshResult> _refreshOnce() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<_RefreshResult> _doRefresh() async {
    final refresh = await tokens.refreshToken;
    if (refresh == null) return const _RefreshResult.rejected();
    try {
      final res = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
        options: Options(extra: {'noAuth': true}),
      );
      final status = res.statusCode ?? 0;
      final env = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;
      if (status < 300 && env?['ok'] == true) {
        final data = env!['data'];
        final access = data is Map ? data['accessToken'] : null;
        if (access is! String || access.isEmpty) {
          // 2xx with an unusable payload: a server fault, not a revoked token.
          return _RefreshResult.transient(ApiException('UPSTREAM', 'Malformed refresh response', status: status));
        }
        final rotated = (data as Map)['refreshToken'];
        await tokens.save(access: access, refresh: rotated is String ? rotated : refresh);
        final ttl = data['expiresIn'];
        await tokens.setAccessExpiresAt(
            ttl is num && ttl > 0 ? _now().toUtc().add(Duration(seconds: ttl.toInt())) : null);
        return const _RefreshResult.refreshed();
      }
      // Definitive: the refresh token itself is rejected.
      if (status == 401 || status == 403 || env?['code'] == 'invalid_grant' || env?['error'] == 'invalid_grant') {
        return const _RefreshResult.rejected();
      }
      return _RefreshResult.transient(ApiException.fromEnvelope(env, status, retryAfter: _retryAfter(res)));
    } on DioException catch (e) {
      return _RefreshResult.transient(ApiException('network', e.message ?? 'Network error'));
    } catch (_) {
      return _RefreshResult.transient(ApiException('UPSTREAM', 'Refresh failed'));
    }
  }
}

/// Outcome of one `/auth/refresh` round trip.
class _RefreshResult {
  const _RefreshResult.refreshed()
      : refreshed = true,
        transientError = null;
  const _RefreshResult.rejected()
      : refreshed = false,
        transientError = null;
  const _RefreshResult.transient(ApiException this.transientError) : refreshed = false;

  final bool refreshed;

  /// Non-null = the refresh could not be decided (network / 5xx / 429): keep the session.
  final ApiException? transientError;
}
