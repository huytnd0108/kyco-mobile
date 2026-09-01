/// Typed error from the kyco API envelope: `{ ok:false, code, message, fields? }`.
/// Also used for transport/HTTP failures (code = http_STATUS / network).
class ApiException implements Exception {
  ApiException(this.code, this.message, {this.status, this.fields});

  final String code;
  final String message;
  final int? status;
  final Map<String, String>? fields;

  bool get isMaintenance => code == 'MAINTENANCE' || status == 503;
  bool get isUnauthorized => code == 'AUTH_REQUIRED' || status == 401;

  /// Parse the error envelope a kyco route returns via apiError().
  factory ApiException.fromEnvelope(Map<String, dynamic>? body, int? status) {
    final code = (body?['code'] as String?) ?? 'http_${status ?? 0}';
    final message = (body?['message'] as String?) ??
        (status == 503 ? 'Service temporarily unavailable' : 'Request failed');
    final rawFields = body?['fields'];
    final fields = rawFields is Map
        ? rawFields.map((k, v) => MapEntry(k.toString(), v.toString()))
        : null;
    return ApiException(code, message, status: status, fields: fields);
  }

  @override
  String toString() => 'ApiException($code${status != null ? ' $status' : ''}): $message';
}
