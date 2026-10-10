import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token persistence seam. The concrete SecureTokenStore uses the platform
/// keychain/keystore; tests substitute an in-memory implementation.
abstract class TokenStore {
  Future<String?> get accessToken;
  Future<String?> get refreshToken;
  Future<void> save({required String access, required String refresh});
  Future<void> setAccess(String access);

  /// When the stored access token expires (persisted from the auth response's
  /// `expiresIn`), or null when unknown — the client then falls back to the
  /// reactive 401 → refresh path only.
  Future<DateTime?> get accessExpiresAt;
  Future<void> setAccessExpiresAt(DateTime? at);
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
  static const _kAccessExp = 'kyco.accessExpiresAt';

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
  Future<DateTime?> get accessExpiresAt async {
    final raw = await _s.read(key: _kAccessExp);
    final ms = raw == null ? null : int.tryParse(raw);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  Future<void> setAccessExpiresAt(DateTime? at) => at == null
      ? _s.delete(key: _kAccessExp)
      : _s.write(key: _kAccessExp, value: '${at.toUtc().millisecondsSinceEpoch}');

  @override
  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
    await _s.delete(key: _kAccessExp);
  }

  @override
  Future<bool> get hasSession async => (await accessToken) != null;
}
