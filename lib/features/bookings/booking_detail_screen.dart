import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/breakpoints.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../home/home_providers.dart';
import 'bookings_providers.dart';

/// Booking detail — written once, used both as a pushed route (compact) and as
/// the right pane of the iPad two-pane layout (embedded = true, no AppBar).
/// No dedicated GET /bookings/:id endpoint exists; the row is resolved from the
/// bookings list provider.
class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.id, this.embedded = false});
  final int? id;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // On a wide window the detail belongs in the two-pane's right pane, not as
    // a full-screen push. If we were pushed (deep link / resize), hand the id
    // to the selection provider and drop back to the list; the pane renders it.
    if (!embedded && canShowTwoPanes(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedBookingIdProvider.notifier).state = id;
        if (context.mounted) context.go('/bookings');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final async = ref.watch(bookingsProvider);
    final body = async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetry(
        message: l.bookingsLoadError(e.toString()),
        onRetry: () => ref.invalidate(bookingsProvider),
      ),
      data: (list) {
        Booking? b;
        for (final x in list) {
          if (x.id == id) {
            b = x;
            break;
          }
        }
        if (b == null) {
          // The list loaded fine — this id just isn't in it. A retry would
          // refetch the same list and fail identically, so show a plain message.
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l.bookingNotFound(id ?? ''), textAlign: TextAlign.center),
            ),
          );
        }
        return _Detail(b);
      },
    );
    if (embedded) return SafeArea(child: body);
    return Scaffold(
      appBar: AppBar(title: Text(l.bookingDetailTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.b);
  final Booking b;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final vnd = b.totalVnd != null
        ? NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(b.totalVnd)
        : '—';
    return CenteredMaxWidth(
      maxWidth: 700,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.bookingNumber(b.id),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _row(context, l.serviceLabel, b.serviceName ?? '—'),
          _row(context, l.statusLabel, bookingStatusLabel(l, b.status)),
          _row(context, l.totalLabel, vnd),
          _row(context, l.createdLabel, formatBookingDate(context, b.createdAt)),
          const SizedBox(height: 8),
          Divider(color: cs.outlineVariant),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
