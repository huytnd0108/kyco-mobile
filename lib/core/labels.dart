import 'package:kyco_mobile/core/datetime.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Localized labels for every backend enum the UI shows (UX-M54/M55/M56).
///
/// Rule: a known value maps to its ARB label; an UNKNOWN value never prints the
/// raw server string — it falls back to the neutral [AppLocalizations.labelOther]
/// ("Khác" / "Other"). A missing value (null / empty) renders an em dash.
/// Matching is case-insensitive so a backend casing change does not leak.
const String _dash = '—';

String _norm(String? v) => (v ?? '').trim().toLowerCase();

/// Booking FSM status (`lib/orders/status-machine.ts`, 15 states).
String bookingStatusLabel(AppLocalizations l, String? status) {
  final s = (status ?? '').trim().toUpperCase();
  if (s.isEmpty) return _dash;
  return switch (s) {
    'PENDING' => l.statusPending,
    'CONFIRMED' => l.statusConfirmed,
    'EN_ROUTE' => l.cust2StatusEnRoute,
    'ARRIVED' => l.cust2StatusArrived,
    'CHECKED_IN' => l.cust2StatusCheckedIn,
    'ACTIVE' => l.cust2StatusActive,
    'AWAITING_CUSTOMER_CONFIRMATION' => l.cust2StatusAwaitingConfirmation,
    'AWAITING_PAYMENT' => l.cust2StatusAwaitingPayment,
    'AWAITING_CASH_CONFIRM' => l.cust2StatusAwaitingCashConfirm,
    'COMPLETED' => l.statusCompleted,
    'CLOSED' => l.cust2StatusClosed,
    'SETTLED' => l.statusSettled,
    'IN_DISPUTE' => l.cust2StatusInDispute,
    'CANCELLED' => l.statusCancelled,
    'BAD_DEBT' => l.statusBadDebt,
    _ => l.labelOther,
  };
}

/// Payment method (display only).
String paymentMethodLabel(AppLocalizations l, String? m) {
  final k = _norm(m);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'cash' => l.cust2PayCash,
    'vnpay' => 'VNPay',
    'momo' => 'MoMo',
    'zalopay' => 'ZaloPay',
    'bank_transfer' => l.provJdPayBankTransfer,
    _ => l.labelOther,
  };
}

/// Booking timeline event kind.
String timelineLabel(AppLocalizations l, String? kind) => switch (kind) {
      null || '' => _dash,
      'created' => l.cust2TlCreated,
      'scheduled' => l.cust2TlScheduled,
      'claimed' => l.cust2TlClaimed,
      'started' => l.cust2TlStarted,
      'finished' => l.cust2TlFinished,
      'completed' => l.cust2TlCompleted,
      'customerConfirmed' => l.cust2TlCustomerConfirmed,
      'cashReceived' => l.cust2TlCashReceived,
      'settled' => l.cust2TlSettled,
      _ => l.labelOther,
    };

/// Cancellation reason code - server enums: customer (plan_changed, wrong_time,
/// price, found_other, other) and tasker (sick, address_unreach, wrong_scope,
/// safety, other). Unknown codes read as "other"; never the raw code.
String cancelReasonLabel(AppLocalizations l, String? code) => switch (_norm(code)) {
      '' => _dash,
      'plan_changed' => l.moneyCancelReasonPlanChanged,
      'wrong_time' => l.moneyCancelReasonWrongTime,
      'price' => l.moneyCancelReasonPrice,
      'found_other' => l.moneyCancelReasonFoundOther,
      'sick' => l.moneyCancelReasonSick,
      'address_unreach' => l.moneyCancelReasonAddressUnreach,
      'wrong_scope' => l.moneyCancelReasonWrongScope,
      'safety' => l.moneyCancelReasonSafety,
      _ => l.moneyCancelReasonOther,
    };

/// Cancel response `refundStatus` (none|succeeded|pending|manual); null for
/// an absent/unknown value so no raw text is ever shown.
String? refundStatusLabel(AppLocalizations l, String? status) => switch (_norm(status)) {
      'none' => l.moneyRefundStatusNone,
      'succeeded' => l.moneyRefundStatusSucceeded,
      'pending' => l.moneyRefundStatusPending,
      'manual' => l.moneyRefundStatusManual,
      _ => null,
    };

/// Tasker fine kind.
String fineKindLabel(AppLocalizations l, String? kind) {
  final k = _norm(kind);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'cancel_late' => l.fineKindCancelLate,
    'late' => l.fineKindLate,
    'extra_charge' => l.fineKindExtraCharge,
    'private_client' => l.fineKindPrivateClient,
    'bad_attitude' => l.fineKindBadAttitude,
    'fraud' => l.fineKindFraud,
    'damage' => l.fineKindDamage,
    _ => l.labelOther,
  };
}

/// Tasker fine status (`pending` / `charged` / `refunded`).
String fineStatusLabel(AppLocalizations l, String? status) {
  final k = _norm(status);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'pending' => l.provFinesPending,
    'charged' => l.provFinesDeducted,
    'refunded' => l.provFinesRefunded,
    _ => l.labelOther,
  };
}

/// Fine appeal status.
String appealStatusLabel(AppLocalizations l, String? status) {
  final k = _norm(status);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'pending' => l.appealStatusPending,
    'accepted' || 'approved' => l.appealStatusAccepted,
    'rejected' || 'denied' => l.appealStatusRejected,
    _ => l.labelOther,
  };
}

/// Tasker referral status.
String referralStatusLabel(AppLocalizations l, String? status) {
  final k = _norm(status);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'pending_kyc' => l.referralStatusPendingKyc,
    'active' => l.referralStatusActive,
    'completed' => l.referralStatusCompleted,
    _ => l.labelOther,
  };
}

/// Subscription frequency (weekly / biweekly / monthly).
String subscriptionFrequencyLabel(AppLocalizations l, String? f) {
  final k = _norm(f);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'weekly' => l.subFrequencyWeekly,
    'biweekly' => l.subFrequencyBiweekly,
    'monthly' => l.subFrequencyMonthly,
    _ => l.labelOther,
  };
}

/// Subscription status.
String subscriptionStatusLabel(AppLocalizations l, String? s) {
  final k = _norm(s);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'active' => l.subStatusActive,
    'paused' => l.subStatusPaused,
    'pending' => l.statusPending,
    'cancelled' || 'canceled' => l.statusCancelled,
    'expired' => l.subStatusExpired,
    'completed' => l.statusCompleted,
    _ => l.labelOther,
  };
}

/// Account role shown on the Account card.
String accountRoleLabel(AppLocalizations l, String? role) {
  final k = _norm(role);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'customer' => l.roleCustomer,
    'tasker' => l.roleTasker,
    'pending_tasker' => l.rolePendingTasker,
    'admin' => l.roleAdmin,
    'staff' => l.roleStaff,
    _ => l.labelOther,
  };
}

/// Tasker job (pool/assigned) status: pending / active / closed.
String jobStatusLabel(AppLocalizations l, String? status) {
  final k = _norm(status);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'pending' => l.provJobStatusPending,
    'active' => l.provJobStatusActive,
    'closed' => l.provJobStatusClosed,
    _ => l.labelOther,
  };
}

/// Tasker payout-request status.
String payoutRequestStatusLabel(AppLocalizations l, String? status) {
  final k = _norm(status);
  if (k.isEmpty) return _dash;
  return switch (k) {
    'paid' => l.provWalletPayoutRequestPaid,
    'rejected' => l.provWalletPayoutRequestRejected,
    'pending' => l.provWalletPayoutRequestPending,
    _ => l.labelOther,
  };
}

/// Tasker bonus kind.
String bonusKindLabel(AppLocalizations l, String? kind) => switch (_norm(kind)) {
      'weekly_jobs' => l.provBonusKindWeeklyJobs,
      'monthly_revenue' => l.provBonusKindMonthlyRevenue,
      'punctuality' => l.provBonusKindPunctuality,
      'rating' => l.provBonusKindRating,
      'referral' => l.provBonusKindReferral,
      '' => _dash,
      _ => l.labelOther,
    };

/// Human period label for an internal key: `2026-W41` -> "Tuần 41, 2026",
/// `2026-10` -> "Tháng 10/2026". Unparseable keys fall back to "Khác" (the raw
/// key is internal and never shown).
String periodLabel(AppLocalizations l, String? key) {
  final p = parsePeriodKey(key);
  if (p == null) return l.labelOther;
  return p.isWeek
      ? l.periodWeekLabel(p.number, p.year)
      : l.periodMonthLabel(p.number, p.year);
}
