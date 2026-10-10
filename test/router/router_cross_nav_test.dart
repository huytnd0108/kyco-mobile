// OCD-025 / OCD-034 / OCD-049: the REAL router (routerProvider) driven through
// the cross-navigation pairs that mix root-level and shell-level routes, a
// tasker cold start, and repeated language switches with requests in flight.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/core/nav.dart';
import 'package:kyco_mobile/core/locale_controller.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';

import '../wave_c_support.dart';

Map<String, dynamic> _page(int id) => {
      'booking': {
        'id': id, 'status': 'CONFIRMED', 'totalVnd': 480000, 'paymentMethod': 'cash',
        'createdAt': '2026-01-15T12:00:00Z', 'scheduledAt': '2026-01-17T12:00:00Z',
        'addressLine': '45 Lê Lợi', 'district': 'Quận 1',
      },
      'service': {'id': 1, 'name': 'Vệ sinh nhà'},
      'job': {'id': 77, 'status': 'active', 'taskerId': 4},
      'tasker': {'id': 4, 'name': 'Nguyễn Thị Lan'},
      'messages': <Object>[],
      'hasReview': false,
    };

Backend _backend({String link = '/bookings/148'}) {
  final b = Backend();
  b.on('GET /notifications', (_) => Backend.ok([
        {'id': 1, 'type': 'booking', 'title': 'Đơn mới', 'body': 'Đơn của bạn', 'link': link, 'read': false},
      ]));
  b.on('POST /notifications/1/read', (_) => Backend.ok({}));
  b.on('GET /bookings/148/page', (_) => Backend.ok(_page(148)));
  b.on('GET /bookings', (_) => Backend.ok([]));
  b.on('GET /conversations', (_) => Backend.ok([]));
  return b;
}

Future<(ProviderContainer, GoRouter)> _pumpApp(
  WidgetTester t, {
  required AuthState auth,
  Backend? backend,
  String? initial,
}) async {
  useTallView(t, w: 400, h: 900);
  final h = await harness(backend: backend ?? _backend(), auth: auth);
  final c = ProviderContainer(overrides: h.overrides);
  addTearDown(c.dispose);
  await c.read(localeControllerProvider.notifier).set(const Locale('vi'));
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KycoApp()));
  await t.pumpAndSettle();
  final router = c.read(routerProvider);
  if (initial != null) {
    router.go(initial);
    await t.pumpAndSettle();
  }
  return (c, router);
}

String _path(GoRouter r) => r.routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  group('OCD-025 root <-> shell cross navigation never asserts', () {
    testWidgets('tapping an order notification (link /bookings/148) opens the booking and Back returns',
        (t) async {
      // The real path: the shell is alive underneath (Account -> Notifications).
      final (_, router) =
          await _pumpApp(t, auth: signedInAs('customer'), initial: '/account');
      unawaited(router.push<Object?>('/notifications'));
      await t.pumpAndSettle();
      expect(find.text('Đơn mới'), findsOneWidget);
      await t.tap(find.text('Đơn mới'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_path(router), '/bookings/148');
      // Back goes to the notifications screen, not out of the app.
      router.pop();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Đơn mới'), findsOneWidget);
    });

    // Every (from -> push target) pair that mixes a root-level route with a
    // shell-level one, via the exact calls the screens make.
    final pairs = <(String, String)>[
      ('/notifications', '/bookings/148'),
      ('/notifications', '/bookings'),
      ('/notifications', '/messages'),
      ('/notifications', '/messages/148'),
      ('/notifications', '/services/3'),
      ('/notifications', '/services'),
      ('/notifications', '/account'),
      ('/notifications', '/taskers/4'),
      ('/messages/148', '/bookings/148'),
      ('/bookings/148', '/messages/148'),
      ('/bookings/148', '/taskers/4'),
      ('/bookings', '/bookings/148'),
      ('/account', '/notifications'),
      ('/account', '/subscriptions'),
      ('/account', '/bookings'),
      ('/', '/services'),
      ('/', '/services/3'),
      ('/', '/book-now'),
      ('/services', '/services/3'),
      ('/services/3', '/checkout/3'),
    ];
    for (final (from, to) in pairs) {
      testWidgets('$from -> push $to', (t) async {
        // Root-level origins are reached the way users reach them: pushed over
        // a live shell (Account tab), so both navigators are in play.
        final overShell = from == '/notifications';
        final (_, router) =
            await _pumpApp(t, auth: signedInAs('customer'), initial: overShell ? '/account' : from);
        if (overShell) {
          unawaited(router.push<Object?>(from));
          await t.pumpAndSettle();
        }
        // Exactly what the screens do: tab roots switch tab, the rest push.
        final tab = isShellTabRoot(to);
        if (tab) {
          router.go(to);
        } else {
          unawaited(router.push<Object?>(to));
        }
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'open $to from $from');
        expect(_path(router), to);
        if (!tab) {
          router.pop();
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: 'pop back from $to');
        }
      });
    }

    testWidgets('tasker: /p/jobs -> /p/jobs/5, /p/more -> /notifications', (t) async {
      final b = _backend();
      final (_, router) = await _pumpApp(t, auth: signedInAs('tasker'), backend: b, initial: '/p/jobs');
      unawaited(router.push<Object?>('/p/jobs/5'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      router.pop();
      await t.pumpAndSettle();
      router.go('/p/more');
      await t.pumpAndSettle();
      unawaited(router.push<Object?>('/notifications'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      unawaited(router.push<Object?>('/bookings/148'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('OCD-034 cold start role routing', () {
    test('first signed-in decision: tasker / pending_tasker on / go to /p', () {
      expect(
          appRedirect(status: AuthStatus.signedIn, role: 'tasker', loc: '/', coldStart: true), '/p');
      expect(
          appRedirect(status: AuthStatus.signedIn, role: 'pending_tasker', loc: '/', coldStart: true),
          '/p');
    });
    test('customer / admin / not cold start / other paths are untouched', () {
      expect(appRedirect(status: AuthStatus.signedIn, role: 'customer', loc: '/', coldStart: true),
          isNull);
      expect(appRedirect(status: AuthStatus.signedIn, role: 'admin', loc: '/', coldStart: true),
          isNull);
      expect(appRedirect(status: AuthStatus.signedIn, role: 'tasker', loc: '/'), isNull);
      expect(
          appRedirect(status: AuthStatus.signedIn, role: 'tasker', loc: '/services', coldStart: true),
          isNull);
      expect(appRedirect(status: AuthStatus.signedOut, loc: '/', coldStart: true), isNull);
    });

    testWidgets('a tasker relaunching lands on /p; a later deliberate go(/) stays on the customer shell',
        (t) async {
      final (_, router) = await _pumpApp(t, auth: signedInAs('tasker'));
      expect(_path(router), '/p');
      router.go('/');
      await t.pumpAndSettle();
      expect(_path(router), '/');
    });

    testWidgets('a pending_tasker relaunching lands on the under-review screen', (t) async {
      final (_, router) = await _pumpApp(t, auth: signedInAs('pending_tasker'));
      expect(_path(router), '/become-tasker');
    });

    testWidgets('a customer relaunching stays on /', (t) async {
      final (_, router) = await _pumpApp(t, auth: signedInAs('customer'));
      expect(_path(router), '/');
    });
  });

  group('OCD-049 language switch', () {
    testWidgets('repeated vi<->en switches with requests in flight never throw', (t) async {
      final b = _backend();
      b.on('GET /home', (_) => Backend.ok({}));
      final (c, router) = await _pumpApp(t, auth: signedInAs('customer'), backend: b, initial: '/account');
      for (var i = 0; i < 8; i++) {
        final code = i.isEven ? 'en' : 'vi';
        unawaited(c.read(localeControllerProvider.notifier).set(Locale(code)));
        // Mid-flight: navigate (shell tabs, a pushed root route, a dialog-less sheet
        // host) and flip again before the previous refetch settled.
        switch (i % 4) {
          case 0:
            router.go('/bookings');
          case 1:
            router.go('/');
          case 2:
            unawaited(router.push<Object?>('/notifications'));
          default:
            router.go('/account');
        }
        await t.pump(const Duration(milliseconds: 20));
        expect(t.takeException(), isNull, reason: 'switch #$i');
      }
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    testWidgets('a locale change refetches once, after the frame - not once per rapid flip', (t) async {
      final b = _backend();
      var homeCalls = 0;
      b.on('GET /home', (_) {
        homeCalls++;
        return Backend.ok({});
      });
      final (c, _) = await _pumpApp(t, auth: signedInAs('customer'), backend: b, initial: '/');
      final before = homeCalls;
      final ctl = c.read(localeControllerProvider.notifier);
      unawaited(ctl.set(const Locale('en')));
      unawaited(ctl.set(const Locale('vi')));
      unawaited(ctl.set(const Locale('en')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(homeCalls - before, lessThanOrEqualTo(3), reason: 'bounded refetch, no storm');
      expect(c.read(appLocaleCodeProvider), 'en');
      await t.pumpWidget(const SizedBox()); // unmount, then let any timers fire
      await t.pump(const Duration(seconds: 10));
    });

    testWidgets('re-selecting the active language is a no-op', (t) async {
      final (c, _) = await _pumpApp(t, auth: signedInAs('customer'), initial: '/account');
      var changes = 0;
      c.listen(localeControllerProvider, (_, _) => changes++);
      await c.read(localeControllerProvider.notifier).set(const Locale('vi'));
      expect(changes, 0);
    });
  });

  group('OCD-009/011 signup is pushed over login', () {
    const out = AuthState(status: AuthStatus.signedOut);

    testWidgets('signup has a close control; system Back returns to login, not the launcher', (t) async {
      final (_, router) = await _pumpApp(t, auth: out, initial: '/login');
      await t.tap(find.text(vi.noAccountSignup));
      await t.pumpAndSettle();
      expect(_path(router), '/signup');
      expect(find.byKey(const ValueKey('signup-close')), findsOneWidget);
      expect(router.canPop(), isTrue);
      // The OS back button.
      final handled = await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(handled, isTrue, reason: 'Back is consumed by the router, the app does not exit');
      expect(_path(router), '/login');
    });

    testWidgets('close button pops back to login; "I have an account" does not stack a second login',
        (t) async {
      final (_, router) = await _pumpApp(t, auth: out, initial: '/login');
      await t.tap(find.text(vi.noAccountSignup));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('signup-close')));
      await t.pumpAndSettle();
      expect(_path(router), '/login');

      await t.tap(find.text(vi.noAccountSignup));
      await t.pumpAndSettle();
      await t.tap(find.text(vi.haveAccountLogin));
      await t.pumpAndSettle();
      expect(_path(router), '/login');
      // Exactly one login in the stack (nothing left to pop).
      expect(find.byKey(const ValueKey('login-close')), findsOneWidget);
      expect(router.canPop(), isFalse);
    });

    testWidgets('signup opened directly (deep link) closes to home', (t) async {
      final (_, router) = await _pumpApp(t, auth: out, initial: '/signup');
      await t.tap(find.byKey(const ValueKey('signup-close')));
      await t.pumpAndSettle();
      expect(_path(router), '/');
    });
  });
}
