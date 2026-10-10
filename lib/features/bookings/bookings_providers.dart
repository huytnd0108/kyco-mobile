import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:kyco_mobile/core/labels.dart' show bookingStatusLabel;
import 'package:kyco_mobile/core/datetime.dart';

/// Selected booking in the iPad two-pane layout (null = show placeholder).
final selectedBookingIdProvider = StateProvider<int?>((_) => null);

/// Localized date (VN time) for a raw API timestamp; '—' when unparseable.
String formatBookingDate(BuildContext context, String? raw) => vnDate(context, raw);

/// Coarse tone for a status chip: done / problem / in-flight.
enum BookingTone { success, danger, info, warning }

BookingTone bookingStatusTone(String status) => switch (status.toUpperCase()) {
      'SETTLED' || 'COMPLETED' || 'CONFIRMED' || 'CLOSED' => BookingTone.success,
      'CANCELLED' || 'BAD_DEBT' || 'IN_DISPUTE' => BookingTone.danger,
      'AWAITING_CUSTOMER_CONFIRMATION' || 'AWAITING_PAYMENT' || 'AWAITING_CASH_CONFIRM' => BookingTone.warning,
      _ => BookingTone.info,
    };

/// Localized date+time (VN time) for a raw API timestamp (ISO-8601 or Postgres
/// `YYYY-MM-DD HH:MM:SS+00`); '—' when unparseable.
String formatBookingDateTime(BuildContext context, String? raw) =>
    vnDateTime(context, raw);
