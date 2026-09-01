import '../models.dart';
import 'api_client.dart';
import 'token_store.dart';

/// Typed facade over the kyco /api/v1 endpoints the app uses.
class KycoApi {
  KycoApi(this._c, this._tokens);
  final KycoApiClient _c;
  final TokenStore _tokens;

  // ── auth ────────────────────────────────────────────────────────────────
  Future<AuthResult> login({required String email, required String password}) async {
    final data = await _c.post('/auth/login', body: {'email': email, 'password': password}, auth: false);
    final result = AuthResult.fromJson(data as Map<String, dynamic>);
    await _tokens.save(access: result.accessToken, refresh: result.refreshToken);
    return result;
  }

  Future<AuthResult> signup({required String email, required String password, String? name, String? refCode}) async {
    final data = await _c.post('/auth/signup', auth: false, body: {
      'email': email,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
      if (refCode != null && refCode.isNotEmpty) 'refCode': refCode,
    });
    final result = AuthResult.fromJson(data as Map<String, dynamic>);
    await _tokens.save(access: result.accessToken, refresh: result.refreshToken);
    return result;
  }

  Future<void> logout() async {
    // Best-effort server revoke; always clear locally.
    final refresh = await _tokens.refreshToken;
    if (refresh != null) {
      try {
        await _c.post('/auth/logout', body: {'refreshToken': refresh}, auth: false);
      } catch (_) {/* ignore — clearing locally is what matters */}
    }
    await _tokens.clear();
  }

  // ── reads ───────────────────────────────────────────────────────────────
  /// Public composite (webBff) — no auth required.
  Future<HomeComposite> home() async {
    final data = await _c.get('/home', auth: false);
    return HomeComposite.fromJson(data as Map<String, dynamic>);
  }

  /// Current user (dualAuth Bearer read).
  Future<AuthUser> me() async {
    final data = await _c.get('/me');
    return AuthUser.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Booking>> bookings() async {
    final data = await _c.get('/bookings');
    // data may be a bare list OR a paginated envelope { items: [...], meta }.
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['items'] is List ? data['items'] as List : const []);
    return list.whereType<Map<String, dynamic>>().map(Booking.fromJson).toList(growable: false);
  }
}
