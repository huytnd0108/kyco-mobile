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

/// Client-side label for the booking status enum. Falls back to the raw value
/// for statuses the app doesn't know (keeps working if the backend adds one).
String bookingStatusLabel(AppLocalizations l, String status) => switch (status.toUpperCase()) {
      'PENDING' => l.statusPending,
      'CONFIRMED' => l.statusConfirmed,
      'COMPLETED' => l.statusCompleted,
      'SETTLED' => l.statusSettled,
      'CANCELLED' => l.statusCancelled,
      'BAD_DEBT' => l.statusBadDebt,
      _ => status,
    };
