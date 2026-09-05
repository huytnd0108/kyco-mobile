import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import 'core/adaptive.dart';
import 'core/locale_controller.dart';
import 'features/account/account_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/bookings/booking_detail_screen.dart';
import 'features/bookings/bookings_providers.dart';
import 'features/bookings/bookings_screen.dart';
import 'features/checkout/book_now_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/home/home_providers.dart';
import 'features/home/home_screen.dart';
import 'features/locations/city_screen.dart';
import 'features/locations/city_service_screen.dart';
import 'features/locations/locations_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/providers/provider_screen.dart';
import 'features/service_detail/service_detail_screen.dart';
import 'features/services/services_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: ref.watch(_authRefreshProvider),
    // GUEST-FIRST. Only owned-data areas are protected; everything else
    // (home, services, book-now, checkout, locations, providers, subscriptions,
    // notifications, account) is public. The confirm-booking wall is IN-SCREEN,
    // never a route redirect — NEVER add /checkout (or anything else) here.
    redirect: (context, state) => guestFirstRedirect(
      status: ref.read(authControllerProvider).status,
      loc: state.matchedLocation,
      from: state.uri.queryParameters['from'],
    ),
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
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Kyco')),
      body: Center(child: Text(AppLocalizations.of(context).pageNotFound(state.uri.toString()))),
    ),
  );
});

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
    });
    // Clear a stale two-pane selection across sign-out (user A → user B).
    ref.listen(authControllerProvider, (_, next) {
      if (next.status == AuthStatus.signedOut) {
        ref.read(selectedBookingIdProvider.notifier).state = null;
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
