import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token persistence seam. The concrete SecureTokenStore uses the platform
/// keychain/keystore; tests substitute an in-memory implementation.
abstract class TokenStore {
  Future<String?> get accessToken;
  Future<String?> get refreshToken;
  Future<void> save({required String access, required String refresh});
  Future<void> setAccess(String access);
  Future<void> clear();
  Future<bool> get hasSession;
}

/// Persists the mobile token pair in the platform keychain/keystore.
/// access = short-lived ES256/HS256 JWT; refresh = opaque, rotated on use.
class SecureTokenStore implements TokenStore {
  SecureTokenStore([FlutterSecureStorage? storage])
      : _s = storage ??
            const FlutterSecureStorage(
              // v11 defaults: Android = EncryptedSharedPreferences-backed;
              // iOS = Keychain. Pin iOS accessibility to first-unlock.
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _s;
  static const _kAccess = 'kyco.accessToken';
  static const _kRefresh = 'kyco.refreshToken';

  @override
  Future<String?> get accessToken => _s.read(key: _kAccess);
  @override
  Future<String?> get refreshToken => _s.read(key: _kRefresh);

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _s.write(key: _kAccess, value: access);
    await _s.write(key: _kRefresh, value: refresh);
  }

  @override
  Future<void> setAccess(String access) => _s.write(key: _kAccess, value: access);

  @override
  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
  }

  @override
  Future<bool> get hasSession async => (await accessToken) != null;
}
