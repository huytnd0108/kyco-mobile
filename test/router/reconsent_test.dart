// Release-i re-consent gate (kyco 4f36881d lib/legal/consent.ts:104-137,
// app/api/v1/me/consents/route.ts), driven through the REAL router + scripted
// /api/v1. Fixtures: test/fixtures/release_i.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show RequestOptions, ResponseBody;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/core/locale_controller.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'dart:typed_data';

import '../wave_c_support.dart';

Map<String, dynamic> _fx(String n) =>
    jsonDecode(File('test/fixtures/release_i/$n').readAsStringSync()) as Map<String, dynamic>;

/// Holds `POST /me/consents` open until [release] so the in-flight state is observable.
class _GatedBackend extends Backend {
  final gate = Completer<void>();
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.method == 'POST' && o.path == '/me/consents') await gate.future;
    return super.fetch(o, s, c);
  }
}

AuthState _needs(String role) => AuthState(
    status: AuthStatus.signedIn,
    user: AuthUser.fromJson({..._fx('me_needs_reconsent.json'), 'role': role}));

Backend _backend({String role = 'customer', bool consentedAfterPost = true}) {
  var accepted = false;
  return Backend()
    ..on('GET /legal', (_) => Backend.ok(_fx('legal.json')))
    ..on('GET /me', (_) => Backend.ok({
          ..._fx(accepted && consentedAfterPost ? 'me_consented.json' : 'me_needs_reconsent.json'),
          'role': role,
        }))
    ..on('POST /me/consents', (_) {
      accepted = true;
      return Backend.ok(_fx('consents_201.json'), status: 201);
    });
}

Future<(ProviderContainer, GoRouter)> _open(WidgetTester t, Backend b, AuthState auth) async {
  useTallView(t, w: 420, h: 2200);
  final h = await harness(backend: b, auth: auth);
  final c = ProviderContainer(overrides: h.overrides);
  addTearDown(c.dispose);
  await c.read(localeControllerProvider.notifier).set(const Locale('vi'));
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KycoApp()));
  await t.pumpAndSettle();
  return (c, c.read(routerProvider));
}

String _loc(GoRouter r) => r.routerDelegate.currentConfiguration.uri.toString();
String _path(GoRouter r) => r.routerDelegate.currentConfiguration.uri.path;

FilledButton _accept(WidgetTester t) => t.widget<FilledButton>(find.byKey(const ValueKey('reconsent-accept')));

Future<void> _tick(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('reconsent-checkbox')));
  await t.pump();
}

void main() {
  group('appRedirect (pure)', () {
    String? r(AuthStatus s, String loc, {String? role = 'customer', bool needs = false, String? from, String? full}) =>
        appRedirect(status: s, role: role, loc: loc, from: from, needsReconsent: needs, fullLoc: full);

    test('signed-in + needsReconsent is held on /reconsent with the destination in from (every role)', () {
      for (final role in ['customer', 'tasker', 'pending_tasker', 'admin']) {
        expect(r(AuthStatus.signedIn, '/', role: role, needs: true), '/reconsent?from=%2F', reason: role);
        expect(r(AuthStatus.signedIn, '/bookings', role: role, needs: true, full: '/bookings?x=1'),
            '/reconsent?from=%2Fbookings%3Fx%3D1');
        expect(r(AuthStatus.signedIn, '/p/jobs/5', role: role, needs: true), '/reconsent?from=%2Fp%2Fjobs%2F5');
      }
      expect(r(AuthStatus.signedIn, '/reconsent', needs: true), isNull, reason: 'stay on the gate');
    });

    test('guests and an unresolved session are never gated; the gate is not reachable to them', () {
      for (final s in [AuthStatus.signedOut, AuthStatus.unknown]) {
        expect(r(s, '/', needs: true), isNull);
        expect(r(s, '/bookings', needs: true), s == AuthStatus.unknown ? '/' : '/login?from=/bookings');
        expect(r(s, '/reconsent', needs: true), '/');
      }
    });

    test('no flag -> unchanged routing; a cleared gate resumes from (safe paths only)', () {
      expect(r(AuthStatus.signedIn, '/bookings'), isNull);
      expect(r(AuthStatus.signedIn, '/reconsent', from: '/bookings/5'), '/bookings/5');
      expect(r(AuthStatus.signedIn, '/reconsent'), '/');
      for (final bad in ['https://evil.test/x', '//evil.test', 'bookings', '/reconsent', '']) {
        expect(reconsentResume(bad), '/', reason: bad);
      }
    });
  });

  test('after login the controller reads consents from /me (the login body carries none)', () async {
    final b = Backend()
      ..on('POST /auth/login', (_) => Backend.ok({
            'accessToken': 'a',
            'refreshToken': 'r',
            'expiresIn': 900,
            'user': {'id': 7, 'role': 'customer', 'name': 'Ngọc Anh', 'locale': 'vi'},
          }))
      ..on('GET /me', (_) => Backend.ok(_fx('me_needs_reconsent.json')));
    final h = await harness(backend: b, auth: const AuthState(status: AuthStatus.signedOut));
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    expect(await c.read(authControllerProvider.notifier).login(email: 'a@b.vn', password: 'secret-123'), isTrue);
    expect(c.read(authControllerProvider).user!.needsReconsent, isTrue);

    // /me unavailable right after login: still signed in (the next /me read fills it in).
    b.on('GET /me', (_) => Backend.err(503, 'MAINTENANCE'));
    expect(await c.read(authControllerProvider.notifier).login(email: 'a@b.vn', password: 'secret-123'), isTrue);
    expect(c.read(authControllerProvider).status, AuthStatus.signedIn);
    expect(c.read(authControllerProvider).user!.needsReconsent, isFalse);
  });

  testWidgets('customer at app start: gated, accept POSTs the server version, refreshes /me, continues', (t) async {
    final b = _backend();
    final (c, router) = await _open(t, b, _needs('customer'));
    expect(_path(router), '/reconsent');
    expect(find.text(vi.reconsentTitle), findsOneWidget);
    expect(vi.reconsentTitle, 'Cập nhật điều khoản');
    expect(find.text(vi.reconsentTermsVersion('24/05/2026')), findsOneWidget);
    expect(find.text(vi.reconsentPrivacyVersion('24/05/2026')), findsOneWidget);
    expect(find.byKey(const ValueKey('reconsent-logout')), findsOneWidget);
    expect(_accept(t).onPressed, isNull, reason: 'one checkbox must be ticked first');

    await _tick(t);
    expect(_accept(t).onPressed, isNotNull);
    await t.tap(find.byKey(const ValueKey('reconsent-accept')));
    await t.pumpAndSettle();

    final post = b.calls('POST /me/consents').single;
    expect(post.data, {'terms': true, 'privacy': true, 'version': '2026-05-24'});
    expect(b.calls('GET /me'), isNotEmpty, reason: '/me is refreshed after the 201');
    expect(_path(router), '/');
    expect(find.text(vi.reconsentTitle), findsNothing);
    expect(c.read(authControllerProvider).user?.needsReconsent, isFalse);
  });

  testWidgets('the accept button is disabled while the POST is in flight (no double submit)', (t) async {
    final b = _GatedBackend()
      ..on('GET /legal', (_) => Backend.ok(_fx('legal.json')))
      ..on('GET /me', (_) => Backend.ok(_fx('me_consented.json')))
      ..on('POST /me/consents', (_) => Backend.ok(_fx('consents_201.json'), status: 201));
    final (_, router) = await _open(t, b, _needs('customer'));
    await _tick(t);
    await t.tap(find.byKey(const ValueKey('reconsent-accept')));
    await t.pump();
    expect(_accept(t).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(t.widget<CheckboxListTile>(find.byKey(const ValueKey('reconsent-checkbox'))).onChanged, isNull);
    b.gate.complete();
    await t.pumpAndSettle();
    expect(b.calls('POST /me/consents'), hasLength(1));
    expect(_path(router), '/');
  });

  testWidgets('a tasker relaunching lands on /p after the gate; pending_tasker on the review door', (t) async {
    final b = _backend(role: 'tasker');
    final (_, router) = await _open(t, b, _needs('tasker'));
    expect(_path(router), '/reconsent');
    await _tick(t);
    await t.tap(find.byKey(const ValueKey('reconsent-accept')));
    await t.pumpAndSettle();
    expect(_path(router), '/p', reason: 'the one-shot cold-start role routing was not spent by the gate hop');

    await t.pumpWidget(const SizedBox());
    final (_, router2) = await _open(t, _backend(role: 'pending_tasker'), _needs('pending_tasker'));
    expect(_path(router2), '/reconsent');
    await _tick(t);
    await t.tap(find.byKey(const ValueKey('reconsent-accept')));
    await t.pumpAndSettle();
    expect(_path(router2), '/become-tasker');
  });

  testWidgets('mid-session: /me flips to needsReconsent on /account -> gate -> back to /account', (t) async {
    var needs = false;
    final b = Backend()
      ..on('GET /legal', (_) => Backend.ok(_fx('legal.json')))
      ..on('GET /me', (_) => Backend.ok(_fx(needs ? 'me_needs_reconsent.json' : 'me_consented.json')))
      ..on('POST /me/consents', (_) {
        needs = false;
        return Backend.ok(_fx('consents_201.json'), status: 201);
      });
    final (c, router) = await _open(t, b, signedInAs('customer'));
    router.go('/account');
    await t.pumpAndSettle();
    expect(_path(router), '/account');

    needs = true;
    unawaited(c.read(authControllerProvider.notifier).reloadMe());
    await t.pumpAndSettle();
    expect(_loc(router), '/reconsent?from=%2Faccount');

    await _tick(t);
    await t.tap(find.byKey(const ValueKey('reconsent-accept')));
    await t.pumpAndSettle();
    expect(_loc(router), '/account');
  });

  testWidgets('POST failure: friendly error + retry, no loop, still gated; retry then succeeds', (t) async {
    var fail = true;
    final b = _backend()
      ..on('GET /me', (_) => Backend.ok(_fx(fail ? 'me_needs_reconsent.json' : 'me_consented.json')))
      ..on('POST /me/consents', (_) => fail
          ? Backend.err(500, 'INTERNAL', 'boom stack trace')
          : Backend.ok(_fx('consents_201.json'), status: 201));
    final (_, router) = await _open(t, b, _needs('customer'));
    final meCalls = b.calls('GET /me').length;
    await _tick(t);
    await t.tap(find.byKey(const ValueKey('reconsent-accept')));
    await t.pumpAndSettle();

    expect(b.calls('POST /me/consents'), hasLength(1), reason: 'one attempt per tap, no automatic retry loop');
    expect(b.calls('GET /me'), hasLength(meCalls), reason: 'a failed POST triggers no /me refetch loop');
    expect(_path(router), '/reconsent');
    expect(find.byKey(const ValueKey('reconsent-error')), findsOneWidget);
    expect(find.text(vi.reconsentError), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing, reason: 'raw server text is never shown');
    expect(find.descendant(of: find.byKey(const ValueKey('reconsent-accept')), matching: find.text(vi.retry)),
        findsOneWidget);
    expect(_accept(t).onPressed, isNotNull, reason: 'retry is available');
    expect(find.byKey(const ValueKey('reconsent-logout')), findsOneWidget);

    fail = false;
    await t.tap(find.byKey(const ValueKey('reconsent-accept')));
    await t.pumpAndSettle();
    expect(b.calls('POST /me/consents'), hasLength(2));
    expect(_path(router), '/');
  });

  testWidgets('even when the /me refresh after a 201 fails, the user is not bounced back to the gate', (t) async {
    final b = _backend()..on('GET /me', (_) => Backend.err(503, 'MAINTENANCE'));
    final (c, router) = await _open(t, b, _needs('customer'));
    await _tick(t);
    await t.tap(find.byKey(const ValueKey('reconsent-accept')));
    await t.pumpAndSettle();
    expect(_path(router), '/');
    expect(c.read(authControllerProvider).user?.needsReconsent, isFalse);
  });

  testWidgets('guests are not gated; /reconsent is not reachable signed out', (t) async {
    final b = _backend();
    final (_, router) = await _open(t, b, const AuthState(status: AuthStatus.signedOut));
    expect(_path(router), '/');
    expect(find.text(vi.reconsentTitle), findsNothing);
    router.go('/reconsent');
    await t.pumpAndSettle();
    expect(_path(router), '/');
    expect(b.calls('POST /me/consents'), isEmpty);
  });

  testWidgets('logout stays available on the gate and signs the user out to home', (t) async {
    final (c, router) = await _open(t, _backend(), _needs('customer'));
    await t.tap(find.byKey(const ValueKey('reconsent-logout')));
    await t.pumpAndSettle();
    expect(c.read(authControllerProvider).status, AuthStatus.signedOut);
    expect(_path(router), '/');
    expect(find.text(vi.reconsentTitle), findsNothing);
  });

  testWidgets('the gate links open the server URLs', (t) async {
    useTallView(t, w: 420, h: 2200);
    final opened = <Uri>[];
    final h = await harness(
        backend: _backend(),
        auth: _needs('customer'),
        opener: (u) async {
          opened.add(u);
          return true;
        });
    final c = ProviderContainer(overrides: h.overrides);
    addTearDown(c.dispose);
    await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KycoApp()));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('reconsent-terms-link')));
    await t.tap(find.byKey(const ValueKey('reconsent-privacy-link')));
    expect(opened.map((u) => u.toString()), ['https://kyco.vn/vi/legal/terms', 'https://kyco.vn/vi/legal/privacy']);
  });
}
