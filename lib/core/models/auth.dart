// Auth identity + token models. Tolerant parsing throughout.

/// One KYC document of a pending tasker's application (release-h
/// `application.documents[]`). [status] is `pending | approved | rejected`.
class ApplicationDocument {
  const ApplicationDocument({
    required this.docKind,
    this.docLabel,
    required this.status,
    this.reason,
  });
  final String docKind;

  /// Server-localized label ("CCCD mặt trước"); null on an older payload.
  final String? docLabel;
  final String status;

  /// Admin's free-text reason, present only when rejected.
  final String? reason;

  bool get rejected => status == 'rejected';

  static ApplicationDocument? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final kind = raw['docKind'];
    if (kind is! String || kind.isEmpty) return null;
    String? str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final st = raw['status'];
    return ApplicationDocument(
      docKind: kind,
      docLabel: str(raw['docLabel']),
      status: st is String && st.isNotEmpty ? st : 'pending',
      reason: str(raw['reason']),
    );
  }
}

/// The pending tasker's application (`/v1/me` `application` and
/// `GET /v1/kyc` `{application}`). Every field except [status] is optional.
class TaskerApplication {
  const TaskerApplication({
    required this.status,
    this.statusLabel,
    this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.documents = const [],
  });

  /// `not_submitted | pending | approved | rejected`.
  final String status;

  /// Server-localized sentence for [status].
  final String? statusLabel;
  final String? submittedAt;
  final String? reviewedAt;
  final String? rejectionReason;
  final List<ApplicationDocument> documents;

  bool get isRejected => status == 'rejected';

  static TaskerApplication? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final st = raw['status'];
    if (st is! String || st.isEmpty) return null;
    String? str(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final docs = raw['documents'];
    return TaskerApplication(
      status: st,
      statusLabel: str(raw['statusLabel']),
      submittedAt: str(raw['submittedAt']),
      reviewedAt: str(raw['reviewedAt']),
      rejectionReason: str(raw['rejectionReason']),
      documents: [
        if (docs is List)
          for (final d in docs) ?ApplicationDocument.tryParse(d),
      ],
    );
  }

  /// Accepts the `GET /kyc` body (`{application}`) or the bare object.
  static TaskerApplication? fromKycBody(Object? body) =>
      tryParse(body is Map && body['application'] != null ? body['application'] : body);
}

class AuthUser {
  const AuthUser(
      {required this.id, required this.role, this.name, this.locale, this.application});
  final int id;

  /// The raw server role ('' when absent). Validate with [roleValidity].
  final String role;
  final String? name;
  final String? locale;

  /// Release-h: the pending tasker's KYC application (`/me` `application`);
  /// null for every other role and on an older backend.
  final TaskerApplication? application;

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
      application: TaskerApplication.tryParse(j['application']),
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
