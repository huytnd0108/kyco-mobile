import 'dart:convert';

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
    this.jobId,
    this.messages = const [],
    this.hasReview = false,
    this.timeline = const [],
    this.ctvHasCheckedIn = false,
    this.customerDisputedAt,
    this.taskerResubmittedAt,
    this.manualSettlementRequired = false,
    this.breakdown,
    this.latestPaymentStatus,
    this.serverActions,
    this.cancelPreview,
    this.cancelReasons = const [],
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

  /// The job row behind this booking (`/page` `job.id`) - the live-tracking key.
  final int? jobId;

  /// The booking thread (`/page` `messages`, oldest first).
  final List<BookingMessage> messages;
  final bool hasReview;
  final List<BookingTimelineEvent> timeline;

  /// An 'arrival' check-in exists (`/page` `ctvHasCheckedIn`): cancel is refused.
  final bool ctvHasCheckedIn;

  /// Soft dispute timestamps (`confirm-completion` action=dispute).
  final String? customerDisputedAt;
  final String? taskerResubmittedAt;

  /// Server flag: payment captured but settlement needs ops (shown as a note).
  final bool manualSettlementRequired;

  /// The server's itemisation (`booking.surchargeBreakdownJson`), display only.
  final PriceBreakdownView? breakdown;

  /// Status of the newest payment row (`latestPayment.status`), if any.
  final String? latestPaymentStatus;

  /// Server-decided button flags (`/page` `actions`), null on a backend that
  /// does not send them yet (the status table in [BookingActions] applies).
  final ServerActions? serverActions;

  /// Server-computed cancel outcome preview (`/page` `cancelPreview`), or null.
  final CancelPreview? cancelPreview;

  /// Server cancel reasons (`/page` `cancelReasons: [{code, label}]`, labels
  /// localized server-side); empty on a backend that does not send them.
  final List<CancelReasonOption> cancelReasons;

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
      jobId: (job?['id'] as num?)?.toInt(),
      messages: [
        for (final m in (j['messages'] is List ? j['messages'] as List : const []))
          ?BookingMessage.tryParse(m),
      ],
      hasReview: j['hasReview'] == true,
      timeline: events,
      ctvHasCheckedIn: j['ctvHasCheckedIn'] == true,
      customerDisputedAt: _s(b['customerDisputedAt']),
      taskerResubmittedAt: _s(b['taskerResubmittedAt']),
      manualSettlementRequired: b['manualSettlementRequired'] == true,
      breakdown: PriceBreakdownView.tryParse(b['surchargeBreakdownJson']),
      latestPaymentStatus: _latestPaymentStatus(j),
      serverActions: ServerActions.tryParse(j['actions']),
      cancelPreview: CancelPreview.tryParse(j['cancelPreview']),
      cancelReasons: CancelReasonOption.parseList(j['cancelReasons']),
    );
  }

  static String? _latestPaymentStatus(Map<String, dynamic> j) {
    final latest = j['latestPayment'];
    if (latest is Map) return _s(latest['status']);
    final list = j['payments'];
    if (list is List && list.isNotEmpty && list.last is Map) return _s((list.last as Map)['status']);
    return null;
  }
}

/// `actions: {canCancel, canConfirm, canPay, canDispute}` — each flag optional.
class ServerActions {
  const ServerActions({this.canCancel, this.canConfirm, this.canPay, this.canDispute});
  final bool? canCancel;
  final bool? canConfirm;
  final bool? canPay;
  final bool? canDispute;

  static ServerActions? tryParse(Object? raw) {
    if (raw is! Map) return null;
    bool? f(String k) => raw[k] is bool ? raw[k] as bool : null;
    final a = ServerActions(
        canCancel: f('canCancel'), canConfirm: f('canConfirm'), canPay: f('canPay'), canDispute: f('canDispute'));
    return (a.canCancel ?? a.canConfirm ?? a.canPay ?? a.canDispute) == null ? null : a;
  }
}

/// One server cancel reason `{code, label}`.
class CancelReasonOption {
  const CancelReasonOption(this.code, this.label);
  final String code;
  final String label;

  /// Tolerant: skips malformed entries and duplicate codes; a missing label drops the entry.
  static List<CancelReasonOption> parseList(Object? raw) {
    if (raw is! List) return const [];
    final seen = <String>{};
    final out = <CancelReasonOption>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final code = e['code'], label = e['label'];
      if (code is! String || code.trim().isEmpty || label is! String || label.trim().isEmpty) continue;
      if (seen.add(code.trim())) out.add(CancelReasonOption(code.trim(), label.trim()));
    }
    return out;
  }
}

/// `cancelPreview: {feeVnd, refundVnd, reason}` - server numbers/text, shown
/// verbatim in the cancel dialog; the app never derives a fee. `reason` is
/// `{code:'FREE_WINDOW'|'AFTER_START_NO_REFUND', label}` (final contract) or a
/// plain string (earlier backend); [reason] holds the text to show.
class CancelPreview {
  const CancelPreview({this.feeVnd, this.refundVnd, this.reason, this.reasonCode});
  final int? feeVnd;
  final int? refundVnd;
  final String? reason;
  final String? reasonCode;

  static CancelPreview? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final r = raw['reason'];
    String? text, code;
    if (r is Map) {
      final label = r['label'], c = r['code'];
      text = label is String && label.trim().isNotEmpty ? label.trim() : null;
      code = c is String && c.trim().isNotEmpty ? c.trim() : null;
    } else if (r is String && r.trim().isNotEmpty) {
      text = r.trim();
    }
    final p = CancelPreview(
      feeVnd: (raw['feeVnd'] as num?)?.toInt(),
      refundVnd: (raw['refundVnd'] as num?)?.toInt(),
      reason: text,
      reasonCode: code,
    );
    return (p.feeVnd ?? p.refundVnd ?? p.reason) == null ? null : p;
  }
}

/// Cancel response `{feeVnd, refundVnd, refundStatus}` (all optional: the
/// current backend answers only `{intent, bookingId}`).
class CancelResult {
  const CancelResult({this.feeVnd, this.refundVnd, this.refundStatus});
  final int? feeVnd;
  final int? refundVnd;
  final String? refundStatus;

  factory CancelResult.fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    return CancelResult(
      feeVnd: (j['feeVnd'] as num?)?.toInt(),
      refundVnd: (j['refundVnd'] as num?)?.toInt(),
      refundStatus: j['refundStatus'] as String?,
    );
  }
}

/// `POST /bookings/quote` answer: the server total (= what create charges)
/// and its itemisation.
class BookingQuote {
  const BookingQuote({required this.totalVnd, this.breakdown});
  final int totalVnd;
  final PriceBreakdownView? breakdown;

  static BookingQuote? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final t = raw['totalVnd'];
    if (t is! num) return null;
    return BookingQuote(
        totalVnd: t.toInt(),
        breakdown: PriceBreakdownView.tryParse(raw['breakdown'] ?? raw['surchargeBreakdownJson'] ?? raw));
  }
}

/// One server-itemised line (label + amount exactly as received).
class BreakdownLine {
  const BreakdownLine(this.label, this.amountVnd);
  final String label;
  final int amountVnd;
}

/// The server's price itemisation (`PriceBreakdown` + `cancelCompensations`),
/// parsed for DISPLAY only. Every number is copied from the payload; nothing is
/// derived, summed or recomputed here.
class PriceBreakdownView {
  const PriceBreakdownView({
    this.compensations = const [],
    this.surchargesVnd,
    this.surchargeReasons = const [],
    this.compensationVnd,
  });

  /// `cancelCompensations[]` — label and amount as sent.
  final List<BreakdownLine> compensations;

  /// `surchargesVnd` (shown only when the server sent a positive value).
  final int? surchargesVnd;
  final List<String> surchargeReasons;

  /// `compensationVnd` — the server's own compensation sum (used only when no
  /// per-line `cancelCompensations` came with it).
  final int? compensationVnd;

  bool get hasSurcharge => (surchargesVnd ?? 0) > 0;
  bool get isEmpty =>
      compensations.isEmpty && !hasSurcharge && (compensationVnd ?? 0) <= 0;

  /// Accepts the decoded map or its JSON string; null/garbage -> null.
  static PriceBreakdownView? tryParse(Object? raw) {
    Object? v = raw;
    if (v is String && v.isNotEmpty) {
      try {
        v = jsonDecode(v);
      } catch (_) {
        return null;
      }
    }
    if (v is! Map) return null;
    final lines = <BreakdownLine>[];
    final comps = v['cancelCompensations'];
    if (comps is List) {
      for (final c in comps) {
        if (c is! Map) continue;
        final amount = c['amountVnd'];
        final label = c['label'];
        if (amount is num && label is String && label.trim().isNotEmpty) {
          lines.add(BreakdownLine(label.trim(), amount.toInt()));
        }
      }
    }
    final reasons = <String>[];
    final rr = v['surchargeReasons'];
    if (rr is List) {
      for (final r in rr) {
        if (r is String && r.trim().isNotEmpty) reasons.add(r.trim());
        if (r is Map && r['label'] is String && (r['label'] as String).trim().isNotEmpty) {
          reasons.add((r['label'] as String).trim());
        }
      }
    }
    final out = PriceBreakdownView(
      compensations: lines,
      surchargesVnd: (v['surchargesVnd'] as num?)?.toInt(),
      surchargeReasons: reasons,
      compensationVnd: (v['compensationVnd'] as num?)?.toInt(),
    );
    return out.isEmpty ? null : out;
  }
}

/// Which money actions the booking detail may offer. Derived ONLY from the
/// server status and flags (MONEY-CONTRACT section 5.3) — never from amounts.
class BookingActions {
  const BookingActions({
    this.canCancel = false,
    this.canConfirm = false,
    this.canDispute = false,
    this.disputeWaiting = false,
    this.canPay = false,
    this.awaitingCashConfirm = false,
  });

  final bool canCancel;
  final bool canConfirm;
  final bool canDispute;

  /// Confirm-completion was disputed and the tasker has not resubmitted yet.
  final bool disputeWaiting;
  final bool canPay;
  final bool awaitingCashConfirm;

  static const gatewayMethods = {'vnpay', 'momo'};
  static const _cancellable = {'PENDING', 'CONFIRMED', 'EN_ROUTE'};
  static const _paidStates = {'paid', 'held', 'released'};

  factory BookingActions.of(BookingDetail b) {
    final status = b.status.toUpperCase();
    final method = (b.paymentMethod ?? '').toLowerCase();
    final confirming = status == 'AWAITING_CUSTOMER_CONFIRMATION';
    final disputedAt = DateTime.tryParse(b.customerDisputedAt ?? '');
    final resubmittedAt = DateTime.tryParse(b.taskerResubmittedAt ?? '');
    final waiting = confirming &&
        b.customerDisputedAt != null &&
        !(disputedAt != null && resubmittedAt != null && resubmittedAt.isAfter(disputedAt));
    final sa = b.serverActions;
    return BookingActions(
      // Server flags win when present; else the status table (MONEY-CONTRACT 5.3).
      canCancel: sa?.canCancel ?? (_cancellable.contains(status) && !b.ctvHasCheckedIn),
      canConfirm: sa?.canConfirm ?? confirming,
      canDispute: sa?.canDispute ?? (confirming && !waiting),
      disputeWaiting: waiting,
      canPay: sa?.canPay ??
          (status == 'AWAITING_PAYMENT' &&
              gatewayMethods.contains(method) &&
              !_paidStates.contains((b.latestPaymentStatus ?? '').toLowerCase())),
      awaitingCashConfirm: status == 'AWAITING_CASH_CONFIRM',
    );
  }
}

/// `POST /v1/payment/initiate` answer, discriminated by [kind]
/// (`ok` | `cash` | `already_paid` | `no_rail`). No amount is ever read.
class PaymentInitiateResult {
  const PaymentInitiateResult({
    required this.kind,
    required this.bookingId,
    this.method,
    this.payUrl,
    this.deeplink,
    this.providerTxId,
  });
  final String kind;
  final int bookingId;
  final String? method;
  final String? payUrl;
  final String? deeplink;
  final String? providerTxId;

  factory PaymentInitiateResult.fromJson(Map<String, dynamic> j) => PaymentInitiateResult(
        kind: (j['kind'] as String?) ?? '',
        bookingId: (j['bookingId'] as num?)?.toInt() ?? 0,
        method: j['method'] as String?,
        payUrl: j['payUrl'] as String?,
        deeplink: j['deeplink'] as String?,
        providerTxId: j['providerTxId'] as String?,
      );
}

/// `GET /v1/bookings/{id}/payment-status`: the latest payment row's status.
/// Paid/failed are ONLY what the server reports.
class PaymentStatusResult {
  const PaymentStatusResult({required this.status, required this.paid, required this.failed});
  final String status;
  final bool paid;
  final bool failed;

  /// `held`/`released` are legacy escrow states the server treats as paid-ish.
  bool get serverSaysPaid => paid || status == 'held' || status == 'released';
  bool get serverSaysFailed => !serverSaysPaid && (failed || status == 'refunded');

  factory PaymentStatusResult.fromJson(Map<String, dynamic> j) => PaymentStatusResult(
        status: (j['status'] as String?) ?? 'unknown',
        paid: j['paid'] == true,
        failed: j['failed'] == true,
      );
}

/// One booking-thread message from the `/bookings/{id}/page` composite
/// (`messages: [{id, fromRole, body, createdAt}]`, id ASC).
class BookingMessage {
  const BookingMessage({required this.id, required this.fromRole, required this.body, this.createdAt});
  final int id;
  final String fromRole;
  final String body;
  final String? createdAt;

  bool get fromCustomer => fromRole == 'customer';

  static BookingMessage? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final body = raw['body'];
    if (id is! num || body is! String) return null;
    final from = raw['fromRole'];
    final at = raw['createdAt'];
    return BookingMessage(
      id: id.toInt(),
      fromRole: from is String ? from : '',
      body: body,
      createdAt: at is String ? at : null,
    );
  }
}
