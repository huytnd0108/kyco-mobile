// Wave C - UX-M63 error reporter (PII/token scrubbing, global hooks, release
// fallback widget) and UX-M65 (persisted expiry + proactive single-flight refresh).
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/error_reporter.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore;
import 'wave_c_support.dart';

const _jwt =
    'eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiI3IiwiZXhwIjoxNzAwMDAwMDAwfQ.c2lnbmF0dXJlLWJ5dGVzLWhlcmU';

void main() {
  group('UX-M63 ErrorReporter.scrub', () {
    test('removes bearer tokens and JWTs', () {
      final s = ErrorReporter.scrub('GET failed: Authorization: Bearer $_jwt trailing');
      expect(s, isNot(contains('eyJ')));
      expect(s, isNot(contains('c2lnbmF0')));
      expect(ErrorReporter.scrub('token=$_jwt'), isNot(contains('eyJ')));
    });
    test('removes refresh/access tokens in JSON and key=value forms', () {
      final s = ErrorReporter.scrub('{"refreshToken":"abcDEF123456","accessToken": "zzz999"} password=hunter2');
      expect(s, isNot(contains('abcDEF123456')));
      expect(s, isNot(contains('zzz999')));
      expect(s, isNot(contains('hunter2')));
      expect(s, contains('[redacted]'));
    });
    test('removes emails and VN phone numbers', () {
      final s = ErrorReporter.scrub('user ngoc.anh+x@gmail.com called 0912345678 / +84 912 345 678 / 84912345678');
      expect(s, isNot(contains('gmail')));
      expect(s, isNot(contains('0912345678')));
      expect(s, isNot(contains('912 345 678')));
      expect(s, isNot(contains('84912345678')));
      expect(s, contains('[email]'));
      expect(s, contains('[phone]'));
    });
    test('removes long hex secrets but keeps ordinary text and short numbers', () {
      final s = ErrorReporter.scrub('hash ${'a1b2c3d4' * 8} status 404 booking #1042');
      expect(s, isNot(contains('a1b2c3d4a1b2')));
      expect(s, contains('404'));
      expect(s, contains('#1042'));
    });
    test('report() funnels exactly one scrubbed line through the sink', () {
      final lines = <String>[];
      final r = ErrorReporter(sink: lines.add);
      r.report(Exception('boom Bearer $_jwt for a@b.vn'), StackTrace.fromString('#0 f (x:1)'), source: 'test');
      expect(lines, hasLength(1));
      expect(lines.single, contains('[kyco-error][test]'));
      expect(lines.single, isNot(contains('eyJ')));
      expect(lines.single, isNot(contains('a@b.vn')));
    });
    test('a throwing sink never escapes the reporter', () {
      final r = ErrorReporter(sink: (_) => throw StateError('sink down'));
      expect(() => r.report('x', null), returnsNormally);
    });
  });

  group('UX-M63 global wiring', () {
    late FlutterExceptionHandler? savedFlutter;
    late bool Function(Object, StackTrace)? savedPlatform;
    setUp(() {
      savedFlutter = FlutterError.onError;
      savedPlatform = PlatformDispatcher.instance.onError;
    });
    tearDown(() {
      FlutterError.onError = savedFlutter;
      PlatformDispatcher.instance.onError = savedPlatform;
    });

    test('FlutterError.onError and PlatformDispatcher.onError go through the reporter', () {
      final lines = <String>[];
      installGlobalErrorHandling(reporter: ErrorReporter(sink: lines.add));
      FlutterError.onError!(FlutterErrorDetails(exception: Exception('widget failed for 0912345678')));
      final handled = PlatformDispatcher.instance.onError!(StateError('async refreshToken=abc123456'), StackTrace.empty);
      expect(handled, isTrue, reason: 'async errors are handled, never crash the process');
      expect(lines, hasLength(2));
      expect(lines[0], contains('flutter'));
      expect(lines[0], isNot(contains('0912345678')));
      expect(lines[1], contains('platform,fatal'));
      expect(lines[1], isNot(contains('abc123456')));
    });

    testWidgets('release fallback replaces the red error screen with friendly copy', (t) async {
      final saved = ErrorWidget.builder;
      try {
        installErrorWidget(title: 'Đã xảy ra lỗi', body: 'Hãy thử lại', force: true);
        final w = ErrorWidget.builder(FlutterErrorDetails(exception: Exception('secret stack detail')));
        await t.pumpWidget(w);
        expect(find.text('Đã xảy ra lỗi'), findsOneWidget);
        expect(find.textContaining('secret'), findsNothing);
      } finally {
        ErrorWidget.builder = saved; // the binding verifies this before tearDown runs
      }
    });

    test('debug builds keep Flutter default unless forced', () {
      final saved = ErrorWidget.builder;
      installErrorWidget(title: 't', body: 'b'); // kReleaseMode == false in tests
      expect(identical(ErrorWidget.builder, saved), isTrue);
    });
  });

  group('UX-M65 proactive refresh', () {
    late Backend b;
    late InMemoryTokenStore tokens;
    late KycoApiClient client;
    var now = DateTime.utc(2026, 10, 10, 12);

    void build({DateTime? expiry, String refresh = 'r1'}) {
      b = Backend();
      tokens = InMemoryTokenStore()..save(access: 'old', refresh: refresh);
      tokens.setAccessExpiresAt(expiry);
      b.on('POST /auth/refresh', (o) => Backend.ok({'accessToken': 'new', 'refreshToken': 'r2', 'expiresIn': 900}));
      b.on('GET /me', (_) => Backend.ok({'id': 1, 'role': 'customer'}));
      final dio = Dio(BaseOptions(baseUrl: '', validateStatus: (_) => true))..httpClientAdapter = b;
      client = KycoApiClient(tokens: tokens, dio: dio, now: () => now);
    }

    String? authOf(RequestOptions o) => o.headers['authorization'] as String?;

    test('near expiry: refreshes BEFORE the request and sends the new token', () async {
      build(expiry: now.add(const Duration(seconds: 30)));
      await client.get('/me');
      expect(b.log.map((o) => o.path).toList(), ['/auth/refresh', '/me']);
      expect(authOf(b.log.last), 'Bearer new');
      expect(await tokens.refreshToken, 'r2', reason: 'rotated refresh token stored');
      expect(await tokens.accessExpiresAt, now.add(const Duration(seconds: 900)));
    });

    test('already expired: refreshes first too', () async {
      build(expiry: now.subtract(const Duration(minutes: 5)));
      await client.get('/me');
      expect(b.calls('POST /auth/refresh'), hasLength(1));
      expect(authOf(b.log.last), 'Bearer new');
    });

    test('plenty of time left: no refresh', () async {
      build(expiry: now.add(const Duration(minutes: 10)));
      await client.get('/me');
      expect(b.calls('POST /auth/refresh'), isEmpty);
      expect(authOf(b.log.single), 'Bearer old');
    });

    test('unknown expiry: no proactive refresh (reactive 401 path only)', () async {
      build(expiry: null);
      await client.get('/me');
      expect(b.calls('POST /auth/refresh'), isEmpty);
    });

    test('concurrent requests share ONE refresh (single-flight)', () async {
      build(expiry: now.subtract(const Duration(seconds: 1)));
      await Future.wait([client.get('/me'), client.get('/me'), client.get('/me')]);
      expect(b.calls('POST /auth/refresh'), hasLength(1));
      expect(b.calls('GET /me'), hasLength(3));
      expect(b.calls('GET /me').every((o) => authOf(o) == 'Bearer new'), isTrue);
    });

    test('the refresh call itself never triggers another proactive refresh', () async {
      build(expiry: now.subtract(const Duration(seconds: 1)));
      await client.get('/me');
      expect(b.calls('POST /auth/refresh'), hasLength(1));
    });

    test('proactive refresh failing (server down) does not block or sign out', () async {
      build(expiry: now.subtract(const Duration(seconds: 1)));
      b.on('POST /auth/refresh', (_) => Backend.err(503, 'MAINTENANCE'));
      var lost = 0;
      client = KycoApiClient(
          tokens: tokens,
          onAuthLost: () => lost++,
          dio: Dio(BaseOptions(baseUrl: '', validateStatus: (_) => true))..httpClientAdapter = b,
          now: () => now);
      final data = await client.get('/me');
      expect((data as Map)['id'], 1, reason: 'the request still went out');
      expect(lost, 0);
      expect(await tokens.refreshToken, 'r1', reason: 'tokens untouched');
    });

    test('login persists expiry from expiresIn; clear() forgets it', () async {
      build();
      b.on('POST /auth/login', (_) => Backend.ok({
            'accessToken': 'a1',
            'refreshToken': 'r9',
            'expiresIn': 900,
            'user': {'id': 1, 'role': 'customer'}
          }));
      final before = DateTime.now().toUtc();
      await KycoApi(client, tokens).login(email: 'a@b.vn', password: 'pw');
      final exp = (await tokens.accessExpiresAt)!;
      expect(exp.isAfter(before.add(const Duration(seconds: 890))), isTrue);
      expect(exp.isBefore(DateTime.now().toUtc().add(const Duration(seconds: 901))), isTrue);
      await tokens.clear();
      expect(await tokens.accessExpiresAt, isNull);
    });
  });
}
