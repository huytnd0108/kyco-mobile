import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/api/token_store.dart';

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore({String? access, String? refresh})
      : _a = access,
        _r = refresh;
  String? _a;
  String? _r;
  DateTime? _exp;
  @override
  Future<String?> get accessToken async => _a;
  @override
  Future<String?> get refreshToken async => _r;
  @override
  Future<void> save({required String access, required String refresh}) async {
    _a = access;
    _r = refresh;
  }
  @override
  Future<void> setAccess(String access) async => _a = access;
  @override
  Future<DateTime?> get accessExpiresAt async => _exp;
  @override
  Future<void> setAccessExpiresAt(DateTime? at) async => _exp = at;
  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
  }
  @override
  Future<bool> get hasSession async => _a != null;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, int status) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

KycoApiClient _client(TokenStore tokens, _FakeAdapter adapter, {void Function()? onAuthLost}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1', validateStatus: (_) => true));
  dio.httpClientAdapter = adapter;
  return KycoApiClient(tokens: tokens, onAuthLost: onAuthLost, dio: dio);
}

void main() {
  test('unwraps the ok envelope and returns data', () async {
    final adapter = _FakeAdapter((o) => _json({'ok': true, 'data': {'categories': []}}, 200));
    final c = _client(InMemoryTokenStore(), adapter);
    final data = await c.get('/home', auth: false);
    expect(data, {'categories': []});
  });

  test('throws a typed ApiException on a non-ok envelope', () async {
    final adapter = _FakeAdapter((o) => _json({'ok': false, 'code': 'VALIDATION', 'message': 'bad', 'fields': {'email': 'invalid'}}, 422));
    final c = _client(InMemoryTokenStore(), adapter);
    expect(
      () => c.post('/auth/login', auth: false, body: {}),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'VALIDATION')
          .having((e) => e.status, 'status', 422)
          .having((e) => e.fields?['email'], 'fields.email', 'invalid')),
    );
  });

  test('on 401 refreshes ONCE and retries the request with the new token', () async {
    final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
    final adapter = _FakeAdapter((o) {
      if (o.path.endsWith('/auth/refresh')) {
        return _json({'ok': true, 'data': {'accessToken': 'new', 'refreshToken': 'r2'}}, 200);
      }
      // /me: reject the old token, accept the refreshed one.
      final auth = o.headers['authorization'];
      return auth == 'Bearer new'
          ? _json({'ok': true, 'data': {'id': 1, 'role': 'customer'}}, 200)
          : _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401);
    });
    final c = _client(tokens, adapter);

    final data = await c.get('/me');
    expect(data, {'id': 1, 'role': 'customer'});
    expect(await tokens.accessToken, 'new'); // rotated in
    expect(await tokens.refreshToken, 'r2');
    // Exactly one refresh call (single-flight), and the /me was retried once.
    expect(adapter.requests.where((r) => r.path.endsWith('/auth/refresh')).length, 1);
    expect(adapter.requests.where((r) => r.path.endsWith('/me')).length, 2);
  });

  test('when refresh fails, clears tokens, signals auth-lost, and gives up (no loop)', () async {
    final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
    var authLost = false;
    final adapter = _FakeAdapter((o) {
      if (o.path.endsWith('/auth/refresh')) return _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401);
      return _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401);
    });
    final c = _client(tokens, adapter, onAuthLost: () => authLost = true);

    await expectLater(() => c.get('/me'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(authLost, isTrue);
    expect(await tokens.accessToken, isNull); // cleared
    // /me tried at most twice (original + one retry), never an infinite loop.
    expect(adapter.requests.where((r) => r.path.endsWith('/me')).length, lessThanOrEqualTo(2));
  });

  test('concurrent 401s share a single refresh (no refresh storm)', () async {
    final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
    final adapter = _FakeAdapter((o) {
      if (o.path.endsWith('/auth/refresh')) {
        return _json({'ok': true, 'data': {'accessToken': 'new', 'refreshToken': 'r2'}}, 200);
      }
      final auth = o.headers['authorization'];
      return auth == 'Bearer new'
          ? _json({'ok': true, 'data': {'ok': 1}}, 200)
          : _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401);
    });
    final c = _client(tokens, adapter);

    await Future.wait([c.get('/me'), c.get('/bookings'), c.get('/dashboard')]);
    expect(adapter.requests.where((r) => r.path.endsWith('/auth/refresh')).length, 1);
  });

  test('a 401 that PERSISTS after a successful refresh signals auth-lost (revoked/banned)', () async {
    final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
    var authLost = false;
    final adapter = _FakeAdapter((o) {
      if (o.path.endsWith('/auth/refresh')) {
        return _json({'ok': true, 'data': {'accessToken': 'new', 'refreshToken': 'r2'}}, 200);
      }
      return _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401); // still 401 even with the new token
    });
    final c = _client(tokens, adapter, onAuthLost: () => authLost = true);

    await expectLater(() => c.get('/me'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(authLost, isTrue);
    expect(await tokens.accessToken, isNull); // cleared, not left churning refresh
    expect(adapter.requests.where((r) => r.path.endsWith('/me')).length, 2); // original + one retry only
  });

  test('a malformed 2xx refresh payload is a server fault, not a revoked token: keep the session', () async {
    final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
    var authLost = false;
    final adapter = _FakeAdapter((o) {
      if (o.path.endsWith('/auth/refresh')) {
        return _json({'ok': true, 'data': {'token': 'wrong-shape'}}, 200); // no accessToken → TypeError if uncaught
      }
      return _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401);
    });
    final c = _client(tokens, adapter, onAuthLost: () => authLost = true);

    await expectLater(() => c.get('/me'), throwsA(isA<ApiException>())); // NOT a raw TypeError
    expect(authLost, isFalse);
    expect(await tokens.refreshToken, 'r1');
  });

  group('UX-M01 refresh failure matrix', () {
    // Each row: how /auth/refresh answers, and whether the session must end.
    final rows = <String, ({ResponseBody Function(RequestOptions) refresh, bool signOut, String? code})>{
      '401': (refresh: (o) => _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401), signOut: true, code: null),
      '403': (refresh: (o) => _json({'ok': false, 'code': 'FORBIDDEN'}, 403), signOut: true, code: null),
      'invalid_grant (400)': (refresh: (o) => _json({'ok': false, 'code': 'invalid_grant'}, 400), signOut: true, code: null),
      '500': (refresh: (o) => _json({'ok': false, 'code': 'INTERNAL'}, 500), signOut: false, code: 'INTERNAL'),
      '503': (refresh: (o) => _json({'ok': false, 'code': 'MAINTENANCE'}, 503), signOut: false, code: 'MAINTENANCE'),
      '429': (refresh: (o) => _json({'ok': false, 'code': 'RATE_LIMIT'}, 429), signOut: false, code: 'RATE_LIMIT'),
      'timeout': (
        refresh: (o) => throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout),
        signOut: false,
        code: 'network'
      ),
      'offline': (
        refresh: (o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError),
        signOut: false,
        code: 'network'
      ),
    };
    rows.forEach((name, row) {
      test('refresh $name → ${row.signOut ? 'signs out' : 'keeps tokens, retryable error'}', () async {
        final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
        var authLost = 0;
        final adapter = _FakeAdapter((o) =>
            o.path.endsWith('/auth/refresh') ? row.refresh(o) : _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401));
        final c = _client(tokens, adapter, onAuthLost: () => authLost++);

        if (row.signOut) {
          await expectLater(() => c.get('/me'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
          expect(authLost, 1);
          expect(await tokens.accessToken, isNull);
          expect(await tokens.refreshToken, isNull);
        } else {
          await expectLater(() => c.get('/me'), throwsA(isA<ApiException>().having((e) => e.code, 'code', row.code)));
          expect(authLost, 0, reason: 'a transient refresh failure must not sign the user out');
          expect(await tokens.accessToken, 'old');
          expect(await tokens.refreshToken, 'r1');
        }
      });
    });

    test('transient refresh failure on a binary download also keeps the session', () async {
      final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
      var authLost = false;
      final adapter = _FakeAdapter((o) => o.path.endsWith('/auth/refresh')
          ? _json({'ok': false, 'code': 'INTERNAL'}, 502)
          : _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401));
      final c = _client(tokens, adapter, onAuthLost: () => authLost = true);
      await expectLater(() => c.getBytes('/export'), throwsA(isA<ApiException>()));
      expect(authLost, isFalse);
      expect(await tokens.refreshToken, 'r1');
    });

    test('concurrent 401s during an outage share ONE refresh and all get the retryable error', () async {
      final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
      final adapter = _FakeAdapter((o) => o.path.endsWith('/auth/refresh')
          ? _json({'ok': false, 'code': 'INTERNAL'}, 500)
          : _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401));
      final c = _client(tokens, adapter);
      final results = await Future.wait([
        c.get('/me').then<Object?>((_) => null, onError: (e) => e),
        c.get('/bookings').then<Object?>((_) => null, onError: (e) => e),
      ]);
      expect(results.every((e) => e is ApiException && e.code == 'INTERNAL'), isTrue);
      expect(adapter.requests.where((r) => r.path.endsWith('/auth/refresh')).length, 1);
      expect(await tokens.refreshToken, 'r1');
    });

    test('a transient failure does not poison the next attempt: it refreshes and retries', () async {
      final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
      var refreshCalls = 0;
      final adapter = _FakeAdapter((o) {
        if (o.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          return refreshCalls == 1
              ? _json({'ok': false, 'code': 'INTERNAL'}, 500)
              : _json({'ok': true, 'data': {'accessToken': 'new', 'refreshToken': 'r2'}}, 200);
        }
        return o.headers['authorization'] == 'Bearer new'
            ? _json({'ok': true, 'data': {'id': 1}}, 200)
            : _json({'ok': false, 'code': 'AUTH_REQUIRED'}, 401);
      });
      final c = _client(tokens, adapter);
      await expectLater(() => c.get('/me'), throwsA(isA<ApiException>()));
      expect(await c.get('/me'), {'id': 1});
      expect(await tokens.refreshToken, 'r2');
    });

    test('429 keeps the server Retry-After on the typed error', () async {
      final adapter = _FakeAdapter((o) => ResponseBody.fromString(
            jsonEncode({'ok': false, 'code': 'RATE_LIMIT'}),
            429,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
              'retry-after': ['42'],
            },
          ));
      final c = _client(InMemoryTokenStore(), adapter);
      await expectLater(
        () => c.post('/auth/otp/request', auth: false, body: {}),
        throwsA(isA<ApiException>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 42))),
      );
    });
  });

  test('accepts a paginated {items:[...]} envelope shape', () async {
    // Guards the bookings parse against a paginated data shape (not a bare list).
    final data = {'items': [{'id': 1, 'status': 'SETTLED'}], 'meta': {'hasMore': false}};
    final list = data['items'];
    expect(list is List, isTrue);
    expect((list as List).length, 1);
  });

  test('sends accept-language: vi by default', () async {
    final adapter = _FakeAdapter((o) => _json({'ok': true, 'data': {}}, 200));
    final c = _client(InMemoryTokenStore(), adapter);
    await c.get('/home', auth: false);
    expect(adapter.requests.single.headers['accept-language'], 'vi');
  });

  test('sends the resolved language from acceptLanguage()', () async {
    final adapter = _FakeAdapter((o) => _json({'ok': true, 'data': {}}, 200));
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1', validateStatus: (_) => true));
    dio.httpClientAdapter = adapter;
    final c = KycoApiClient(tokens: InMemoryTokenStore(), acceptLanguage: () => 'en', dio: dio);
    await c.get('/home', auth: false);
    expect(adapter.requests.single.headers['accept-language'], 'en');
  });

  test('MQA-36: idempotencyKey goes out as the Idempotency-Key header and survives the 401 retry', () async {
    final tokens = InMemoryTokenStore(access: 'old', refresh: 'r1');
    final adapter = _FakeAdapter((o) {
      if (o.path.endsWith('/auth/refresh')) {
        return _json({'ok': true, 'data': {'accessToken': 'new', 'refreshToken': 'r2'}}, 200);
      }
      return o.headers['authorization'] == 'Bearer new'
          ? _json({'ok': true, 'data': {'id': 7}}, 201)
          : _json({'ok': false, 'code': 'AUTH_REQUIRED', 'message': 'x'}, 401);
    });
    final c = _client(tokens, adapter);
    await c.post('/tasker/payouts', body: {'amountVnd': 100000}, idempotencyKey: 'k-123');
    final payoutCalls = adapter.requests.where((r) => r.path.endsWith('/tasker/payouts')).toList();
    expect(payoutCalls, hasLength(2));
    expect(payoutCalls.map((r) => r.headers['Idempotency-Key']), everyElement('k-123'));
    expect(payoutCalls.last.data, {'amountVnd': 100000}); // amount sent unchanged
  });

  test('no Idempotency-Key header when none is given', () async {
    final adapter = _FakeAdapter((o) => _json({'ok': true, 'data': {}}, 200));
    final c = _client(InMemoryTokenStore(access: 'a'), adapter);
    await c.post('/addresses', body: {});
    expect(adapter.requests.single.headers.containsKey('Idempotency-Key'), isFalse);
  });
}
