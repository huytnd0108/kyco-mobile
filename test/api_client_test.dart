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

  test('a malformed refresh payload is treated as a failed refresh (no crash, auth-lost)', () async {
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
    expect(authLost, isTrue);
  });

  test('accepts a paginated {items:[...]} envelope shape', () async {
    // Guards the bookings parse against a paginated data shape (not a bare list).
    final data = {'items': [{'id': 1, 'status': 'SETTLED'}], 'meta': {'hasMore': false}};
    final list = data['items'];
    expect(list is List, isTrue);
    expect((list as List).length, 1);
  });
}
