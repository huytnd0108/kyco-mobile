// Release-j consent contract (kyco c96c4ca0 lib/legal/consent.ts): GET /v1/legal
// `consentSchema: 2` -> per-document termsVersion / privacyVersion (signup,
// quick signup, become-tasker, re-consent); absent / 1 -> release-i min()/max().
import 'dart:convert';

import 'package:dio/dio.dart' show BaseOptions, Dio, FormData;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/ui/error_text.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/auth/signup_screen.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore;
import 'wave_c_support.dart';

Map<String, dynamic> _legalJson({int? schema, String t = '2026-05-24', String p = '2026-05-24'}) => {
      'termsVersion': t,
      'privacyVersion': p,
      'consentRequired': true,
      'consentSchema': ?schema,
      'termsUrl': 'https://kyco.vn/vi/legal/terms',
      'privacyUrl': 'https://kyco.vn/vi/legal/privacy',
    };

LegalInfo _legal({int? schema, String t = '2026-05-24', String p = '2026-05-24'}) =>
    LegalInfo.tryParse(_legalJson(schema: schema, t: t, p: p))!;

KycoApi _api(Backend b) {
  final tokens = InMemoryTokenStore();
  final dio = Dio(BaseOptions(baseUrl: '', validateStatus: (_) => true))..httpClientAdapter = b;
  return KycoApi(KycoApiClient(tokens: tokens, dio: dio), tokens);
}

String _j(Object? o) => jsonEncode(o);

void main() {
  group('LegalInfo.consentSchema', () {
    test('absent -> 1 (legacy), 2 -> per-document, junk -> 1', () {
      expect(_legal().consentSchema, 1);
      expect(_legal().perDocumentConsent, isFalse);
      expect(_legal(schema: 1).perDocumentConsent, isFalse);
      expect(_legal(schema: 2).perDocumentConsent, isTrue);
      expect(LegalInfo.tryParse({..._legalJson(), 'consentSchema': 'x'})!.consentSchema, 1);
      expect(_legal(schema: 3).perDocumentConsent, isTrue);
    });
  });

  group('payloads: schema 2 vs schema 1 (exact)', () {
    test('schema 2 JSON: per-document versions, NO version key; diverging versions are NOT min()ed', () {
      final p = ConsentPayload.forLegal(_legal(schema: 2, t: '2026-06-01', p: '2026-05-24'))!;
      expect(_j(p.toJson()),
          '{"terms":true,"privacy":true,"termsVersion":"2026-06-01","privacyVersion":"2026-05-24"}');
      final flipped = ConsentPayload.forLegal(_legal(schema: 2, t: '2026-05-24', p: '2026-06-01'))!;
      expect(_j(flipped.toJson()),
          '{"terms":true,"privacy":true,"termsVersion":"2026-05-24","privacyVersion":"2026-06-01"}');
    });

    test('schema 2 multipart: consent_terms_version / consent_privacy_version, no consent_version', () {
      final p = ConsentPayload.forLegal(_legal(schema: 2, t: '2026-06-01', p: '2026-05-24'))!;
      expect(p.toFormFields(), {
        'consent_terms': '1',
        'consent_privacy': '1',
        'consent_terms_version': '2026-06-01',
        'consent_privacy_version': '2026-05-24',
      });
    });

    test('schema 1 / absent keep release-i exactly: min() version', () {
      for (final l in [_legal(), _legal(schema: 1)]) {
        final p = ConsentPayload.forLegal(
            LegalInfo(termsVersion: '2026-06-01', privacyVersion: '2026-05-24', consentSchema: l.consentSchema))!;
        expect(_j(p.toJson()), '{"terms":true,"privacy":true,"version":"2026-05-24"}');
        expect(p.toFormFields(),
            {'consent_terms': '1', 'consent_privacy': '1', 'consent_version': '2026-05-24'});
      }
    });

    test('non-ISO versions send nothing under either schema; no legal -> null', () {
      expect(ConsentPayload.forLegal(_legal(schema: 2, t: 'v2')), isNull);
      expect(ConsentPayload.forLegal(_legal(t: 'v2')), isNull);
      expect(ConsentPayload.forLegal(null), isNull);
    });

    test('signup / quick signup bodies over the wire', () async {
      final b = Backend()
        ..on('POST /auth/signup', (_) => Backend.ok({
              'accessToken': 'a',
              'refreshToken': 'r',
              'expiresIn': 900,
              'user': {'id': 7, 'role': 'customer'},
            }, status: 201))
        ..on('POST /signup/quick', (_) => Backend.ok({'email': 'a@b.vn'}, status: 201));
      final api = _api(b);
      final c2 = ConsentPayload.forLegal(_legal(schema: 2, t: '2026-06-01', p: '2026-05-24'));
      final c1 = ConsentPayload.forLegal(_legal(t: '2026-06-01', p: '2026-05-24'));
      await api.signup(email: 'a@b.vn', password: 'secret-123', name: 'Lan', consent: c2);
      await api.signup(email: 'a@b.vn', password: 'secret-123', name: 'Lan', consent: c1);
      await api.quickSignup(phone: '0912345678', email: 'a@b.vn', password: 'secret-123', name: 'Lan', consent: c2);
      await api.quickSignup(phone: '0912345678', email: 'a@b.vn', password: 'secret-123', name: 'Lan', consent: c1);
      final s = b.calls('POST /auth/signup').toList();
      expect(_j((s[0].data as Map)['consent']),
          '{"terms":true,"privacy":true,"termsVersion":"2026-06-01","privacyVersion":"2026-05-24"}');
      expect(_j((s[1].data as Map)['consent']), '{"terms":true,"privacy":true,"version":"2026-05-24"}');
      final q = b.calls('POST /signup/quick').toList();
      expect(_j((q[0].data as Map)['consent']),
          '{"terms":true,"privacy":true,"termsVersion":"2026-06-01","privacyVersion":"2026-05-24"}');
      expect(_j((q[1].data as Map)['consent']), '{"terms":true,"privacy":true,"version":"2026-05-24"}');
    });

    test('become-tasker multipart over the wire', () async {
      final b = Backend()..on('POST /become-tasker', (_) => Backend.ok({'userId': 3}, status: 201));
      final api = _api(b);
      Future<void> call(ConsentPayload? c) => api.becomeTasker(
          phone: '0912345678', otpCode: '123456', name: 'Lan', city: 'HCM', district: 'Q1', files: const [], consent: c);
      await call(ConsentPayload.forLegal(_legal(schema: 2, t: '2026-06-01', p: '2026-05-24')));
      await call(ConsentPayload.forLegal(_legal(t: '2026-06-01', p: '2026-05-24')));
      final forms = [
        for (final o in b.calls('POST /become-tasker'))
          {for (final e in (o.data as FormData).fields) e.key: e.value}
      ];
      expect({for (final e in forms[0].entries.where((e) => e.key.startsWith('consent'))) e.key: e.value}, {
        'consent_terms': '1',
        'consent_privacy': '1',
        'consent_terms_version': '2026-06-01',
        'consent_privacy_version': '2026-05-24',
      });
      expect({for (final e in forms[1].entries.where((e) => e.key.startsWith('consent'))) e.key: e.value},
          {'consent_terms': '1', 'consent_privacy': '1', 'consent_version': '2026-05-24'});
    });

    test('POST /me/consents: flat per-document vs legacy max()', () async {
      final b = Backend()..on('POST /me/consents', (_) => Backend.ok({'needsReconsent': false}, status: 201));
      final api = _api(b);
      await api.recordConsents(termsVersion: '2026-06-01', privacyVersion: '2026-05-24');
      await api.recordConsents(version: '2026-06-01');
      final c = b.calls('POST /me/consents').toList();
      expect(_j(c[0].data), '{"terms":true,"privacy":true,"termsVersion":"2026-06-01","privacyVersion":"2026-05-24"}');
      expect(_j(c[1].data), '{"terms":true,"privacy":true,"version":"2026-06-01"}');
    });
  });

  group('signup screen picks the schema from GET /v1/legal', () {
    Future<Backend> submit(WidgetTester t, Map<String, dynamic> legal) async {
      useTallView(t);
      final b = Backend()
        ..on('GET /legal', (_) => Backend.ok(legal))
        ..on('POST /auth/signup', (_) => Backend.ok({
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
      await t.tap(find.byKey(const ValueKey('consent-checkbox')));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, vi.createAccount));
      await t.pumpAndSettle();
      return b;
    }

    testWidgets('schema 2, diverging', (t) async {
      final b = await submit(t, _legalJson(schema: 2, t: '2026-06-01', p: '2026-05-24'));
      expect(_j((b.calls('POST /auth/signup').single.data as Map)['consent']),
          '{"terms":true,"privacy":true,"termsVersion":"2026-06-01","privacyVersion":"2026-05-24"}');
    });

    testWidgets('schema absent: legacy min(), never termsVersion/privacyVersion', (t) async {
      final b = await submit(t, _legalJson(t: '2026-06-01', p: '2026-05-24'));
      final body = _j(b.calls('POST /auth/signup').single.data);
      expect(_j((b.calls('POST /auth/signup').single.data as Map)['consent']),
          '{"terms":true,"privacy":true,"version":"2026-05-24"}');
      expect(body.contains('termsVersion') || body.contains('privacyVersion'), isFalse);
    });
  });

  group('re-consent (controller)', () {
    Future<(ProviderContainer, Backend)> setup({
      required Backend b,
      String? ct,
      String? cp,
    }) async {
      b
        ..on('GET /me', (_) => Backend.ok({
              'id': 7,
              'role': 'customer',
              'consents': {'needsReconsent': false}
            }))
        ..on('POST /me/consents', (_) => Backend.ok({'needsReconsent': false}, status: 201));
      final user = AuthUser.fromJson({
        'id': 7,
        'role': 'customer',
        'consents': {
          'needsReconsent': true,
          'currentTermsVersion': ?ct,
          'currentPrivacyVersion': ?cp,
        },
      });
      final h = await harness(backend: b, auth: AuthState(status: AuthStatus.signedIn, user: user));
      final c = ProviderContainer(overrides: h.overrides);
      addTearDown(c.dispose);
      return (c, b);
    }

    test('schema 2: diverging /me current versions are sent per document (not max)', () async {
      final (c, b) = await setup(
          b: Backend()..on('GET /legal', (_) => Backend.ok(_legalJson(schema: 2))), ct: '2026-06-01', cp: '2026-05-24');
      expect(await c.read(authControllerProvider.notifier).acceptReconsent(), isNull);
      expect(_j(b.calls('POST /me/consents').single.data),
          '{"terms":true,"privacy":true,"termsVersion":"2026-06-01","privacyVersion":"2026-05-24"}');
    });

    test('schema 2: /me without current versions falls back to /v1/legal', () async {
      final (c, b) = await setup(
          b: Backend()..on('GET /legal', (_) => Backend.ok(_legalJson(schema: 2, t: '2026-06-01', p: '2026-05-24'))));
      await c.read(authControllerProvider.notifier).acceptReconsent();
      expect(_j(b.calls('POST /me/consents').single.data),
          '{"terms":true,"privacy":true,"termsVersion":"2026-06-01","privacyVersion":"2026-05-24"}');
    });

    test('schema absent, 1 or /legal 404/unreachable: release-i max() version', () async {
      for (final legal in <({int status, Object? body}) Function(dynamic)>[
        (_) => Backend.ok(_legalJson()),
        (_) => Backend.ok(_legalJson(schema: 1)),
        (_) => Backend.err(404, 'NOT_FOUND'),
        (_) => throw StateError('offline'),
      ]) {
        final (c, b) = await setup(b: Backend()..on('GET /legal', legal), ct: '2026-06-01', cp: '2026-05-24');
        await c.read(authControllerProvider.notifier).acceptReconsent();
        expect(_j(b.calls('POST /me/consents').single.data), '{"terms":true,"privacy":true,"version":"2026-06-01"}');
      }
    });
  });

  group('422 key mapping', () {
    ApiException e(Map<String, String> f) => ApiException('VALIDATION', 'Request failed', status: 422, fields: f);
    test('version keys -> version copy; consent/terms/privacy -> required copy; others untouched', () {
      final l = vi;
      for (final k in ['consent.termsVersion', 'consent.privacyVersion', 'consent.version']) {
        expect(apiErrorText(l, e({k: 'x'})), l.consentVersionInvalid, reason: k);
      }
      for (final k in ['consent', 'terms', 'privacy']) {
        expect(apiErrorText(l, e({k: 'x'})), l.consentRequired, reason: k);
      }
      expect(apiErrorText(l, e({'email': 'x'})), l.cust2ErrValidation);
      expect(consentErrorText(l, e({'email': 'x'})), isNull);
      expect(consentErrorText(l, ApiException('VALIDATION', 'm', status: 422)), isNull);
      // version problems win when both are present
      expect(apiErrorText(l, e({'consent': 'x', 'consent.termsVersion': 'y'})), l.consentVersionInvalid);
      expect(l.consentVersionInvalid.isNotEmpty && l.consentVersionInvalid != l.consentRequired, isTrue);
    });
  });
}
