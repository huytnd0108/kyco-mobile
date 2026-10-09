import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import 'core/adaptive.dart';
import 'core/locale_controller.dart';
import 'features/account/account_providers.dart';
import 'features/account/account_screen.dart';
import 'features/account/addresses_screen.dart';
import 'features/account/content_screens.dart';
import 'features/account/invite_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/bookings/booking_detail_screen.dart';
import 'features/bookings/bookings_providers.dart';
import 'features/bookings/bookings_screen.dart';
import 'features/checkout/book_now_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/checkout/draft_store.dart';
import 'features/home/home_providers.dart';
import 'features/home/home_screen.dart';
import 'features/locations/city_screen.dart';
import 'features/locations/city_service_screen.dart';
import 'features/locations/locations_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/notifications/notifications_providers.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/providers/provider_screen.dart';
// ── provider (/p) shell + stubs ──
import 'features/become_tasker/become_tasker_screen.dart';
import 'features/provider_availability/provider_availability_screen.dart';
import 'features/provider_compliance/provider_cancellations_screen.dart';
import 'features/provider_compliance/provider_fine_appeal_screen.dart';
import 'features/provider_compliance/provider_fines_screen.dart';
import 'features/provider_compliance/provider_referrals_screen.dart';
import 'features/provider_growth/provider_bonuses_screen.dart';
import 'features/provider_growth/provider_goals_screen.dart';
import 'features/provider_growth/provider_leaderboard_screen.dart';
import 'features/provider_growth/provider_vip_screen.dart';
import 'features/provider_home/provider_home_screen.dart';
import 'features/provider_job_detail/provider_job_detail_screen.dart';
import 'features/provider_jobs/provider_jobs_screen.dart';
import 'features/provider_shell/provider_more_screen.dart';
import 'features/provider_shell/provider_scaffold.dart';
import 'features/provider_support/provider_support_screen.dart';
import 'features/provider_wallet/provider_wallet_screen.dart';
import 'features/service_detail/service_detail_screen.dart';
import 'features/services/services_providers.dart';
import 'features/services/services_screen.dart';
import 'features/subscriptions/subscriptions_providers.dart';
import 'features/subscriptions/subscriptions_screen.dart';
import 'theme/color_schemes.dart';
import 'theme/theme_mode_controller.dart';

/// Bridges Riverpod auth state to go_router's refreshListenable so the redirect
/// re-runs on login / logout / refresh-lost.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

final _authRefreshProvider = Provider<_AuthRefresh>((ref) => _AuthRefresh(ref));

final _rootKey = GlobalKey<NavigatorState>();

/// The GUEST-FIRST redirect rule, pure + table-testable (see redirect_test).
/// PUBLIC forever: / /services /services/:id /book-now /checkout/* /locations/*
/// /providers/:id /subscriptions /notifications /account. The confirm-booking
/// gate is IN-SCREEN, never here — NEVER add /checkout (or anything) to the
/// protected set.
String? guestFirstRedirect({required AuthStatus status, required String loc, String? from}) {
  const authScreens = {'/login', '/signup'};
  final isProtected = loc.startsWith('/bookings') || loc.startsWith('/messages');
  if (status == AuthStatus.unknown) return isProtected ? '/' : null;
  final signedIn = status == AuthStatus.signedIn;
  if (signedIn && authScreens.contains(loc)) {
    // Resume the flow the guest came from (e.g. checkout) after signing in.
    return from ?? '/';
  }
  if (!signedIn && isProtected) return '/login?from=$loc';
  return null;
}

/// True for the provider shell prefix ONLY — matches `/p` and `/p/*`, never the
/// customer `/providers/:id` route (which begins with `/p` but not `/p/`).
bool isProviderPath(String loc) => loc == '/p' || loc.startsWith('/p/');

/// The composed router redirect. Provider role-gating applies ONLY to `/p*`;
/// every other path is delegated to [guestFirstRedirect] byte-for-byte, so the
/// customer guest-first semantics are preserved exactly. Pure + table-testable.
String? appRedirect({
  required AuthStatus status,
  String? role,
  required String loc,
  String? from,
}) {
  if (isProviderPath(loc)) {
    // Mid-bootstrap: never bounce to login (mirrors the guest-first unknown rule).
    if (status == AuthStatus.unknown) return '/';
    if (status != AuthStatus.signedIn) return '/login?from=$loc';
    // Role-UNKNOWN: bootstrap entered optimistically (signedIn with user==null
    // after a non-401 /me failure — offline / 503 dark-launch), so `role` is
    // null but the account may well be a provider. Treat it exactly like the
    // `unknown` status above (send /p* home), NEVER to become-tasker — otherwise
    // a real provider is misrouted to onboarding for the whole session. Role
    // backfills via AuthController.refreshMe once /me succeeds.
    if (role == null) return '/';
    // A signed-in non-provider is sent to onboarding (pending_provider sees the
    // "under review" status inside /become-tasker).
    if (role != 'provider' && role != 'admin') return '/become-tasker';
    return null;
  }
  // Public onboarding — reachable signed-out; guest-first would allow it anyway.
  if (loc.startsWith('/become-tasker')) return null;
  // Signed in on an auth screen: resume `from`, but never into the provider
  // shell for a role that can't enter it (drop a `/p*` from → home).
  if (status == AuthStatus.signedIn && (loc == '/login' || loc == '/signup')) {
    return resumeAfterLogin(from, role);
  }
  return guestFirstRedirect(status: status, loc: loc, from: from);
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: ref.watch(_authRefreshProvider),
    // GUEST-FIRST. Only owned-data areas are protected; everything else
    // (home, services, book-now, checkout, locations, providers, subscriptions,
    // notifications, account) is public. The confirm-booking wall is IN-SCREEN,
    // never a route redirect — NEVER add /checkout (or anything else) here.
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return appRedirect(
        status: auth.status,
        role: auth.user?.role,
        loc: state.matchedLocation,
        from: state.uri.queryParameters['from'],
      );
    },
    routes: [
      // Auth OUTSIDE the shell (full-screen, no tabs).
      GoRoute(path: '/login', parentNavigatorKey: _rootKey, builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', parentNavigatorKey: _rootKey, builder: (_, _) => const SignupScreen()),

      // Full-screen flows on the ROOT navigator (over the tab shell).
      GoRoute(
        path: '/book-now',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => BookNowScreen(
          category: s.uri.queryParameters['category'],
          q: s.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        path: '/checkout/:serviceId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => CheckoutScreen(serviceId: int.tryParse(s.pathParameters['serviceId'] ?? '') ?? 0),
      ),
      GoRoute(
        path: '/locations',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const LocationsScreen(),
        routes: [
          GoRoute(
            path: ':city',
            builder: (_, s) => CityScreen(slug: s.pathParameters['city'] ?? ''),
            routes: [
              GoRoute(
                path: ':service',
                builder: (_, s) => CityServiceScreen(
                  citySlug: s.pathParameters['city'] ?? '',
                  service: s.pathParameters['service'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/providers/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ProviderScreen(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0),
      ),
      GoRoute(
        path: '/subscriptions',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SubscriptionsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      // Account sub-screens (full-screen over the tabs). /help + /legal are
      // public reads; /invite + /addresses gate in-screen (guest-first).
      GoRoute(path: '/help', parentNavigatorKey: _rootKey, builder: (_, _) => const HelpScreen()),
      GoRoute(
        path: '/legal/:doc',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => LegalDocScreen(doc: s.pathParameters['doc'] ?? ''),
      ),
      GoRoute(path: '/invite', parentNavigatorKey: _rootKey, builder: (_, _) => const InviteScreen()),
      GoRoute(
        path: '/addresses',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AddressesScreen(),
      ),

      // The 5-tab shell (mirrors web bottom-nav order).
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/services',
              builder: (_, s) => ServicesScreen(
                category: s.uri.queryParameters['category'],
                subcategory: s.uri.queryParameters['subcategory'],
                q: s.uri.queryParameters['q'],
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, s) => ServiceDetailScreen(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/bookings',
              builder: (_, _) => const BookingsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) => BookingDetailScreen(id: int.tryParse(s.pathParameters['id'] ?? '')),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/messages',
              builder: (_, _) => const MessagesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, s) => MessageThreadScreen(id: int.tryParse(s.pathParameters['id'] ?? '') ?? 0),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/account', builder: (_, _) => const AccountScreen()),
          ]),
        ],
      ),

      // ── Provider onboarding (PUBLIC — a guest can start it) ──
      GoRoute(
        path: '/become-tasker',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const BecomeTaskerScreen(),
      ),

      // ── Provider (/p) shell — role-gated by appRedirect. Its own 5-tab
      // ProviderScaffold; detail + More sub-screens ride the root navigator so
      // they present full-screen over the provider tabs. ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ProviderScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/p',
              builder: (_, _) => const ProviderHomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/p/jobs',
              builder: (_, _) => const ProviderJobsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, _) => const ProviderJobDetailScreen(),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/p/wallet', builder: (_, _) => const ProviderWalletScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/p/availability', builder: (_, _) => const ProviderAvailabilityScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/p/more', builder: (_, _) => const ProviderMoreScreen()),
          ]),
        ],
      ),
      // Provider secondary surfaces (reached from the More menu) — full-screen.
      GoRoute(path: '/p/bonuses', parentNavigatorKey: _rootKey, builder: (_, _) => const ProviderBonusesScreen()),
      GoRoute(path: '/p/goals', parentNavigatorKey: _rootKey, builder: (_, _) => const ProviderGoalsScreen()),
      GoRoute(path: '/p/leaderboard', parentNavigatorKey: _rootKey, builder: (_, _) => const ProviderLeaderboardScreen()),
      GoRoute(path: '/p/vip', parentNavigatorKey: _rootKey, builder: (_, _) => const ProviderVipScreen()),
      GoRoute(
        path: '/p/fines',
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ProviderFinesScreen(),
        routes: [
          GoRoute(
            path: ':id/appeal',
            parentNavigatorKey: _rootKey,
            builder: (_, _) => const ProviderFineAppealScreen(),
          ),
        ],
      ),
      GoRoute(path: '/p/cancellations', parentNavigatorKey: _rootKey, builder: (_, _) => const ProviderCancellationsScreen()),
      GoRoute(path: '/p/referrals', parentNavigatorKey: _rootKey, builder: (_, _) => const ProviderReferralsScreen()),
      GoRoute(path: '/p/support', parentNavigatorKey: _rootKey, builder: (_, _) => const ProviderSupportScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Kyco')),
      body: Center(child: Text(AppLocalizations.of(context).pageNotFound(state.uri.toString()))),
    ),
  );
});

/// Invalidate every user-scoped provider + clear persisted checkout drafts.
/// Called on any transition into signed-out.
void clearUserScopedState(WidgetRef ref) {
  ref.read(selectedBookingIdProvider.notifier).state = null;
  ref.invalidate(bookingsProvider);
  ref.invalidate(bookingsPagerProvider);
  ref.invalidate(bookingDetailProvider);
  ref.invalidate(conversationsProvider);
  ref.invalidate(notificationsControllerProvider);
  ref.invalidate(accountMeProvider);
  ref.invalidate(inviteStatsProvider);
  ref.invalidate(addressesProvider);
  ref.invalidate(mySubscriptionsProvider);
  clearCheckoutDrafts(ref);
}

class KycoApp extends ConsumerStatefulWidget {
  const KycoApp({super.key});
  @override
  ConsumerState<KycoApp> createState() => _KycoAppState();
}

class _KycoAppState extends ConsumerState<KycoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Re-fetch server content in the new language when the locale changes.
    ref.listen(localeControllerProvider, (_, _) {
      ref.invalidate(homeProvider);
      ref.invalidate(bookingsProvider);
      // Kept-alive shell branches (Services) must re-fetch in the new language.
      ref.invalidate(catalogTreeProvider);
    });
    // Sign-out (explicit or refresh-lost): drop EVERY user-scoped cache so the
    // next account never sees the previous one's data. (User-scoped providers
    // also watch authUserIdProvider; this is the belt-and-braces reset for the
    // kept-alive ones + local drafts.)
    ref.listen(authControllerProvider, (prev, next) {
      if (next.status == AuthStatus.signedOut && prev?.status != AuthStatus.signedOut) {
        clearUserScopedState(ref);
      }
      // Explicit logout lands on home, whatever screen it was triggered from.
      if (next.explicitLogout && !(prev?.explicitLogout ?? false)) {
        ref.read(routerProvider).go('/');
      }
      // Role-unknown optimistic session (bootstrap's non-401 /me failure): try
      // once to backfill the user so a real provider can reach /p this session.
      // refreshMe no-ops unless still signedIn-with-null-user, so no loop.
      if (next.status == AuthStatus.signedIn && next.user == null) {
        ref.read(authControllerProvider.notifier).refreshMe();
      }
    });
    final router = ref.watch(routerProvider);
    final mode = ref.watch(themeModeControllerProvider);
    return MaterialApp.router(
      onGenerateTitle: (_) => 'Kyco',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(lightColorScheme),
      darkTheme: buildTheme(darkColorScheme),
      themeMode: mode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: ref.watch(localeControllerProvider),
      localeResolutionCallback: (device, supported) {
        if (device != null) {
          for (final l in supported) {
            if (l.languageCode == device.languageCode) return l;
          }
        }
        return const Locale('vi');
      },
      routerConfig: router,
    );
  }
}
