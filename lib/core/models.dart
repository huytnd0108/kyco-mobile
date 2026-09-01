// Typed models for the kyco /api/v1 responses this app consumes. Kept small
// and defensive (tolerant parsing) — the backend envelope wraps these as
// `{ ok:true, data:<T>, meta? }`.

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

/// A service category from the /v1/home composite (image already resolved server-side).
class ServiceCategory {
  const ServiceCategory({required this.id, required this.name, this.imageUrl, this.slug});
  final int id;
  final String name;
  final String? imageUrl;
  final String? slug;

  factory ServiceCategory.fromJson(Map<String, dynamic> j) => ServiceCategory(
        id: (j['id'] as num).toInt(),
        name: (j['name'] as String?) ?? '',
        imageUrl: j['imageUrl'] as String? ?? j['image_url'] as String?,
        slug: j['slug'] as String?,
      );
}

/// The home landing composite. Parsed leniently — only the fields the UI shows.
class HomeComposite {
  const HomeComposite({required this.categories, this.greetingName});
  final List<ServiceCategory> categories;
  final String? greetingName;

  factory HomeComposite.fromJson(Map<String, dynamic> j) {
    final rawCats = (j['categories'] as List?) ?? const [];
    return HomeComposite(
      categories: rawCats
          .whereType<Map<String, dynamic>>()
          .map(ServiceCategory.fromJson)
          .toList(growable: false),
      greetingName: j['greetingName'] as String? ?? j['greeting'] as String?,
    );
  }
}

class Booking {
  const Booking({required this.id, required this.status, this.serviceName, this.totalVnd, this.createdAt});
  final int id;
  final String status;
  final String? serviceName;
  final int? totalVnd;
  final String? createdAt;

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: (j['id'] as num).toInt(),
        status: (j['status'] as String?) ?? 'PENDING',
        serviceName: j['serviceName'] as String? ?? j['service']?['name'] as String?,
        totalVnd: (j['totalVnd'] as num?)?.toInt(),
        createdAt: j['createdAt'] as String?,
      );
}
