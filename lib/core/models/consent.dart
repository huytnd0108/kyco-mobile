// Release-i: Terms / Privacy consent contract (PDPD Decree 13/2023).
// Server: GET /v1/legal, GET /v1/me `consents`, POST /v1/me/consents.

/// `GET /v1/legal` (public). Its PRESENCE (HTTP 200) is the signal that the
/// server records signup consent; a 404 means an older backend that rejects
/// the unknown `consent` key.
class LegalInfo {
  const LegalInfo({
    required this.termsVersion,
    required this.privacyVersion,
    this.consentRequired = true,
    this.consentSchema = 1,
    this.termsUrl,
    this.privacyUrl,
  });
  final String termsVersion;
  final String privacyVersion;
  final bool consentRequired;

  /// `consentSchema` of `/v1/legal`: 2 = the server takes per-document
  /// `termsVersion` / `privacyVersion`; absent (or 1) = a single `version`.
  final int consentSchema;
  bool get perDocumentConsent => consentSchema >= 2;

  /// Locale-specific absolute web URLs; null when absent (use the web paths).
  final Uri? termsUrl;
  final Uri? privacyUrl;

  static final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  /// The signup / quick-signup / become-tasker `consent.version`: the server
  /// (consent.ts:89) rejects a version GREATER than either document's, so send
  /// `min(terms, privacy)`. ISO dates compare lexicographically, but only after
  /// the format check; null when either is not `YYYY-MM-DD` (nothing safe to send).
  String? get signupConsentVersion {
    if (!_isoDate.hasMatch(termsVersion) || !_isoDate.hasMatch(privacyVersion)) return null;
    return termsVersion.compareTo(privacyVersion) <= 0 ? termsVersion : privacyVersion;
  }

  /// Null when the body has no usable version (treated like "not supported").
  static LegalInfo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final t = raw['termsVersion'], p = raw['privacyVersion'];
    if (t is! String || t.trim().isEmpty || p is! String || p.trim().isEmpty) return null;
    return LegalInfo(
      termsVersion: t.trim(),
      privacyVersion: p.trim(),
      consentRequired: raw['consentRequired'] != false,
      consentSchema: raw['consentSchema'] is num ? (raw['consentSchema'] as num).toInt() : 1,
      termsUrl: _https(raw['termsUrl']),
      privacyUrl: _https(raw['privacyUrl']),
    );
  }

  /// Only absolute https links are ever opened from a server value.
  static Uri? _https(Object? v) {
    if (v is! String) return null;
    final u = Uri.tryParse(v.trim());
    return u != null && u.scheme == 'https' && u.host.isNotEmpty ? u : null;
  }
}

/// The signup `consent` object. Schema 1 (release-i):
/// `{"terms":true,"privacy":true,"version":"min(termsVersion, privacyVersion)"}`.
/// Schema 2 (release-j): `{"terms":true,"privacy":true,"termsVersion":T,"privacyVersion":P}`
/// (no `version`).
class ConsentPayload {
  const ConsentPayload({this.version, this.termsVersion, this.privacyVersion});
  final String? version;
  final String? termsVersion;
  final String? privacyVersion;

  bool get perDocument => termsVersion != null && privacyVersion != null;

  Map<String, Object> toJson() => perDocument
      ? {'terms': true, 'privacy': true, 'termsVersion': termsVersion!, 'privacyVersion': privacyVersion!}
      : {'terms': true, 'privacy': true, 'version': version!};

  /// Multipart fields for the become-tasker form (`consent_terms`,
  /// `consent_privacy` + `consent_version` | `consent_terms_version` /
  /// `consent_privacy_version`, as lib/legal/consent.ts consentFromForm reads).
  Map<String, String> toFormFields() => perDocument
      ? {
          'consent_terms': '1',
          'consent_privacy': '1',
          'consent_terms_version': termsVersion!,
          'consent_privacy_version': privacyVersion!,
        }
      : {'consent_terms': '1', 'consent_privacy': '1', 'consent_version': version!};

  /// The payload for a server that advertised [legal]; null = send nothing.
  static ConsentPayload? forLegal(LegalInfo? legal) {
    if (legal == null) return null;
    if (legal.perDocumentConsent) {
      if (!LegalInfo._isoDate.hasMatch(legal.termsVersion) || !LegalInfo._isoDate.hasMatch(legal.privacyVersion)) {
        return null;
      }
      return ConsentPayload(termsVersion: legal.termsVersion, privacyVersion: legal.privacyVersion);
    }
    final v = legal.signupConsentVersion;
    return v == null ? null : ConsentPayload(version: v);
  }
}

/// `/v1/me` `consents` (also the 201 body of `POST /v1/me/consents`).
class ConsentStatus {
  const ConsentStatus({
    this.termsVersion,
    this.termsAcceptedAt,
    this.privacyVersion,
    this.privacyAcceptedAt,
    this.currentTermsVersion,
    this.currentPrivacyVersion,
    this.needsReconsent = false,
  });
  final String? termsVersion;
  final String? termsAcceptedAt;
  final String? privacyVersion;
  final String? privacyAcceptedAt;
  final String? currentTermsVersion;
  final String? currentPrivacyVersion;
  final bool needsReconsent;

  /// The version `POST /v1/me/consents` accepts: the server requires the
  /// highest current version (`max(terms, privacy)`; versions are ISO dates).
  /// Null when the server sent none (then the field is omitted: optional).
  String? get acceptVersion {
    final t = currentTermsVersion, p = currentPrivacyVersion;
    if (t == null) return p;
    if (p == null) return t;
    return t.compareTo(p) >= 0 ? t : p;
  }

  /// Per-document re-consent versions (schema 2): the current ones from /me,
  /// falling back to [legal]. Null when either is unknown (then fall back to [acceptVersion]).
  (String, String)? perDocumentVersions(LegalInfo? legal) {
    final t = currentTermsVersion ?? legal?.termsVersion;
    final p = currentPrivacyVersion ?? legal?.privacyVersion;
    return t == null || p == null ? null : (t, p);
  }

  static ConsentStatus? tryParse(Object? raw) {
    if (raw is! Map) return null;
    String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    return ConsentStatus(
      termsVersion: s(raw['termsVersion']),
      termsAcceptedAt: s(raw['termsAcceptedAt']),
      privacyVersion: s(raw['privacyVersion']),
      privacyAcceptedAt: s(raw['privacyAcceptedAt']),
      currentTermsVersion: s(raw['currentTermsVersion']),
      currentPrivacyVersion: s(raw['currentPrivacyVersion']),
      needsReconsent: raw['needsReconsent'] == true,
    );
  }
}
