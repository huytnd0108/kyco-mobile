/// Auth identity + token models. Tolerant parsing throughout.
class AuthUser {
  const AuthUser({required this.id, required this.role, this.name, this.locale});
  final int id;
  final String role;
  final String? name;
  final String? locale;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] as num).toInt(),
        role: (j['role'] as String?) ?? 'customer',
        name: j['name'] as String?,
        locale: j['locale'] as String?,
      );
}

class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    this.user,
  });
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AuthUser? user;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        expiresIn: (j['expiresIn'] as num?)?.toInt() ?? 0,
        user: j['user'] is Map<String, dynamic>
            ? AuthUser.fromJson(j['user'] as Map<String, dynamic>)
            : null,
      );
}
