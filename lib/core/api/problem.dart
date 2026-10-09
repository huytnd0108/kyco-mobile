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
  bool get isRateLimited => code == 'RATE_LIMIT' || status == 429;
  bool get isNetwork => code == 'network';

  /// Parse the error envelope a kyco route returns via apiError().
  ///
  /// Also tolerates the NON-envelope bodies some edge layers still emit (backend
  /// bug MQA-1: the middleware limiter answers 429 `{"error":"Too many requests"}`
  /// with no `code`): any 429 without an envelope code is typed `RATE_LIMIT`, and
  /// a bare `{"error": "..."}` string is kept as the (non-UI) message.
  factory ApiException.fromEnvelope(Map<String, dynamic>? body, int? status) {
    final envCode = body?['code'];
    final bareError = body?['error'];
    final code = envCode is String && envCode.isNotEmpty
        ? envCode
        : (status == 429 ? 'RATE_LIMIT' : 'http_${status ?? 0}');
    final envMessage = body?['message'];
    final message = envMessage is String
        ? envMessage
        : (bareError is String
            ? bareError
            : (status == 503 ? 'Service temporarily unavailable' : 'Request failed'));
    final rawFields = body?['fields'];
    final fields = rawFields is Map
        ? rawFields.map((k, v) => MapEntry(k.toString(), v.toString()))
        : null;
    return ApiException(code, message, status: status, fields: fields);
  }

  @override
  String toString() => 'ApiException($code${status != null ? ' $status' : ''}): $message';
}
