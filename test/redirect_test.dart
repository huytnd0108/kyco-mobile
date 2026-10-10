import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';

void main() {
  // Every public path the guest-first rule must leave alone (null redirect),
  // including the ones the plan calls out explicitly as PUBLIC forever.
  const publicPaths = <String>[
    '/',
    '/services',
    '/services/42',
    '/book-now',
    '/checkout/42', // the confirm gate is in-screen — NEVER a redirect
    '/locations',
    '/locations/ho-chi-minh',
    '/locations/ho-chi-minh/ve-sinh',
    '/taskers/7',
    '/subscriptions',
    '/notifications',
    '/account',
  ];

  group('anon (signedOut)', () {
    for (final p in publicPaths) {
      test('public $p → null', () {
        expect(guestFirstRedirect(status: AuthStatus.signedOut, loc: p), isNull);
      });
    }

    test('/bookings → /login?from=/bookings', () {
      expect(guestFirstRedirect(status: AuthStatus.signedOut, loc: '/bookings'),
          '/login?from=/bookings');
    });
    test('/bookings/1042 → /login?from=/bookings/1042', () {
      expect(guestFirstRedirect(status: AuthStatus.signedOut, loc: '/bookings/1042'),
          '/login?from=/bookings/1042');
    });
    test('/messages → /login?from=/messages', () {
      expect(guestFirstRedirect(status: AuthStatus.signedOut, loc: '/messages'),
          '/login?from=/messages');
    });
    test('/messages/9 → /login?from=/messages/9', () {
      expect(guestFirstRedirect(status: AuthStatus.signedOut, loc: '/messages/9'),
          '/login?from=/messages/9');
    });
  });

  group('unknown (still bootstrapping)', () {
    test('protected → / (never a login bounce mid-bootstrap)', () {
      expect(guestFirstRedirect(status: AuthStatus.unknown, loc: '/bookings'), '/');
      expect(guestFirstRedirect(status: AuthStatus.unknown, loc: '/messages'), '/');
    });
    for (final p in publicPaths) {
      test('public $p → null', () {
        expect(guestFirstRedirect(status: AuthStatus.unknown, loc: p), isNull);
      });
    }
  });

  group('signedIn', () {
    test('on /login without from → /', () {
      expect(guestFirstRedirect(status: AuthStatus.signedIn, loc: '/login'), '/');
    });
    test('on /login with from → resumes from', () {
      expect(
          guestFirstRedirect(status: AuthStatus.signedIn, loc: '/login', from: '/checkout/42'),
          '/checkout/42');
    });
    test('on /signup with from → resumes from', () {
      expect(
          guestFirstRedirect(status: AuthStatus.signedIn, loc: '/signup', from: '/bookings'),
          '/bookings');
    });
    test('protected path stays (no redirect)', () {
      expect(guestFirstRedirect(status: AuthStatus.signedIn, loc: '/bookings'), isNull);
      expect(guestFirstRedirect(status: AuthStatus.signedIn, loc: '/messages'), isNull);
    });
    for (final p in publicPaths) {
      test('public $p → null', () {
        expect(guestFirstRedirect(status: AuthStatus.signedIn, loc: p), isNull);
      });
    }
  });

  // ── Tasker (/p) gating — additive; the customer rule above is frozen. ──
  group('appRedirect — customer delegation UNCHANGED', () {
    // appRedirect must be byte-identical to guestFirstRedirect for every
    // non-/p path (public + protected + auth screens).
    final customerCases = <(AuthStatus, String, String?)>[
      for (final p in publicPaths) (AuthStatus.signedOut, p, null),
      for (final p in publicPaths) (AuthStatus.unknown, p, null),
      for (final p in publicPaths) (AuthStatus.signedIn, p, null),
      (AuthStatus.signedOut, '/bookings', null),
      (AuthStatus.signedOut, '/messages', null),
      (AuthStatus.unknown, '/bookings', null),
      (AuthStatus.signedIn, '/bookings', null),
      (AuthStatus.signedIn, '/login', null),
    ];
    for (final (status, loc, from) in customerCases) {
      test('$status $loc delegates', () {
        expect(
          appRedirect(status: status, role: 'customer', loc: loc, from: from),
          guestFirstRedirect(status: status, loc: loc, from: from),
        );
      });
    }
    // The customer /taskers/:id route begins with "/p" but must NOT be gated.
    test('/taskers/7 is not a tasker path', () {
      expect(isTaskerPath('/taskers/7'), isFalse);
      expect(appRedirect(status: AuthStatus.signedOut, role: null, loc: '/taskers/7'), isNull);
    });
  });

  group('appRedirect — /p role gate', () {
    test('unknown → / (never a login bounce mid-bootstrap)', () {
      expect(appRedirect(status: AuthStatus.unknown, loc: '/p'), '/');
      expect(appRedirect(status: AuthStatus.unknown, loc: '/p/wallet'), '/');
    });
    test('signedOut → /login?from=', () {
      expect(appRedirect(status: AuthStatus.signedOut, loc: '/p'), '/login?from=/p');
      expect(appRedirect(status: AuthStatus.signedOut, loc: '/p/wallet'),
          '/login?from=/p/wallet');
    });
    test('signed-in customer → /become-tasker', () {
      expect(appRedirect(status: AuthStatus.signedIn, role: 'customer', loc: '/p'),
          '/become-tasker');
      expect(appRedirect(status: AuthStatus.signedIn, role: 'pending_tasker', loc: '/p'),
          '/become-tasker');
    });
    test('signed-in tasker / admin → null (allowed)', () {
      expect(appRedirect(status: AuthStatus.signedIn, role: 'tasker', loc: '/p'), isNull);
      expect(appRedirect(status: AuthStatus.signedIn, role: 'admin', loc: '/p'), isNull);
      expect(
          appRedirect(status: AuthStatus.signedIn, role: 'tasker', loc: '/p/jobs/5'), isNull);
    });
    test('/become-tasker is public (any status → null)', () {
      expect(appRedirect(status: AuthStatus.signedOut, loc: '/become-tasker'), isNull);
      expect(appRedirect(status: AuthStatus.unknown, loc: '/become-tasker'), isNull);
      expect(appRedirect(status: AuthStatus.signedIn, role: 'customer', loc: '/become-tasker'),
          isNull);
    });
  });
}
