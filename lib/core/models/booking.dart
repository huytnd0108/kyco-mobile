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

/// Every booking status the backend FSM knows (`lib/orders/status-machine.ts`),
/// in rank order. The app LABELS these; it never decides transitions.
const kBookingStatuses = <String>[
  'PENDING', 'CONFIRMED', 'EN_ROUTE', 'ARRIVED', 'CHECKED_IN', 'ACTIVE',
  'AWAITING_CUSTOMER_CONFIRMATION', 'AWAITING_PAYMENT', 'AWAITING_CASH_CONFIRM',
  'COMPLETED', 'CLOSED', 'SETTLED', 'IN_DISPUTE', 'BAD_DEBT', 'CANCELLED',
];

/// Statuses the review core accepts (`lib/reviews/write.ts` TERMINAL_SETTLED).
const kReviewableStatuses = {'COMPLETED', 'CLOSED', 'SETTLED'};

/// One timestamped step of the booking timeline (label resolved by the UI).
class BookingTimelineEvent {
  const BookingTimelineEvent(this.kind, this.at);

  /// created | scheduled | claimed | started | finished | completed |
  /// customerConfirmed | cashReceived | settled
  final String kind;
  final String at;
}

/// Booking detail — parsed from the `GET /v1/bookings/{id}/page` composite
/// (`{booking, service, job, tasker, payments, hasReview, ...}`), the richest
/// owner-scoped read. Only display-safe fields are read; amounts are shown
/// verbatim from the server (`totalVnd`) and NEVER recomputed client-side.
class BookingDetail {
  const BookingDetail({
    required this.id,
    required this.status,
    this.serviceName,
    this.serviceId,
    this.scheduledAt,
    this.createdAt,
    this.totalVnd,
    this.paymentMethod,
    this.addressLine,
    this.district,
    this.ward,
    this.notes,
    this.confirmationCode,
    this.taskerId,
    this.taskerName,
    this.hasReview = false,
    this.timeline = const [],
  });

  final int id;
  final String status;
  final String? serviceName;
  final int? serviceId;
  final String? scheduledAt;
  final String? createdAt;
  final int? totalVnd;
  final String? paymentMethod;
  final String? addressLine;
  final String? district;
  final String? ward;
  final String? notes;
  final String? confirmationCode;
  final int? taskerId;
  final String? taskerName;
  final bool hasReview;
  final List<BookingTimelineEvent> timeline;

  /// Customer review is allowed once the booking is settled-ish, has an
  /// assigned tasker, and has no review yet (mirrors the review core).
  bool get canReview =>
      kReviewableStatuses.contains(status.toUpperCase()) && taskerId != null && !hasReview;

  static String? _s(Object? v) => v is String && v.isNotEmpty ? v : null;

  /// Parse the /page composite. Also accepts the flat `GET /bookings/{id}` DTO
  /// (no `booking` key) so either read can back the screen.
  factory BookingDetail.fromPage(Map<String, dynamic> j) {
    final b = j['booking'] is Map<String, dynamic> ? j['booking'] as Map<String, dynamic> : j;
    final svc = j['service'] is Map<String, dynamic> ? j['service'] as Map<String, dynamic> : null;
    final job = j['job'] is Map<String, dynamic> ? j['job'] as Map<String, dynamic> : null;
    final prov = j['tasker'] is Map<String, dynamic> ? j['tasker'] as Map<String, dynamic> : null;

    final events = <BookingTimelineEvent>[];
    void add(String kind, Object? at) {
      final s = _s(at);
      if (s != null) events.add(BookingTimelineEvent(kind, s));
    }

    add('created', b['createdAt']);
    add('scheduled', b['scheduledAt']);
    add('claimed', job?['claimedAt']);
    add('started', job?['startedAt']);
    add('finished', job?['finishedAt']);
    add('completed', b['completedAt']);
    add('customerConfirmed', b['customerConfirmedAt']);
    add('cashReceived', b['cashReceivedAt']);
    add('settled', b['settledAt']);

    return BookingDetail(
      id: (b['id'] as num).toInt(),
      status: _s(b['status']) ?? 'PENDING',
      serviceName: _s(svc?['name']) ?? _s(b['serviceName']),
      serviceId: (b['serviceId'] as num?)?.toInt() ?? (svc?['id'] as num?)?.toInt(),
      scheduledAt: _s(b['scheduledAt']),
      createdAt: _s(b['createdAt']),
      totalVnd: (b['totalVnd'] as num?)?.toInt(),
      paymentMethod: _s(b['paymentMethod']),
      addressLine: _s(b['addressLine']),
      district: _s(b['district']),
      ward: _s(b['ward']),
      notes: _s(b['notes']),
      confirmationCode: _s(b['confirmationCode']),
      taskerId: (prov?['id'] as num?)?.toInt() ?? (job?['taskerId'] as num?)?.toInt(),
      taskerName: _s(prov?['name']),
      hasReview: j['hasReview'] == true,
      timeline: events,
    );
  }
}
