// Fix wave A (UX audit): session/role handling, OTP cooldown, not-found route,
// typed error views, live-share tolerance, checkout inline errors, ledger scope.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/core/ui/resend_cooldown.dart';
import 'package:kyco_mobile/core/widgets.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/auth/login_screen.dart';
import 'package:kyco_mobile/features/checkout/checkout_screen.dart';
import 'package:kyco_mobile/features/home/home_providers.dart';
import 'package:kyco_mobile/features/tasker_job_detail/job_detail_body.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore, FakeAuthController;

final _vi = lookupAppLocalizations(const Locale('vi'));

Widget _app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
      key: UniqueKey(),
      overrides: overrides,
      child: MaterialApp(
        theme: buildTheme(lightColorScheme),
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

/// An api whose /me and login answers are scripted.
class _ScriptedApi extends KycoApi {
  _ScriptedApi(super.c, super.t, {this.meResult, this.meError, this.loginUser});
  final Map<String, dynamic>? meResult;
  final Object? meError;
  final Map<String, dynamic>? loginUser;
  final otpRequests = <String>[];
  Object? otpFailure;

  @override
  Future<AuthUser> me() async {
    if (meError != null) throw meError!;
    return AuthUser.fromJson(meResult!);
  }

  @override
  Future<AuthResult> login({required String email, required String password, String? totpCode}) async =>
      AuthResult(
        accessToken: 'a',
        refreshToken: 'r',
        expiresIn: 900,
        user: loginUser == null ? null : AuthUser.fromJson(loginUser!),
      );

  @override
  Future<void> requestOtp({required String phone, String purpose = 'login'}) async {
    otpRequests.add(phone);
    if (otpFailure != null) throw otpFailure!;
  }
}

({ProviderContainer c, InMemoryTokenStore tokens, _ScriptedApi api}) _auth({
  Map<String, dynamic>? me,
  Object? meError,
  Map<String, dynamic>? loginUser,
}) {
  final tokens = InMemoryTokenStore()..save(access: 'a', refresh: 'r');
  final api = _ScriptedApi(KycoApiClient(tokens: tokens), tokens, meResult: me, meError: meError, loginUser: loginUser);
  final c = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(tokens),
    kycoApiProvider.overrideWithValue(api),
  ]);
  addTearDown(c.dispose);
  return (c: c, tokens: tokens, api: api);
}

void main() {
  group('UX-M37 AuthUser.fromJson is tolerant', () {
    test('no hard casts: wrong types never throw', () {
      final u = AuthUser.fromJson({'id': 'x', 'role': 5, 'name': 7, 'locale': []});
      expect(u.id, 0);
      expect(u.role, '');
      expect(u.name, isNull);
      expect(u.locale, isNull);
      expect(AuthUser.fromJson({'id': '12', 'role': 'tasker'}).id, 12);
      expect(AuthUser.fromJson({'id': 3.0, 'role': 'customer'}).id, 3);
    });
    test('role validity: allow-list only, banned separate, missing is stale', () {
      SessionValidity v(Map<String, dynamic> j) => AuthUser.fromJson(j).roleValidity;
      for (final r in ['customer', 'tasker', 'pending_tasker', 'admin', 'staff']) {
        expect(v({'id': 1, 'role': r}), SessionValidity.ok, reason: r);
      }
      for (final r in ['provider', 'pending_provider', 'wizard']) {
        expect(v({'id': 1, 'role': r}), SessionValidity.stale, reason: r);
      }
      expect(v({'id': 1}), SessionValidity.stale);
      expect(v({'role': 'customer'}), SessionValidity.stale);
      expect(v({'id': 1, 'role': 'banned'}), SessionValidity.banned);
    });
  });

  group('UX-M02/M03 bootstrap role handling', () {
    for (final role in ['provider', 'pending_provider', 'mystery']) {
      test("stale/unknown role '$role' forces re-login (never a customer)", () async {
        final h = _auth(me: {'id': 5, 'role': role});
        await h.c.read(authControllerProvider.notifier).bootstrap();
        final s = h.c.read(authControllerProvider);
        expect(s.status, AuthStatus.signedOut);
        expect(s.user, isNull);
        expect(s.reason, SignOutReason.staleSession);
        expect(await h.tokens.hasSession, isFalse);
      });
    }
    test('a missing role is a forced re-login', () async {
      final h = _auth(me: {'id': 5});
      await h.c.read(authControllerProvider.notifier).bootstrap();
      expect(h.c.read(authControllerProvider).reason, SignOutReason.staleSession);
      expect(h.c.read(authControllerProvider).status, AuthStatus.signedOut);
    });
    test("role 'banned' signs out with the account-locked reason", () async {
      final h = _auth(me: {'id': 5, 'role': 'banned'});
      await h.c.read(authControllerProvider.notifier).bootstrap();
      final s = h.c.read(authControllerProvider);
      expect(s.status, AuthStatus.signedOut);
      expect(s.reason, SignOutReason.accountLocked);
      expect(await h.tokens.hasSession, isFalse);
    });
    test('a valid tasker stays signed in', () async {
      final h = _auth(me: {'id': 5, 'role': 'tasker'});
      await h.c.read(authControllerProvider.notifier).bootstrap();
      expect(h.c.read(authControllerProvider).status, AuthStatus.signedIn);
      expect(h.c.read(authControllerProvider).user!.role, 'tasker');
    });
    test('a network blip keeps the session (no sign-out)', () async {
      final h = _auth(meError: ApiException('network', 'x'));
      await h.c.read(authControllerProvider.notifier).bootstrap();
      expect(h.c.read(authControllerProvider).status, AuthStatus.signedIn);
      expect(await h.tokens.hasSession, isTrue);
    });
    test('a 401 from /me is an expired session notice', () async {
      final h = _auth(meError: ApiException('AUTH_REQUIRED', 'x', status: 401));
      await h.c.read(authControllerProvider.notifier).bootstrap();
      expect(h.c.read(authControllerProvider).reason, SignOutReason.sessionExpired);
    });
    test('login that returns a banned / stale user does not sign in', () async {
      final banned = _auth(loginUser: {'id': 1, 'role': 'banned'});
      expect(await banned.c.read(authControllerProvider.notifier).login(email: 'a@b.c', password: 'x'), isFalse);
      expect(banned.c.read(authControllerProvider).reason, SignOutReason.accountLocked);
      expect(await banned.tokens.hasSession, isFalse);

      final stale = _auth(loginUser: {'id': 1, 'role': 'provider'});
      expect(await stale.c.read(authControllerProvider.notifier).login(email: 'a@b.c', password: 'x'), isFalse);
      expect(stale.c.read(authControllerProvider).reason, SignOutReason.staleSession);
    });
    test('markSignedOut (refresh lost) carries the session-expired reason', () {
      final h = _auth();
      h.c.read(authControllerProvider.notifier).markSignedOut();
      expect(h.c.read(authControllerProvider).reason, SignOutReason.sessionExpired);
    });
  });

  test('UX-M40 a tasker lands on /p after login when there is no from', () {
    expect(resumeAfterLogin(null, 'tasker'), '/p');
    expect(resumeAfterLogin('', 'customer'), '/');
    expect(resumeAfterLogin('/bookings', 'tasker'), '/bookings');
  });

  group('login screen', () {
    testWidgets('UX-M04 a password shorter than 8 can be submitted; empty cannot', (t) async {
      t.view.physicalSize = const Size(430, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final logins = <String>[];
      final fake = _RecordingAuth(logins);
      await t.pumpWidget(_app(const LoginScreen(), overrides: [authControllerProvider.overrideWith(() => fake)]));
      await t.enterText(find.byType(TextFormField).at(0), 'old@user.vn');
      await t.tap(find.byKey(const ValueKey('login-submit')));
      await t.pumpAndSettle();
      expect(logins, isEmpty);
      expect(find.text(_vi.cust2Required), findsOneWidget);

      await t.enterText(find.byType(TextFormField).at(1), 'abc12');
      await t.tap(find.byKey(const ValueKey('login-submit')));
      await t.pumpAndSettle();
      expect(logins, ['old@user.vn/abc12']);
      expect(find.text(_vi.passwordMin8), findsNothing);
    });

    testWidgets('UX-M05 a previous failure is cleared on entry and when a field is edited', (t) async {
      t.view.physicalSize = const Size(430, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final fake = _RecordingAuth([], initial: AuthState(status: AuthStatus.signedOut, failure: ApiException('AUTH_REQUIRED', 'x', status: 401)));
      await t.pumpWidget(_app(const LoginScreen(), overrides: [authControllerProvider.overrideWith(() => fake)]));
      await t.pumpAndSettle();
      expect(find.text(_vi.cust2ErrLoginInvalid), findsNothing, reason: 'cleared on re-entry');

      fake.setFailure(ApiException('AUTH_REQUIRED', 'x', status: 401));
      await t.pump();
      expect(find.text(_vi.cust2ErrLoginInvalid), findsOneWidget);
      await t.enterText(find.byType(TextFormField).at(0), 'a');
      await t.pump();
      expect(find.text(_vi.cust2ErrLoginInvalid), findsNothing, reason: 'cleared on edit');
    });

    testWidgets('UX-M02/M03 forced sign-out shows the localized notice', (t) async {
      for (final (reason, text) in [
        (SignOutReason.staleSession, _vi.authSessionStale),
        (SignOutReason.accountLocked, _vi.authAccountLocked),
        (SignOutReason.sessionExpired, _vi.cust2ErrSessionExpired),
      ]) {
        final fake = _RecordingAuth([], initial: AuthState(status: AuthStatus.signedOut, reason: reason));
        await t.pumpWidget(_app(const LoginScreen(), overrides: [authControllerProvider.overrideWith(() => fake)]));
        await t.pumpAndSettle();
        expect(find.text(text), findsOneWidget, reason: '$reason');
      }
      expect(_vi.authSessionStale, 'Phiên đăng nhập đã cũ, vui lòng đăng nhập lại');
    });

    testWidgets('UX-M07 OTP resend is disabled with a countdown for 60 s', (t) async {
      t.view.physicalSize = const Size(430, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final fake = _RecordingAuth([]);
      await t.pumpWidget(_app(const LoginScreen(), overrides: [authControllerProvider.overrideWith(() => fake)]));
      await t.tap(find.text(_vi.cust2LoginModePhone));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('login-phone')), '0901110002');
      await t.tap(find.byKey(const ValueKey('login-send-otp')));
      await t.pump();
      await t.pump();
      expect(fake.otpRequests, hasLength(1));
      final btn = find.byKey(const ValueKey('login-send-otp'));
      expect(find.text(_vi.otpResendIn(60)), findsOneWidget);
      expect(t.widget<OutlinedButton>(btn).onPressed, isNull);

      await t.pump(const Duration(seconds: 30));
      expect(find.text(_vi.otpResendIn(30)), findsOneWidget);
      expect(t.widget<OutlinedButton>(btn).onPressed, isNull);

      await t.pump(const Duration(seconds: 30));
      expect(find.text(_vi.cust2ResendCode), findsOneWidget);
      expect(t.widget<OutlinedButton>(btn).onPressed, isNotNull);
    });

    testWidgets('UX-M07 a 429 uses the server Retry-After as the cooldown', (t) async {
      t.view.physicalSize = const Size(430, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      final fake = _RecordingAuth([])
        ..otpFailure = ApiException('RATE_LIMIT', 'slow', status: 429, retryAfter: const Duration(seconds: 42));
      await t.pumpWidget(_app(const LoginScreen(), overrides: [authControllerProvider.overrideWith(() => fake)]));
      await t.tap(find.text(_vi.cust2LoginModePhone));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('login-phone')), '0901110002');
      await t.tap(find.byKey(const ValueKey('login-send-otp')));
      await t.pump();
      await t.pump();
      expect(find.text(_vi.otpResendIn(42)), findsOneWidget);
      expect(find.text(_vi.cust2ErrRateLimit), findsOneWidget);
      await t.pump(const Duration(seconds: 42));
    });
  });

  group('ResendCooldown', () {
    test('only a rate limit starts a cooldown after a failed send', () {
      final c = ResendCooldown();
      addTearDown(c.dispose);
      c.startAfterFailure(ApiException('network', 'x'));
      expect(c.active, isFalse);
      c.startAfterFailure(ApiException('RATE_LIMIT', 'x', status: 429));
      expect(c.remaining, 60);
      c.startAfterFailure(ApiException('RATE_LIMIT', 'x', status: 429, retryAfter: const Duration(seconds: 7)));
      expect(c.remaining, 7);
    });
  });

  group('UX-M38 unknown route', () {
    testWidgets('shows the friendly page with a Go-home button and never the raw URI', (t) async {
      final tokens = InMemoryTokenStore();
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authControllerProvider.overrideWith(() => FakeAuthController(const AuthState(status: AuthStatus.signedOut))),
        homeProvider.overrideWith((ref) async => throw ApiException('network', 'x')),
      ]);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildTheme(lightColorScheme),
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      router.go('/definitely/not/a/route?x=1');
      await t.pumpAndSettle();
      expect(find.text(_vi.notFoundBody), findsOneWidget);
      expect(find.textContaining('definitely'), findsNothing);
      await t.tap(find.byKey(const ValueKey('not-found-home')));
      await t.pumpAndSettle();
      expect(find.text(_vi.notFoundBody), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/');
    });
  });

  group('ErrorRetry takes the typed error (UX-M23)', () {
    testWidgets('offline / maintenance / rate limit get their own copy', (t) async {
      for (final (e, text) in [
        (ApiException('network', 'x'), _vi.cust2ErrNetwork),
        (ApiException('MAINTENANCE', 'x', status: 503), _vi.cust2ErrMaintenance),
        (ApiException('RATE_LIMIT', 'x', status: 429), _vi.cust2ErrRateLimit),
        (StateError('boom'), _vi.genericError),
      ]) {
        await t.pumpWidget(_app(Scaffold(body: ErrorRetry(error: e, onRetry: () {}))));
        expect(find.text(text), findsOneWidget);
        expect(find.text(_vi.retry), findsOneWidget);
      }
    });
    testWidgets('a 404 shows not-found without a pointless Retry; a non-API error is generic', (t) async {
      await t.pumpWidget(_app(Scaffold(body: ErrorRetry(error: ApiException('NOT_FOUND', 'x', status: 404), onRetry: () {}))));
      expect(find.text(_vi.cust2ErrNotFound), findsOneWidget);
      expect(find.text(_vi.retry), findsNothing);
      await t.pumpWidget(_app(Scaffold(body: ErrorRetry(error: StateError('internal detail'), onRetry: () {}))));
      expect(find.textContaining('internal detail'), findsNothing);
      expect(find.text(_vi.genericError), findsOneWidget);
    });
  });

  group('UX-M28 live share tolerates transient failures', () {
    Future<void> pump(WidgetTester t, List<LivePingResult> script, List<int> calls) async {
      await t.pumpWidget(_app(Scaffold(
        body: LiveShareToggle(
          enRoute: true,
          interval: const Duration(seconds: 10),
          onPing: () async {
            calls.add(calls.length);
            return script[(calls.length - 1).clamp(0, script.length - 1)];
          },
        ),
      )));
      await t.tap(find.byType(Switch));
      await t.pump();
      await t.pump();
    }

    bool isOn(WidgetTester t) => t.widget<Switch>(find.byType(Switch)).value;

    testWidgets('two failures then success keeps sharing and backs off', (t) async {
      final calls = <int>[];
      await pump(t, [LivePingResult.retry, LivePingResult.retry, LivePingResult.ok], calls);
      expect(calls, hasLength(1));
      expect(isOn(t), isTrue);
      expect(find.textContaining('--:--'), findsOneWidget, reason: 'reconnecting copy');
      await t.pump(const Duration(seconds: 19)); // backoff = 2x interval after 1 failure
      expect(calls, hasLength(1));
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(calls, hasLength(2));
      await t.pump(const Duration(seconds: 40)); // 4x after 2 failures
      await t.pump();
      expect(calls, hasLength(3));
      expect(isOn(t), isTrue);
      expect(find.textContaining('--:--'), findsNothing);
      await t.tap(find.byType(Switch)); // off → cancels the timer
      await t.pump();
    });

    testWidgets('stops after 3 consecutive failures', (t) async {
      final calls = <int>[];
      await pump(t, [LivePingResult.retry], calls);
      await t.pump(const Duration(seconds: 20));
      await t.pump();
      await t.pump(const Duration(seconds: 40));
      await t.pump();
      expect(calls, hasLength(3));
      expect(isOn(t), isFalse);
      expect(find.text(_vi.prov2LiveShareStopped), findsOneWidget);
    });

    testWidgets('a definitive refusal stops at once', (t) async {
      final calls = <int>[];
      await pump(t, [LivePingResult.stop], calls);
      expect(calls, hasLength(1));
      expect(isOn(t), isFalse);
    });
  });

  group('UX-M33 idempotency ledger scope', () {
    test('the same action under another user gets a different key', () async {
      var uid = 1;
      final l = IdempotencyLedger(userId: () => uid);
      final a1 = await l.keyFor('payout:100000');
      expect(await l.keyFor('payout:100000'), a1, reason: 'same user retry reuses');
      uid = 2;
      final b = await l.keyFor('payout:100000');
      expect(b, isNot(a1));
      uid = 1;
      expect(await l.keyFor('payout:100000'), a1, reason: 'user 1 still has its own pending key');
    });

    test('persisted entries are user-prefixed', () async {
      final store = MemoryPendingKeyStore();
      final l = IdempotencyLedger(store: store, userId: () => 7);
      await l.keyFor('payout:5');
      expect(store.value, contains('u7|payout:5'));
    });

    test('forget and run use the same user scope', () async {
      var uid = 1;
      final l = IdempotencyLedger(userId: () => uid);
      final k = await l.keyFor('cash-received:9');
      await l.forget('cash-received:9');
      expect(await l.keyFor('cash-received:9'), isNot(k));
    });

    test('clear() drops every pending key, in memory and in the store', () async {
      final store = MemoryPendingKeyStore();
      var uid = 1;
      final l = IdempotencyLedger(store: store, userId: () => uid);
      final k1 = await l.keyFor('payout:5');
      uid = 2;
      await l.keyFor('payout:5');
      expect(store.value, isNotNull);
      await l.clear();
      expect(store.value, isNull);
      uid = 1;
      expect(await l.keyFor('payout:5'), isNot(k1));
      // a "restarted app" reading the cleared store starts empty too
      final after = IdempotencyLedger(store: store, userId: () => 1);
      expect(store.value, isNotNull); // keyFor above persisted a fresh one
      expect(await after.keyFor('payout:5'), await l.keyFor('payout:5'));
    });

    testWidgets('sign-out KEEPS pending money keys (per-user scoped; replay after re-login)', (t) async {
      final store = MemoryPendingKeyStore();
      final ledger = IdempotencyLedger(store: store, userId: () => 1);
      await ledger.keyFor('payout:5');
      expect(store.value, isNotNull);
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        idempotencyLedgerProvider.overrideWithValue(ledger),
        authControllerProvider.overrideWith(() => FakeAuthController(const AuthState(status: AuthStatus.signedOut))),
      ]);
      addTearDown(container.dispose);
      late WidgetRef captured;
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: Consumer(builder: (_, ref, _) {
          captured = ref;
          return const SizedBox();
        }),
      ));
      final before = await ledger.keyFor('payout:5');
      clearUserScopedState(captured);
      await t.pump();
      expect(store.value, isNotNull);
      expect(await ledger.keyFor('payout:5'), before);
      // Another account never sees it.
      final other = IdempotencyLedger(store: store, userId: () => 2);
      expect(await other.keyFor('payout:5'), isNot(before));
    });
  });

  group('UX-M26 checkout inline errors', () {
    testWidgets('confirming with empty fields shows a per-field error, not just a snackbar', (t) async {
      t.view.physicalSize = const Size(393, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final tokens = InMemoryTokenStore();
      final api = _CheckoutApi(KycoApiClient(tokens: tokens), tokens);
      await t.pumpWidget(_app(const CheckoutScreen(serviceId: 101), overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authControllerProvider.overrideWith(() => FakeAuthController(const AuthState(status: AuthStatus.signedIn, user: AuthUser(id: 7, role: 'customer')))),
        kycoApiProvider.overrideWithValue(api),
      ]));
      await t.pumpAndSettle();
      expect(find.text(_vi.cust2Required), findsNothing);
      await t.tap(find.text(_vi.confirmBooking));
      await t.pumpAndSettle();
      // date, time, ward, street
      expect(find.text(_vi.cust2Required), findsNWidgets(4));
      expect(api.created, 0, reason: 'no request for an invalid form');
    });

    testWidgets('a malformed serviceId (0) is not-found and issues no request', (t) async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final tokens = InMemoryTokenStore();
      final api = _CheckoutApi(KycoApiClient(tokens: tokens), tokens);
      await t.pumpWidget(_app(const CheckoutScreen(serviceId: 0), overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(tokens),
        authControllerProvider.overrideWith(() => FakeAuthController(const AuthState(status: AuthStatus.signedOut))),
        kycoApiProvider.overrideWithValue(api),
      ]));
      await t.pumpAndSettle();
      expect(find.text(_vi.notFoundBody), findsOneWidget);
      expect(api.detailCalls, 0);
    });
  });
}

class _CheckoutApi extends KycoApi {
  _CheckoutApi(super.c, super.t);
  int created = 0;
  int detailCalls = 0;
  @override
  Future<ServiceDetail> serviceDetail(int id) async {
    detailCalls++;
    return const ServiceDetail(id: 101, name: 'Vệ sinh nhà', basePriceVnd: 480000, durationMinutes: 120);
  }

  @override
  Future<List<ActiveCity>> locationsTree() async => const [
        ActiveCity(id: 1, slug: 'hcm', name: 'HCM', wards: [ActiveWard(code: 1, name: 'Phường 1', provinceCode: 79)]),
      ];
  @override
  Future<List<Neighborhood>> neighborhoods(int wardCode) async => const [];
  @override
  Future<CreateBookingResult> createBooking(BookingDraft draft) async {
    created++;
    return const CreateBookingResult(kind: 'created', bookingId: 1);
  }
}

class _RecordingAuth extends AuthController {
  _RecordingAuth(this.logins, {this.initial = const AuthState(status: AuthStatus.signedOut)});
  final List<String> logins;
  final AuthState initial;
  final otpRequests = <String>[];
  Object? otpFailure;
  @override
  AuthState build() => initial;
  @override
  Future<void> bootstrap() async {}
  void setFailure(ApiException e) => state = state.copyWith(failure: e);
  @override
  Future<Object?> requestLoginOtp(String phone) async {
    otpRequests.add(phone);
    return otpFailure;
  }

  @override
  Future<bool> login({required String email, required String password, String? totpCode}) async {
    logins.add('$email/$password');
    return false;
  }
}
