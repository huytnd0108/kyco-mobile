# Android release signing

Release builds are signed with a real upload keystore driven by
`android/key.properties` (gitignored). If that file is absent (fresh clone / CI
without secrets) the release build falls back to debug keys so
`flutter run --release` still works — **that APK is not publishable**.

## Files
- `android/app/kyco-release.jks` — the keystore. **gitignored. BACK IT UP.**
- `android/key.properties` — points at it + holds passwords. **gitignored.**
- `android/key.properties.example` — committed template.
- `build.gradle.kts` — loads `key.properties`, defines `signingConfigs.release`,
  and the `release` build type enables it + R8 (`isMinifyEnabled` +
  `isShrinkResources` + `proguard-rules.pro`).

## ⚠️ Keep the keystore forever
Google Play identifies the app by this keystore's key. **Once the app is
published you can never change it** (short of Play App Signing key reset). Store
`kyco-release.jks` + its passwords in a password manager / secret vault and back
it up off-machine. The current file was generated for UAT — regenerate + secure
your own before the first Play publish if you want a fresh key.

## Build locally
```bash
flutter build apk   --release --dart-define=API_BASE=https://kyco.vn/api/v1   # APK
flutter build appbundle --release --dart-define=API_BASE=https://kyco.vn/api/v1 # AAB for Play
```
Verify the signer:
```bash
$ANDROID_SDK/build-tools/<ver>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# Signer #1 certificate DN: CN=Kyco, OU=Mobile, O=Kyco, L=Ho Chi Minh City, C=VN
```

## CI (GitHub Actions)
Don't commit the keystore. Instead add secrets and recreate the files in a step:
`ANDROID_KEYSTORE_BASE64` (base64 of the .jks), `ANDROID_KEYSTORE_PASSWORD`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Before `flutter build`:
```bash
echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > android/app/kyco-release.jks
cat > android/key.properties <<EOF
storeFile=kyco-release.jks
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
keyPassword=$ANDROID_KEY_PASSWORD
EOF
```
