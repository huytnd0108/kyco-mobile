import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/api/token_store.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// Where to land after sign-in: the `from` flow the guest came from, except a
/// tasker-shell (`/p`, `/p/*`) target is dropped for a role that cannot
/// enter it (customer / pending_tasker / unknown) — they go home instead of
/// bouncing through the role gate into onboarding.
String resumeAfterLogin(String? from, String? role) {
  if (from == null || from.isEmpty) return role == 'tasker' ? '/p' : '/';
  final isTasker = from == '/p' || from.startsWith('/p/') || from.startsWith('/p?');
  if (isTasker && role != 'tasker' && role != 'admin') return '/';
  return from;
}

/// The signed-in user's id for user-scoped providers to `watch`: null when
/// signed out / unknown, 0 for an optimistic session whose user hasn't loaded.
/// Any account switch or sign-out changes it, so every watcher refetches or
/// drops its data automatically (no stale data across users).
final authUserIdProvider = Provider<int?>((ref) {
  final s = ref.watch(authControllerProvider);
  if (s.status != AuthStatus.signedIn) return null;
  return s.user?.id ?? 0;
});

enum AuthStatus { unknown, signedIn, signedOut }

/// Why the session ended without an explicit logout (login screen banner).
enum SignOutReason {
  /// A refresh / authed call was definitively rejected (401).
  sessionExpired,

  /// A stale pre-rename, unknown or missing role: re-login required.
  staleSession,

  /// The account is locked (role `banned`).
  accountLocked,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.busy = false,
    this.error,
    this.failure,
    this.explicitLogout = false,
    this.reason,
  });
  final AuthStatus status;
  final AuthUser? user;
  final bool busy;

  /// Legacy free-text error (goldens / [AuthController.genericError] sentinel).
  final String? error;

  /// The typed failure of the last auth action. Screens map it to localized
  /// copy via `apiErrorText` — never render `toString()`.
  final ApiException? failure;

  /// True only for the signed-out state produced by an explicit user logout
  /// (not a refresh-lost sign-out) — the app routes home on it.
  final bool explicitLogout;

  /// Set on a forced sign-out; shown as a notice on the login screen until the
  /// next login attempt. Not an error: [AuthController.clearError] keeps it.
  final SignOutReason? reason;

  AuthState copyWith({AuthStatus? status, AuthUser? user, bool? busy, String? error, ApiException? failure}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        busy: busy ?? this.busy,
        error: error,
        failure: failure,
        reason: reason,
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
      await _accept(user);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // The token is genuinely rejected (and the client's own refresh already
        // failed) — only NOW drop the stored session.
        await _signOut(SignOutReason.sessionExpired);
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

  /// Backfill the user when bootstrap entered optimistically (signedIn with a
  /// null user after a non-401 /me failure). Cheap and idempotent: no-ops unless
  /// the role is still unknown, and a failure leaves the optimistic session
  /// untouched so a later authed refresh can fill the role instead.
  Future<void> refreshMe() async {
    final s = state;
    if (s.status != AuthStatus.signedIn || s.user != null || s.busy) return;
    try {
      final user = await _api.me();
      // Re-check: only apply if we're still signed-in with no user (never race
      // a logout / sign-out that happened while /me was in flight).
      if (state.status == AuthStatus.signedIn && state.user == null) {
        await _accept(user);
      }
    } catch (_) {
      // Still offline / dark-launched — keep the optimistic session as-is.
    }
  }

  /// Re-read /me and apply it (role changes after approval / an application,
  /// OCD-060). Best effort: offline or a failed read keeps the current session;
  /// a definitive 401 ends it like any other authed call. Returns the fresh
  /// role, or null when it could not be read.
  Future<String?> reloadMe() async {
    if (state.status != AuthStatus.signedIn) return null;
    try {
      final user = await _api.me();
      if (state.status != AuthStatus.signedIn) return null;
      await _accept(user);
      return state.user?.role;
    } catch (_) {
      return null;
    }
  }

  Future<bool> login({required String email, required String password, String? totpCode}) =>
      _run(() => _api.login(email: email, password: password, totpCode: totpCode));

  /// Phone sign-in step 1: send a `purpose: 'login'` OTP. Returns null on
  /// success, else the typed failure (the screen localizes it).
  Future<Object?> requestLoginOtp(String phone) async {
    try {
      await _api.requestOtp(phone: phone, purpose: 'login');
      return null;
    } catch (e) {
      return e;
    }
  }

  /// Phone sign-in step 2: `/auth/login {phone, code[, totpCode]}`.
  Future<bool> loginWithOtp({required String phone, required String code, String? totpCode}) =>
      _run(() => _api.loginWithOtp(phone: phone, code: code, totpCode: totpCode));

  /// Clear a stale error (e.g. when switching login mode).
  void clearError() {
    if (state.error != null || state.failure != null) state = state.copyWith();
  }

  /// [consent] is non-null only when GET /v1/legal answered 200 (release-i).
  Future<bool> signup(
          {required String email, required String password, String? name, ConsentPayload? consent}) =>
      _run(() => _api.signup(email: email, password: password, name: name, consent: consent));

  /// Re-consent gate: record acceptance of the server's CURRENT Terms +
  /// Privacy (`POST /me/consents`), then refresh /me. Returns null on success,
  /// else the failure for the screen to localize.
  ///
  /// Never loops and changes the session state exactly ONCE (so the router sees
  /// a single transition): the fresh /me when it can be read, else the 201 body
  /// applied locally - a failing /me refresh cannot re-open the gate for a user
  /// who has just accepted.
  Future<Object?> acceptReconsent() async {
    if (state.status != AuthStatus.signedIn) return null;
    final ConsentStatus? accepted;
    try {
      final c = state.user?.consents;
      // consentSchema >= 2 -> per-document versions; absent/1/unreachable -> release-i max().
      LegalInfo? legal;
      try {
        legal = await _api.legal();
      } catch (_) {/* unreachable: legacy path */}
      final per = legal != null && legal.perDocumentConsent ? c?.perDocumentVersions(legal) : null;
      accepted = per != null
          ? await _api.recordConsents(termsVersion: per.$1, privacyVersion: per.$2)
          : await _api.recordConsents(version: c?.acceptVersion);
    } on ApiException catch (e) {
      // 422 = the version moved under us: pick up the new current version.
      if (e.status == 422) unawaited(reloadMe());
      return e;
    } catch (e) {
      return e;
    }
    AuthUser? fresh;
    try {
      fresh = await _api.me();
    } catch (_) {/* offline / maintenance: fall back to the 201 body below */}
    if (state.status != AuthStatus.signedIn) return null; // signed out meanwhile
    if (fresh != null) {
      await _accept(fresh);
    } else if (state.user != null) {
      state = AuthState(
          status: AuthStatus.signedIn,
          user: state.user!.withConsents(accepted ?? const ConsentStatus(needsReconsent: false)));
    }
    return null;
  }

  Future<bool> _run(Future<AuthResult> Function() action) async {
    state = AuthState(status: state.status, user: state.user, busy: true);
    try {
      final res = await action();
      final user = res.user;
      if (user != null && user.roleValidity != SessionValidity.ok) {
        await _accept(user);
        return false;
      }
      state = AuthState(status: AuthStatus.signedIn, user: await _withConsents(user));
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, failure: e);
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, error: genericError);
      return false;
    }
  }

  /// The login / signup response carries no `consents`; read them from /me so
  /// the re-consent gate decides before the first screen. Best effort: any
  /// failure keeps [user] as is (the next /me read fills it in).
  Future<AuthUser?> _withConsents(AuthUser? user) async {
    if (user == null || user.consents != null) return user;
    try {
      final fresh = await _api.me();
      return fresh.id == user.id ? user.withConsents(fresh.consents) : user;
    } catch (_) {
      return user;
    }
  }

  Future<void> logout() async {
    // Always land signed-out, even if the server revoke or keychain clear throws.
    try {
      await _api.logout();
    } finally {
      state = const AuthState(status: AuthStatus.signedOut, explicitLogout: true);
    }
  }

  /// Called by the API client when a refresh fails (session unrecoverable).
  void markSignedOut() {
    state = const AuthState(status: AuthStatus.signedOut, reason: SignOutReason.sessionExpired);
  }

  /// Accept [user] as the session user, unless the role says the session must
  /// end: banned → account-locked sign-out; stale / unknown / missing role →
  /// forced re-login. Never maps a bad role to customer or guest.
  Future<void> _accept(AuthUser user) async {
    switch (user.roleValidity) {
      case SessionValidity.ok:
        state = AuthState(status: AuthStatus.signedIn, user: user);
      case SessionValidity.banned:
        await _signOut(SignOutReason.accountLocked);
      case SessionValidity.stale:
        await _signOut(SignOutReason.staleSession);
    }
  }

  Future<void> _signOut(SignOutReason reason) async {
    try {
      await _tokens.clear();
    } finally {
      state = AuthState(status: AuthStatus.signedOut, reason: reason);
    }
  }
}
