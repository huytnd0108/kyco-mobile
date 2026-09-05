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
    '/providers/7',
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
}
