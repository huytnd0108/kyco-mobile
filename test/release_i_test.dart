// Backend release-i (kyco 4f36881d): consent contract + tasker cancel preview.
// Fixtures in test/fixtures/release_i are written from the DTO code (authed
// routes cannot be captured anonymously; /v1/legal was also read live, 200):
//   GET /v1/legal            app/api/v1/legal/route.ts:15-29
//   consent decision/422s    lib/legal/consent.ts:68-95 (+ consentFromForm :48)
//   /v1/me `consents`        lib/legal/consent.ts:104-128, lib/profile/read.ts:32,65
//   POST /v1/me/consents     app/api/v1/me/consents/route.ts:15-28, consent.ts:131
//   signup bodies            app/api/v1/auth/signup/route.ts:25, signup/quick/route.ts:19-30
//   cancel preview DTO       lib/tasker/tasker-cancel-assess.ts:81-172
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show BaseOptions, Dio, FormData;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/auth/signup_screen.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore;
import 'wave_c_support.dart';

dynamic _fx(String name) => jsonDecode(File('test/fixtures/release_i/$name').readAsStringSync());
Map<String, dynamic> _map(String name) => _fx(name) as Map<String, dynamic>;

KycoApi _api(Backend b) {
  final tokens = InMemoryTokenStore();
  final client = KycoApiClient(tokens: tokens, dio: _dio(b));
  return KycoApi(client, tokens);
}

Dio _dio(Backend b) => Dio(BaseOptions(baseUrl: '', validateStatus: (_) => true))..httpClientAdapter = b;

void main() {
  group('models', () {
    test('LegalInfo parses the live /v1/legal body; only https URLs are kept', () {
      final l = LegalInfo.tryParse(_map('legal.json'))!;
      expect((l.termsVersion, l.privacyVersion, l.consentRequired), ('2026-05-24', '2026-05-24', true));
      expect(l.termsUrl.toString(), 'https://kyco.vn/vi/legal/terms');
      final odd = LegalInfo.tryParse({
        ..._map('legal.json'),
        'termsUrl': 'javascript:alert(1)',
        'privacyUrl': 'http://kyco.vn/vi/legal/privacy',
      })!;
      expect((odd.termsUrl, odd.privacyUrl), (null, null));
      expect(LegalInfo.tryParse({'termsVersion': ''}), isNull);
      expect(LegalInfo.tryParse(null), isNull);
    });

    test('ConsentPayload is exactly {terms, privacy, version} / consent_* form fields', () {
      final p = ConsentPayload.forLegal(LegalInfo.tryParse(_map('legal.json')))!;
      expect(jsonEncode(p.toJson()), '{"terms":true,"privacy":true,"version":"2026-05-24"}');
      expect(p.toFormFields(),
          {'consent_terms': '1', 'consent_privacy': '1', 'consent_version': '2026-05-24'});
      expect(ConsentPayload.forLegal(null), isNull);
    });

    test('diverging versions: signup/quick/become send MIN, re-consent sends MAX; bad format sends nothing', () {
      const l = LegalInfo(termsVersion: '2026-06-01', privacyVersion: '2026-05-24');
      final p = ConsentPayload.forLegal(l)!;
      expect(p.version, '2026-05-24');
      expect(p.toFormFields()['consent_version'], '2026-05-24');
      expect(jsonEncode(p.toJson()), '{"terms":true,"privacy":true,"version":"2026-05-24"}');
      const flipped = LegalInfo(termsVersion: '2026-05-24', privacyVersion: '2026-06-01');
      expect(ConsentPayload.forLegal(flipped)!.version, '2026-05-24');
      expect(
          const ConsentStatus(currentTermsVersion: '2026-06-01', currentPrivacyVersion: '2026-05-24').acceptVersion,
          '2026-06-01');
      expect(ConsentPayload.forLegal(const LegalInfo(termsVersion: 'v2', privacyVersion: '2026-05-24')), isNull);
    });

    test('/me consents: needsReconsent + the accept version; absent on an older backend', () {
      final u = AuthUser.fromJson(_map('me_needs_reconsent.json'));
      expect(u.needsReconsent, isTrue);
      expect(u.consents!.termsVersion, isNull);
      expect(u.consents!.acceptVersion, '2026-05-24');
      expect(AuthUser.fromJson(_map('me_consented.json')).needsReconsent, isFalse);
      expect(AuthUser.fromJson({'id': 1, 'role': 'customer'}).needsReconsent, isFalse);
      // The server requires max(terms, privacy) on POST /me/consents.
      expect(
          const ConsentStatus(currentTermsVersion: '2026-05-24', currentPrivacyVersion: '2026-07-01').acceptVersion,
          '2026-07-01');
    });
  });

  group('consent payload is sent ONLY when GET /v1/legal is 200', () {
    Future<Backend> submitSignup(WidgetTester t, {required Backend b}) async {
      useTallView(t);
      b.on('POST /auth/signup', (_) => Backend.ok({
            'accessToken': 'a',
            'refreshToken': 'r',
            'expiresIn': 900,
            'user': {'id': 7, 'role': 'customer', 'name': 'Lan', 'locale': 'vi'},
          }, status: 201));
      final h = await harness(auth: const AuthState(status: AuthStatus.signedOut), backend: b);
      await t.pumpWidget(routerWith(h, '/signup', {
        '/signup': (_) => const SignupScreen(),
        '/': (_) => const Scaffold(body: Text('home')),
      }));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, vi.email), 'lan@kyco.vn');
      await t.enterText(find.widgetWithText(TextFormField, vi.password), 'secret-123');
      await t.enterText(find.widgetWithText(TextFormField, vi.fullName), 'Lan');
      // The box stays required whatever the server supports.
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, vi.createAccount)).onPressed, isNull);
      await t.tap(find.byKey(const ValueKey('consent-checkbox')));
      await t.pump();
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, vi.createAccount)).onPressed, isNotNull);
      await t.tap(find.widgetWithText(FilledButton, vi.createAccount));
      await t.pumpAndSettle();
      return b;
    }

    testWidgets('signup, legal 200: body.consent == {terms:true, privacy:true, version:<termsVersion>}', (t) async {
      final b = await submitSignup(t, b: Backend()..on('GET /legal', (_) => Backend.ok(_map('legal.json'))));
      final body = b.calls('POST /auth/signup').single.data as Map;
      expect(body['consent'], {'terms': true, 'privacy': true, 'version': '2026-05-24'});
      expect(jsonEncode(body['consent']), '{"terms":true,"privacy":true,"version":"2026-05-24"}');
      expect(body.keys.toSet(), {'email', 'password', 'name', 'consent'});
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('signup, legal 404 (older backend): the consent key is never sent', (t) async {
      final b = await submitSignup(t, b: Backend()); // GET /legal -> 404 NOT_FOUND
      expect(b.calls('GET /legal'), isNotEmpty);
      expect((b.calls('POST /auth/signup').single.data as Map).containsKey('consent'), isFalse);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('signup, legal unreachable: retried once, then sent WITHOUT consent', (t) async {
      final b = await submitSignup(t, b: Backend()..on('GET /legal', (_) => throw StateError('offline')));
      expect(b.calls('GET /legal'), hasLength(greaterThanOrEqualTo(2)));
      expect((b.calls('POST /auth/signup').single.data as Map).containsKey('consent'), isFalse);
    });

    testWidgets('signup, legal 5xx: also omitted (the server did not advertise support)', (t) async {
      final b = await submitSignup(t, b: Backend()..on('GET /legal', (_) => Backend.err(503, 'MAINTENANCE')));
      expect((b.calls('POST /auth/signup').single.data as Map).containsKey('consent'), isFalse);
    });

    test('quick signup body: consent only when given, exact shape', () async {
      final b = Backend()..on('POST /signup/quick', (_) => Backend.ok({'email': 'a@b.vn'}, status: 201));
      final api = _api(b);
      await api.quickSignup(
          phone: '0912345678',
          email: 'a@b.vn',
          password: 'secret-123',
          name: 'Lan',
          consent: ConsentPayload.forLegal(LegalInfo.tryParse(_map('legal.json'))));
      await api.quickSignup(phone: '0912345678', email: 'a@b.vn', password: 'secret-123', name: 'Lan');
      final calls = b.calls('POST /signup/quick').toList();
      expect(calls[0].data, {
        'phone': '0912345678',
        'email': 'a@b.vn',
        'password': 'secret-123',
        'name': 'Lan',
        'consent': {'terms': true, 'privacy': true, 'version': '2026-05-24'},
      });
      expect((calls[1].data as Map).containsKey('consent'), isFalse);
    });

    test('api.legal(): 200 -> info, 404 -> null, other failures rethrow', () async {
      final b = Backend()..on('GET /legal', (_) => Backend.ok(_map('legal.json')));
      expect((await _api(b).legal())!.termsVersion, '2026-05-24');
      expect(await _api(Backend()).legal(), isNull);
      b.on('GET /legal', (_) => Backend.err(500, 'INTERNAL'));
      await expectLater(_api(b).legal(), throwsA(isA<Object>()));
    });

    test('become-tasker form: fields only when a payload is given', () async {
      final b = Backend()..on('POST /become-tasker', (_) => Backend.ok({'userId': 3}, status: 201));
      final api = _api(b);
      Future<void> call(ConsentPayload? c) => api.becomeTasker(
          phone: '0912345678', otpCode: '123456', name: 'Lan', city: 'HCM', district: 'Q1', files: const [], consent: c);
      await call(ConsentPayload.forLegal(LegalInfo.tryParse(_map('legal.json'))));
      await call(null);
      final forms = [for (final o in b.calls('POST /become-tasker')) (o.data as FormData).fields];
      expect({for (final e in forms[0]) e.key: e.value}['consent_version'], '2026-05-24');
      expect(forms[1].where((e) => e.key.startsWith('consent')), isEmpty);
    });
  });

  group('consent links', () {
    Future<List<Uri>> tapLinks(WidgetTester t, Backend b, {Locale locale = const Locale('vi')}) async {
      useTallView(t);
      final opened = <Uri>[];
      final h = await harness(
          auth: const AuthState(status: AuthStatus.signedOut),
          backend: b,
          opener: (u) async {
            opened.add(u);
            return true;
          });
      await t.pumpWidget(appWith(h, const SignupScreen(), locale: locale));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('consent-terms-link')));
      await t.tap(find.byKey(const ValueKey('consent-privacy-link')));
      return opened;
    }

    testWidgets('legal 200: the server termsUrl / privacyUrl are opened', (t) async {
      final opened = await tapLinks(t, Backend()..on('GET /legal', (_) => Backend.ok(_map('legal.json'))));
      expect(opened.map((u) => u.toString()), ['https://kyco.vn/vi/legal/terms', 'https://kyco.vn/vi/legal/privacy']);
    });

    testWidgets('no URL from the server (404 / http / absent): the web paths', (t) async {
      expect((await tapLinks(t, Backend())).map((u) => u.path), ['/vi/legal/terms', '/vi/legal/privacy']);
      await t.pumpWidget(const SizedBox());
      final noUrl = Backend()
        ..on('GET /legal', (_) => Backend.ok({..._map('legal.json'), 'termsUrl': 'http://x.test/t'}..remove('privacyUrl')));
      final opened = await tapLinks(t, noUrl, locale: const Locale('en'));
      expect(opened.map((u) => u.path), ['/en/legal/terms', '/en/legal/privacy']);
    });
  });
}
