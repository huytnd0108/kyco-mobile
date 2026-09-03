import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/breakpoints.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../../theme/app_semantics.dart';
import '../home/home_providers.dart';
import 'booking_detail_screen.dart';
import 'bookings_providers.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final twoPane = canShowTwoPanes(context);

    Widget list;
    if (twoPane) {
      final selected = ref.watch(selectedBookingIdProvider);
      list = _BookingsList(
        selectedId: selected,
        onTap: (b) => ref.read(selectedBookingIdProvider.notifier).state = b.id,
      );
    } else {
      list = _BookingsList(onTap: (b) => context.go('/bookings/${b.id}'));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.myBookings)),
      body: SafeArea(
        child: twoPane
            ? Row(children: [
                SizedBox(width: 380, child: list),
                VerticalDivider(width: 1, color: cs.outlineVariant),
                Expanded(child: _RightPane(ref.watch(selectedBookingIdProvider))),
              ])
            : list,
      ),
    );
  }
}

class _RightPane extends StatelessWidget {
  const _RightPane(this.id);
  final int? id;
  @override
  Widget build(BuildContext context) {
    if (id == null) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(AppLocalizations.of(context).selectBookingPlaceholder,
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }
    return BookingDetailScreen(id: id, embedded: true);
  }
}

class _BookingsList extends ConsumerWidget {
  const _BookingsList({required this.onTap, this.selectedId});
  final void Function(Booking) onTap;
  final int? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final bookings = ref.watch(bookingsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingsProvider);
        await ref.read(bookingsProvider.future);
      },
      child: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 120),
          ErrorRetry(message: l.bookingsLoadError(e.toString()), onRetry: () => ref.invalidate(bookingsProvider)),
        ]),
        data: (list) => list.isEmpty
            ? ListView(children: [
                const SizedBox(height: 140),
                Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.noBookingsYet, textAlign: TextAlign.center),
                )),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _BookingTile(
                  list[i],
                  selected: list[i].id == selectedId,
                  onTap: () => onTap(list[i]),
                ),
              ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile(this.b, {required this.onTap, this.selected = false});
  final Booking b;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final vnd = b.totalVnd != null
        ? NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(b.totalVnd)
        : null;
    final parts = <String>[?vnd, if (b.createdAt != null) formatBookingDate(context, b.createdAt)];
    return Card(
      color: selected ? cs.primaryContainer : null,
      child: ListTile(
        selected: selected,
        onTap: onTap,
        leading: CircleAvatar(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FittedBox(child: Text('#${b.id}')),
          ),
        ),
        title: Text(b.serviceName ?? l.bookingNumber(b.id)),
        subtitle: parts.isEmpty ? null : Text(parts.join(' • ')),
        trailing: _StatusChip(b.status),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final sem = context.semantics;
    final (bg, fg) = switch (status.toUpperCase()) {
      'SETTLED' || 'COMPLETED' || 'CONFIRMED' => (sem.successContainer, sem.onSuccessContainer),
      'CANCELLED' || 'BAD_DEBT' => (cs.errorContainer, cs.onErrorContainer),
      _ => (sem.infoContainer, sem.onInfoContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(bookingStatusLabel(l, status),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
