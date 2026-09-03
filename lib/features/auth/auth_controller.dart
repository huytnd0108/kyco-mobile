import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/api/token_store.dart';
import '../../core/di.dart';
import '../../core/models.dart';

enum AuthStatus { unknown, signedIn, signedOut }

class AuthState {
  const AuthState({required this.status, this.user, this.busy = false, this.error});
  final AuthStatus status;
  final AuthUser? user;
  final bool busy;
  final String? error;

  AuthState copyWith({AuthStatus? status, AuthUser? user, bool? busy, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        busy: busy ?? this.busy,
        error: error,
      );

  static const unknown = AuthState(status: AuthStatus.unknown);
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  /// Sentinel for a non-API failure; screens map it to a localized message
  /// (the controller has no BuildContext / l10n).
  static const genericError = '__generic__';

  KycoApi get _api => ref.read(kycoApiProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  AuthState build() => AuthState.unknown;

  /// Resolve the initial session at app start: if a token is stored, validate
  /// it with /me (so a revoked token lands on sign-in, not a broken home).
  Future<void> bootstrap() async {
    if (!await _tokens.hasSession) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }
    try {
      final user = await _api.me();
      state = AuthState(status: AuthStatus.signedIn, user: user);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // The token is genuinely rejected (and the client's own refresh already
        // failed) — only NOW drop the stored session.
        await _tokens.clear();
        state = const AuthState(status: AuthStatus.signedOut);
      } else {
        // Offline / timeout / 503 MAINTENANCE / 5xx — the session may still be
        // valid. Keep the tokens and enter optimistically; any later authed call
        // that truly fails will refresh-then-auth-lost on its own. Never wipe a
        // session over a network blip or a dark-launch window.
        state = const AuthState(status: AuthStatus.signedIn);
      }
    } catch (_) {
      // Unexpected (e.g. a parse error): keep tokens, assume signed-in so the
      // app is usable and never stranded in `unknown`.
      state = const AuthState(status: AuthStatus.signedIn);
    }
  }

  Future<bool> login({required String email, required String password}) =>
      _run(() => _api.login(email: email, password: password));

  Future<bool> signup({required String email, required String password, String? name}) =>
      _run(() => _api.signup(email: email, password: password, name: name));

  Future<bool> _run(Future<AuthResult> Function() action) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final res = await action();
      state = AuthState(status: AuthStatus.signedIn, user: res.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, error: genericError);
      return false;
    }
  }

  Future<void> logout() async {
    // Always land signed-out, even if the server revoke or keychain clear throws.
    try {
      await _api.logout();
    } finally {
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  /// Called by the API client when a refresh fails (session unrecoverable).
  void markSignedOut() {
    state = const AuthState(status: AuthStatus.signedOut);
  }
}
