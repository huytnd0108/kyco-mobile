# Kyco Mobile (Flutter · iOS + Android)

Production Flutter client for the **kyco `/api/v1`** backend. Not a scaffold — it
ships real auth, secure token handling, and live API-backed screens.

## What it does
- **Auth**: email/password **login + signup** against `/v1/auth/*`; the mobile
  token pair (short-lived access JWT + rotated refresh) is stored in the
  platform keychain/keystore (`flutter_secure_storage`), never in plain prefs.
- **Session**: `/v1/auth/refresh` on 401 with **single-flight** refresh (one
  refresh for N concurrent 401s), a single retry, and a hard **auth-lost**
  signal that routes back to sign-in when the refresh is unrecoverable — no
  refresh storm, no retry loop.
- **Screens** (live data through the BFF/dualAuth reads):
  - **Home** — public `/v1/home` composite (service categories, greeting), pull-to-refresh, loading/error/empty states.
  - **Bookings** — signed-in `/v1/bookings` (Bearer), status chips, currency formatting.
  - Account menu (profile from `/v1/me`), logout.

## Architecture
```
lib/
  core/
    config.dart              # API base (compile-time --dart-define)
    models.dart              # tolerant typed models
    widgets.dart             # shared UI (brand, error banner, retry)
    di.dart                  # Riverpod providers
    api/
      token_store.dart       # TokenStore seam + SecureTokenStore (keychain)
      api_client.dart        # dio: Bearer attach, single-flight refresh, envelope unwrap
      kyco_api.dart          # typed endpoints (login/signup/refresh/logout/home/me/bookings)
      problem.dart           # ApiException from the {ok:false,code,message} envelope
  features/
    auth/                    # auth_controller (Notifier) + login/signup screens
    home/                    # home providers + screen
    bookings/                # bookings screen
  app.dart                   # go_router (auth-aware redirect + bootstrap), theme
  main.dart
test/
  api_client_test.dart       # refresh single-flight / no-loop / auth-lost / envelope
```
State = `flutter_riverpod`; routing = `go_router` (redirect keyed on auth status,
`refreshListenable` bridged to the auth state); HTTP = `dio`.

## Run / configure
The API base is compile-time injected (default `https://kyco.vn/api/v1`):
```bash
# iOS simulator → local backend
flutter run --dart-define=API_BASE=http://localhost:3088/api/v1
# Android emulator → host localhost
flutter run --dart-define=API_BASE=http://10.0.2.2:3088/api/v1
```
> The mobile API is behind the `api_mobile_v1_enabled` flag; if OFF the backend
> returns 503 MAINTENANCE on every `/v1` route.

## Build
```bash
flutter analyze      # 0 issues
flutter test         # api client + refresh path
flutter build apk    # Android (needs Android SDK)
```
**iOS binary** (`flutter build ios` / `.ipa`) **must run on macOS with Xcode** —
it cannot be produced on Linux. The full iOS project (`ios/Runner`, Info.plist,
display name "Kyco") is generated and ready; open `ios/Runner.xcworkspace` on a
Mac, set the signing team, then `flutter build ipa`.

## Security notes
- HTTPS-only by default (no ATS cleartext exception in prod); use a dev-only
  exception or an HTTPS tunnel to hit a local backend from a device.
- Tokens live only in the secure enclave-backed store; the access token is
  attached to authed calls only (public/`no-auth` calls and the refresh call
  itself are excluded).
