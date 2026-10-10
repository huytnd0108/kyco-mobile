import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/api/problem.dart';
import '../../core/breakpoints.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import '../home/home_providers.dart';
import 'booking_money_actions.dart';
import 'bookings_providers.dart';
import 'bookings_screen.dart' show BookingStatusChip;
import 'customer_sos.dart';
import 'tracking_card.dart';
import 'package:kyco_mobile/core/labels.dart';

/// Booking detail — written once, used both as a pushed route (compact) and as
/// the right pane of the iPad two-pane layout (embedded = true, no AppBar).
/// Loads the owner-scoped `GET /v1/bookings/{id}/page` composite (status,
/// schedule, address, assigned tasker, job timeline, `hasReview`).
///
/// Money: the total is the server's `totalVnd` and the itemisation is the
/// server's `surchargeBreakdownJson`, both shown verbatim — nothing is computed
/// here. Cancel / confirm completion / gateway pay are offered per
/// [BookingActions] (user-approved 2026-10-10) via [BookingMoneySection].
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
    final bid = id;
    final Widget body;
    if (bid == null || bid <= 0) {
      body = _Message(l.bookingNotFoundNoId, showBack: true);
    } else {
      final async = ref.watch(bookingDetailProvider(bid));
      body = async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => (e is ApiException && (e.code == 'NOT_FOUND' || e.status == 404))
            // Missing OR another user's booking (owner-scoped 404) — a retry
            // would fail identically, so show a plain message.
            ? _Message(l.bookingNotFound(bid), showBack: true)
            : ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(bookingDetailProvider(bid)),
              ),
        data: (b) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bookingDetailProvider(bid));
            try {
              await ref.read(bookingDetailProvider(bid).future);
            } catch (_) {/* UI recovers via .when(error:) */}
          },
          child: _Detail(b),
        ),
      );
    }
    if (embedded) return SafeArea(child: body);
    return Scaffold(
      appBar: AppBar(title: Text(l.bookingDetailTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.showBack = false});
  final String text;

  /// Offer a way out ("Back to my bookings") instead of a dead end.
  final bool showBack;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(text, textAlign: TextAlign.center),
              if (showBack) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  key: const ValueKey('booking-back'),
                  onPressed: () => context.go('/bookings'),
                  child: Text(AppLocalizations.of(context).backToMyBookings),
                ),
              ],
            ],
          ),
        ),
      );
}

class _Detail extends ConsumerWidget {
  const _Detail(this.b);
  final BookingDetail b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final vnd = b.totalVnd != null
        ? NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(b.totalVnd)
        : '—';
    final address = [b.addressLine, b.ward, b.district].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
    return CenteredMaxWidth(
      maxWidth: 700,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.bookingNumber(b.id),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              BookingStatusChip(b.status),
            ],
          ),
          const SizedBox(height: 16),
          _row(context, l.serviceLabel, b.serviceName ?? '—'),
          _row(context, l.statusLabel, bookingStatusLabel(l, b.status)),
          _row(context, l.cust2DetailScheduled, formatBookingDateTime(context, b.scheduledAt)),
          if (address.isNotEmpty) _row(context, l.cust2DetailAddress, address),
          if (b.notes != null) _row(context, l.cust2DetailNotes, b.notes!),
          if (b.taskerName != null)
            _row(context, l.cust2DetailProvider, b.taskerName!,
                // UX-M17: the assigned tasker opens the public profile.
                onTap: b.taskerId == null ? null : () => context.push('/taskers/${b.taskerId}'),
                semanticsLabel: l.openTaskerProfile(b.taskerName!)),
          _row(context, l.totalLabel, vnd),
          if (b.breakdown != null) _breakdown(context, l, b.breakdown!),
          _row(context, l.cust2DetailPayment, paymentMethodLabel(l, b.paymentMethod)),
          if (b.confirmationCode != null) _row(context, l.cust2DetailCode, b.confirmationCode!),
          _row(context, l.createdLabel, formatBookingDate(context, b.createdAt)),
          const SizedBox(height: 8),
          Divider(color: cs.outlineVariant),
          if (b.timeline.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(l.cust2DetailTimeline, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final ev in b.timeline)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 10, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(timelineLabel(l, ev.kind))),
                    Text(formatBookingDateTime(context, ev.at), style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
          ],
          // UX-M09: follow the tasker while they travel to / work at the address.
          if (isTrackable(b.status) && b.jobId != null) TrackingCard(jobId: b.jobId!),
          BookingMoneySection(b),
          // UX-M11: the booking thread (read via /page, send via /messages).
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('booking-chat'),
            onPressed: () => context.push('/messages/${b.id}'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(l.messagesTitle),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          // UX-M13: customer safety path while the tasker is on the way / on site.
          if (isTrackable(b.status)) ...[
            const SizedBox(height: 12),
            CustomerSosButton(bookingId: b.id),
          ],
          if (b.canReview) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const ValueKey('booking-review-cta'),
              onPressed: () => _review(context, ref),
              icon: const Icon(Icons.star_outline),
              label: Text(l.cust2ReviewCta),
            ),
          ] else if (b.hasReview) ...[
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.check_circle_outline, color: cs.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(l.cust2ReviewDone, style: TextStyle(color: cs.onSurfaceVariant))),
            ]),
          ],
        ],
      ),
    );
  }

  /// The server's itemisation, line by line as received (no arithmetic).
  Widget _breakdown(BuildContext context, AppLocalizations l, PriceBreakdownView bd) {
    final cs = Theme.of(context).colorScheme;
    String money(int v) => NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(v);
    Widget line(String label, int amount) => Padding(
          padding: const EdgeInsets.only(left: 120, bottom: 4),
          child: Row(children: [
            Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant))),
            Text(money(amount), style: TextStyle(color: cs.onSurfaceVariant)),
          ]),
        );
    return Column(
      key: const ValueKey('booking-breakdown'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bd.hasSurcharge)
          line(
              bd.surchargeReasons.isEmpty
                  ? l.moneySurchargeLabel
                  : '${l.moneySurchargeLabel} (${bd.surchargeReasons.join(', ')})',
              bd.surchargesVnd!),
        for (final c in bd.compensations) line(c.label, c.amountVnd),
        if (bd.compensations.isEmpty && (bd.compensationVnd ?? 0) > 0)
          line(l.moneyCompensationLabel, bd.compensationVnd!),
      ],
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ReviewSheet(bookingId: b.id),
    );
    if (done == true) {
      ref.invalidate(bookingDetailProvider(b.id));
      messenger.showSnackBar(SnackBar(content: Text(l.cust2ReviewThanks)));
    }
  }

  Widget _row(BuildContext context, String label, String value,
      {VoidCallback? onTap, String? semanticsLabel}) {
    final cs = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: onTap == null ? null : cs.primary,
                    decoration: onTap == null ? null : TextDecoration.underline)),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      link: true,
      label: semanticsLabel ?? '$label: $value',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        key: const ValueKey('booking-tasker-row'),
        onTap: onTap,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: content),
      ),
    );
  }
}

/// Star rating + optional comment → `POST /v1/reviews` (non-money). Pops
/// `true` on success.
class ReviewSheet extends ConsumerStatefulWidget {
  const ReviewSheet({super.key, required this.bookingId});
  final int bookingId;
  @override
  ConsumerState<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<ReviewSheet> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_rating < 1) {
      setState(() => _error = l.cust2RatingRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(kycoApiProvider).createReview(
            bookingId: widget.bookingId,
            rating: _rating,
            comment: _comment.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = apiErrorText(l, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.cust2ReviewCta, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                Semantics(
                  selected: i == _rating,
                  inMutuallyExclusiveGroup: true,
                  child: IconButton(
                    tooltip: l.cust2RatingStar('$i'),
                    onPressed: _busy ? null : () => setState(() => _rating = i),
                    icon: Icon(i <= _rating ? Icons.star : Icons.star_border, color: cs.primary, size: 34),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLength: 1000,
            maxLines: 4,
            minLines: 2,
            decoration: InputDecoration(labelText: l.cust2ReviewComment),
          ),
          if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.cust2ReviewSubmit),
          ),
        ],
      ),
    );
  }
}
