import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/breakpoints.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
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
    final pager = ref.watch(bookingsPagerProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingsProvider);
        try { await ref.read(bookingsProvider.future); } catch (_) {/* offline pull — UI recovers via .when(error:) */}
      },
      child: bookings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 120),
          ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(bookingsProvider)),
        ]),
        data: (first) {
          // Page 1 + any appended pages (de-duplicated by id: a new booking
          // created meanwhile can shift a row across the keyset boundary).
          final seen = <int>{};
          final list = [
            for (final b in [...first, ...pager.extra])
              if (seen.add(b.id)) b,
          ];
          return list.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                // Empty state with a way forward (UX-M30): book a service.
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: l.noBookingsYet,
                  action: FilledButton.icon(
                    key: const ValueKey('bookings-empty-cta'),
                    onPressed: () => context.push('/book-now'),
                    icon: const Icon(Icons.bolt),
                    label: Text(l.bookAServiceCta),
                  ),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: list.length + (pager.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i >= list.length) {
                    return Center(
                      child: pager.loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : TextButton(
                              onPressed: () async {
                                final err = await ref.read(bookingsPagerProvider.notifier).loadMore();
                                if (err != null && context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text(apiErrorText(l, err))));
                                }
                              },
                              child: Text(l.loadMore),
                            ),
                    );
                  }
                  return _BookingTile(
                    list[i],
                    selected: list[i].id == selectedId,
                    onTap: () => onTap(list[i]),
                  );
                },
              );
        },
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
    final tt = Theme.of(context).textTheme;
    final vnd = b.totalVnd != null
        ? NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(b.totalVnd)
        : null;
    final date = b.createdAt != null ? formatBookingDate(context, b.createdAt) : null;
    // Big text: the status pill drops under the title instead of squeezing it.
    final large = MediaQuery.textScalerOf(context).scale(14) / 14 > 1.3;
    final title = Text(b.serviceName ?? l.bookingNumber(b.id),
        style: tt.titleMedium, maxLines: 4, overflow: TextOverflow.ellipsis);
    final chip = BookingStatusChip(b.status);
    return Card(
      color: selected ? cs.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // No fixed-width avatar: the id is plain text in the sub-line, so
                // the title keeps the full row and wraps at word boundaries.
                if (large)
                  title
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: title), const SizedBox(width: 8), chip],
                  ),
                const SizedBox(height: 4),
                // Each fact is one unbreakable token; the Wrap moves a whole token
                // to the next line instead of splitting "10/10/2026" mid-number.
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    for (final t in ['#${b.id}', ?vnd, ?date])
                      Text(t, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
                if (large) ...[const SizedBox(height: 8), chip],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status pill shared by the list and the detail header.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final sem = context.semantics;
    final (bg, fg) = switch (bookingStatusTone(status)) {
      BookingTone.success => (sem.successContainer, sem.onSuccessContainer),
      BookingTone.danger => (cs.errorContainer, cs.onErrorContainer),
      BookingTone.warning => (sem.warningContainer, sem.onWarningContainer),
      BookingTone.info => (sem.infoContainer, sem.onInfoContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(bookingStatusLabel(l, status),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}
