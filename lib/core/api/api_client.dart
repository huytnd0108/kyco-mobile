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
  KycoApiClient({required this.tokens, this.onAuthLost, this.acceptLanguage, Dio? dio})
      : _dio = dio ??
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
  final TokenStore tokens;
  final OnAuthLost? onAuthLost;

  /// Resolves the language code ('vi'/'en') for the Accept-Language header so
  /// the backend returns content_translations in the app's active language.
  final String Function()? acceptLanguage;

  // Single-flight refresh: concurrent 401s share one in-flight refresh.
  Future<bool>? _refreshing;

  Future<void> _attachAuth(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.extra['noAuth'] != true) {
      final t = await tokens.accessToken;
      if (t != null) options.headers['authorization'] = 'Bearer $t';
    }
    options.headers['accept-language'] = acceptLanguage?.call() ?? 'vi';
    handler.next(options);
  }

  /// GET → unwrapped `data`. [auth] attaches the Bearer token + enables refresh.
  Future<dynamic> get(String path, {Map<String, dynamic>? query, bool auth = true}) =>
      _send('GET', path, query: query, auth: auth);

  /// POST → unwrapped `data`.
  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send('POST', path, body: body, auth: auth);

  /// PUT → unwrapped `data`.
  Future<dynamic> put(String path, {Object? body, bool auth = true}) =>
      _send('PUT', path, body: body, auth: auth);

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
      if (!retried && await _refreshOnce()) {
        return getBytes(path, query: query, auth: auth, retried: true);
      }
      await tokens.clear();
      onAuthLost?.call();
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
      if (!retried) {
        final ok = await _refreshOnce();
        if (ok) {
          return _sendMeta(method, path, query: query, body: body, auth: auth, retried: true);
        }
      }
      await tokens.clear();
      onAuthLost?.call();
    }

    if (status >= 200 && status < 300 && envelope?['ok'] == true) {
      final meta = envelope!['meta'];
      return Envelope(envelope['data'], meta is Map<String, dynamic> ? meta : const {});
    }
    throw ApiException.fromEnvelope(envelope, status);
  }

  Future<dynamic> _send(String method, String path,
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

    // 401 on an authed call → refresh once, then retry once.
    if (status == 401 && auth) {
      if (!retried) {
        final ok = await _refreshOnce();
        if (ok) {
          return _send(method, path, query: query, body: body, auth: auth, retried: true);
        }
      }
      // Either the refresh failed, or we already refreshed and STILL got 401
      // (session revoked / user banned) — unrecoverable: clear + sign out,
      // then throw the 401 below. Never keep churning refresh on a dead session.
      await tokens.clear();
      onAuthLost?.call();
    }

    if (status >= 200 && status < 300 && envelope?['ok'] == true) {
      return envelope!['data'];
    }
    throw ApiException.fromEnvelope(envelope, status);
  }

  /// Refresh the access token exactly once for any number of concurrent 401s.
  Future<bool> _refreshOnce() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = await tokens.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await _dio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': refresh},
        options: Options(extra: {'noAuth': true}),
      );
      final env = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : null;
      if ((res.statusCode ?? 0) < 300 && env?['ok'] == true) {
        final data = env!['data'] as Map<String, dynamic>;
        await tokens.save(
          access: data['accessToken'] as String,
          refresh: (data['refreshToken'] as String?) ?? refresh,
        );
        return true;
      }
    } catch (_) {
      // Any failure (network OR a differently-shaped refresh payload) → treat
      // the refresh as failed so callers fall into the clear + auth-lost path,
      // never leak a raw TypeError to requests awaiting the shared future.
    }
    return false;
  }
}
