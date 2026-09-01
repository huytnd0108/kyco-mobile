import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/bookings/bookings_screen.dart';
import 'features/home/home_screen.dart';

/// Bridges the Riverpod auth state to go_router's refreshListenable so the
/// redirect re-runs whenever the session changes (login / logout / refresh-lost).
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

final _authRefreshProvider = Provider<_AuthRefresh>((ref) => _AuthRefresh(ref));

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: ref.watch(_authRefreshProvider),
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;
      const authScreens = {'/login', '/signup'};
      const protected = {'/bookings'};
      // While the initial session check is in flight, keep protected routes out
      // (send them to public home) but let public routes render.
      if (status == AuthStatus.unknown) {
        return protected.contains(loc) ? '/' : null;
      }
      final signedIn = status == AuthStatus.signedIn;
      if (signedIn && authScreens.contains(loc)) return '/';
      if (!signedIn && protected.contains(loc)) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/bookings', builder: (_, _) => const BookingsScreen()),
    ],
    errorBuilder: (_, state) => Scaffold(
      appBar: AppBar(title: const Text('Kyco')),
      body: Center(child: Text('Không tìm thấy trang: ${state.uri}')),
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
    // Resolve the stored session once at startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB));
    return MaterialApp.router(
      title: 'Kyco',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: scheme, useMaterial3: true),
      routerConfig: router,
    );
  }
}
