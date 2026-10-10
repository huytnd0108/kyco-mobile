/// Auth identity + token models. Tolerant parsing throughout.
class AuthUser {
  const AuthUser({required this.id, required this.role, this.name, this.locale});
  final int id;

  /// The raw server role ('' when absent). Validate with [roleValidity].
  final String role;
  final String? name;
  final String? locale;

  /// Roles the app understands (post-rename; `provider` / `pending_provider`
  /// are stale pre-migration values). `staff` is a real server role that the
  /// app treats like a customer.
  static const knownRoles = {'customer', 'tasker', 'pending_tasker', 'admin', 'staff'};

  /// Whether this user may hold a session: a banned account, a stale or
  /// unknown role, a missing role or id are never silently mapped to customer.
  SessionValidity get roleValidity {
    if (role == 'banned') return SessionValidity.banned;
    if (id <= 0 || !knownRoles.contains(role)) return SessionValidity.stale;
    return SessionValidity.ok;
  }

  factory AuthUser.fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final role = j['role'];
    final name = j['name'];
    final locale = j['locale'];
    return AuthUser(
      id: id is num ? id.toInt() : (id is String ? int.tryParse(id) ?? 0 : 0),
      role: role is String ? role.trim() : '',
      name: name is String ? name : null,
      locale: locale is String ? locale : null,
    );
  }
}

enum SessionValidity { ok, stale, banned }

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
