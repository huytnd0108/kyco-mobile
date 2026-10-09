import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Selected booking in the iPad two-pane layout (null = show placeholder).
final selectedBookingIdProvider = StateProvider<int?>((_) => null);

/// Localized date for a raw API timestamp (ISO-8601). Falls back to the raw
/// string if unparseable — never shows an ISO blob to the user.
String formatBookingDate(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat.yMd(Localizations.localeOf(context).toString()).format(dt.toLocal());
}

/// Client-side label for every booking status of the backend FSM
/// (`lib/orders/status-machine.ts`, 15 states). Falls back to the raw value for
/// a status the app doesn't know (keeps working if the backend adds one).
String bookingStatusLabel(AppLocalizations l, String status) => switch (status.toUpperCase()) {
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
      _ => status,
    };

/// Coarse tone for a status chip: done / problem / in-flight.
enum BookingTone { success, danger, info, warning }

BookingTone bookingStatusTone(String status) => switch (status.toUpperCase()) {
      'SETTLED' || 'COMPLETED' || 'CONFIRMED' || 'CLOSED' => BookingTone.success,
      'CANCELLED' || 'BAD_DEBT' || 'IN_DISPUTE' => BookingTone.danger,
      'AWAITING_CUSTOMER_CONFIRMATION' || 'AWAITING_PAYMENT' || 'AWAITING_CASH_CONFIRM' => BookingTone.warning,
      _ => BookingTone.info,
    };

/// Localized date+time for a raw API timestamp (ISO-8601 or Postgres
/// `YYYY-MM-DD HH:MM:SS+00`). Never shows an unparsed blob if avoidable.
String formatBookingDateTime(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat.yMd(Localizations.localeOf(context).toString()).add_Hm().format(dt.toLocal());
}
