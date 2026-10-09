import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../api/problem.dart';

/// Localized, user-facing copy for any failure. NEVER interpolates
/// `toString()` / transport text (Dio messages, stack traces) into the UI.
///
/// Mapping:
///  - transport: `network` → offline copy; `RATE_LIMIT`/429 (incl. the
///    non-envelope MQA-1 body) → slow-down copy; `MAINTENANCE`/503 → maintenance;
///    any other `http_*` / 5xx / INTERNAL / UPSTREAM → server copy.
///  - envelope codes: AUTH_REQUIRED/401 → [authText] (defaults to
///    "session expired"; the login screen passes "wrong credentials"),
///    FORBIDDEN, NOT_FOUND, VALIDATION, TOTP_*.
///  - other DOMAIN codes (CONFLICT, CUSTOMER_*, …): the server envelope message
///    — already negotiated into the app language via Accept-Language — else a
///    localized fallback.
///  - non-API errors → [AppLocalizations.genericError].
String apiErrorText(AppLocalizations l, Object? error, {String? authText}) {
  if (error is! ApiException) return l.genericError;
  final e = error;
  final status = e.status ?? 0;
  if (e.isNetwork) return l.cust2ErrNetwork;
  if (e.isRateLimited) return l.cust2ErrRateLimit;
  if (e.isMaintenance) return l.cust2ErrMaintenance;
  switch (e.code) {
    case 'AUTH_REQUIRED':
      return authText ?? l.cust2ErrSessionExpired;
    case 'TOTP_REQUIRED':
      return l.cust2ErrTotpRequired;
    case 'TOTP_INVALID':
      return l.cust2ErrTotpInvalid;
    case 'FORBIDDEN':
    case 'CSRF_FAILED':
      return l.cust2ErrForbidden;
    case 'NOT_FOUND':
      return l.cust2ErrNotFound;
    case 'VALIDATION':
      return l.cust2ErrValidation;
    case 'INTERNAL':
    case 'UPSTREAM':
      return l.cust2ErrServer;
  }
  if (e.code.startsWith('http_')) {
    if (status == 401) return authText ?? l.cust2ErrSessionExpired;
    if (status == 403) return l.cust2ErrForbidden;
    if (status == 404) return l.cust2ErrNotFound;
    if (status == 422 || status == 400) return l.cust2ErrValidation;
    if (status >= 500) return l.cust2ErrServer;
    return l.genericError;
  }
  // A domain code from a real envelope: the server message is localized copy.
  final msg = e.message.trim();
  if (msg.isNotEmpty && msg != 'Request failed') return msg;
  return e.code == 'CONFLICT' ? l.cust2ErrConflict : l.genericError;
}
