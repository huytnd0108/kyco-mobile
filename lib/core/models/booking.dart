import '../format.dart';

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

/// The guest checkout draft — the app's mirror of the web's sessionStorage
/// form persistence. Persisted via Prefs under `draft:<serviceId>`, restored
/// after sign-in so a guest keeps every field. Never carries an amount.
class BookingDraft {
  BookingDraft({
    required this.serviceId,
    required this.serviceName,
    required this.basePriceVnd,
    this.scheduledDate,
    this.scheduledTime,
    this.wardCode,
    this.wardName,
    this.neighborhood,
    this.addressLine = '',
    this.notes = '',
    String? idempotencyKey,
  }) : idempotencyKey = idempotencyKey ?? uuidV4();

  final int serviceId;
  final String serviceName;
  final int basePriceVnd;
  String? scheduledDate; // 'YYYY-MM-DD'
  String? scheduledTime; // 'HH:mm'
  int? wardCode;
  String? wardName;
  String? neighborhood;
  String addressLine;
  String notes;
  final String idempotencyKey;

  BookingDraft copyWith({
    String? scheduledDate,
    String? scheduledTime,
    int? wardCode,
    String? wardName,
    String? neighborhood,
    String? addressLine,
    String? notes,
  }) =>
      BookingDraft(
        serviceId: serviceId,
        serviceName: serviceName,
        basePriceVnd: basePriceVnd,
        scheduledDate: scheduledDate ?? this.scheduledDate,
        scheduledTime: scheduledTime ?? this.scheduledTime,
        wardCode: wardCode ?? this.wardCode,
        wardName: wardName ?? this.wardName,
        neighborhood: neighborhood ?? this.neighborhood,
        addressLine: addressLine ?? this.addressLine,
        notes: notes ?? this.notes,
        idempotencyKey: idempotencyKey,
      );

  Map<String, dynamic> toJson() => {
        'serviceId': serviceId,
        'serviceName': serviceName,
        'basePriceVnd': basePriceVnd,
        'scheduledDate': scheduledDate,
        'scheduledTime': scheduledTime,
        'wardCode': wardCode,
        'wardName': wardName,
        'neighborhood': neighborhood,
        'addressLine': addressLine,
        'notes': notes,
        'idempotencyKey': idempotencyKey,
      };

  factory BookingDraft.fromJson(Map<String, dynamic> j) => BookingDraft(
        serviceId: (j['serviceId'] as num?)?.toInt() ?? 0,
        serviceName: (j['serviceName'] as String?) ?? '',
        basePriceVnd: (j['basePriceVnd'] as num?)?.toInt() ?? 0,
        scheduledDate: j['scheduledDate'] as String?,
        scheduledTime: j['scheduledTime'] as String?,
        wardCode: (j['wardCode'] as num?)?.toInt(),
        wardName: j['wardName'] as String?,
        neighborhood: j['neighborhood'] as String?,
        addressLine: (j['addressLine'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
        idempotencyKey: j['idempotencyKey'] as String?,
      );

  /// The POST /v1/bookings body — cash-only, NEVER any amount key. Maps the web
  /// column legacy: wardName → `district`, neighborhood → `ward`.
  Map<String, dynamic> toCreateBody() => {
        'serviceId': serviceId,
        'scheduledAt': '${scheduledDate ?? ''}T${scheduledTime ?? ''}:00',
        'district': wardName ?? '',
        'ward': neighborhood ?? '',
        'addressLine': addressLine,
        'notes': notes,
        'paymentMethod': 'cash',
        'idempotencyKey': idempotencyKey,
      };
}

/// The POST /v1/bookings 201 response.
class CreateBookingResult {
  const CreateBookingResult({
    required this.kind,
    required this.bookingId,
    this.paymentMethod,
    this.totalVnd,
    this.confirmationCode,
    this.payUrl,
    this.qrCodeUrl,
    this.deeplink,
  });
  final String kind; // 'created' | 'dedup'
  final int bookingId;
  final String? paymentMethod;
  final int? totalVnd;
  final String? confirmationCode;
  final String? payUrl;
  final String? qrCodeUrl;
  final String? deeplink;

  factory CreateBookingResult.fromJson(Map<String, dynamic> j) => CreateBookingResult(
        kind: (j['kind'] as String?) ?? 'created',
        bookingId: (j['bookingId'] as num?)?.toInt() ??
            (j['id'] as num?)?.toInt() ??
            0,
        paymentMethod: j['paymentMethod'] as String?,
        totalVnd: (j['totalVnd'] as num?)?.toInt(),
        confirmationCode: j['confirmationCode'] as String?,
        payUrl: j['payUrl'] as String?,
        qrCodeUrl: j['qrCodeUrl'] as String?,
        deeplink: j['deeplink'] as String?,
      );
}
