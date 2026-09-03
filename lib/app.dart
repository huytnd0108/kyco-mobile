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
import 'features/home/home_providers.dart';
import 'features/home/home_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: ref.watch(_authRefreshProvider),
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;
      const authScreens = {'/login', '/signup'};
      final isProtected = loc.startsWith('/bookings'); // '/account' stays public
      if (status == AuthStatus.unknown) return isProtected ? '/' : null;
      final signedIn = status == AuthStatus.signedIn;
      if (signedIn && authScreens.contains(loc)) return '/';
      if (!signedIn && isProtected) return '/login';
      return null;
    },
    routes: [
      // Auth OUTSIDE the shell (full-screen, no tabs).
      GoRoute(path: '/login', parentNavigatorKey: _rootKey, builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', parentNavigatorKey: _rootKey, builder: (_, _) => const SignupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AdaptiveScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
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
