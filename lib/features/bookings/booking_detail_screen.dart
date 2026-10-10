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
import 'bookings_providers.dart';
import 'bookings_screen.dart' show BookingStatusChip;

/// Booking detail — written once, used both as a pushed route (compact) and as
/// the right pane of the iPad two-pane layout (embedded = true, no AppBar).
/// Loads the owner-scoped `GET /v1/bookings/{id}/page` composite (status,
/// schedule, address, assigned tasker, job timeline, `hasReview`).
///
/// Read-only for money: the total is the server's `totalVnd` shown verbatim;
/// payment / confirm-completion / cancel actions are NOT offered here (they
/// need explicit approval before the mobile client may drive them).
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
      body = _Message(l.bookingNotFound(id ?? ''));
    } else {
      final async = ref.watch(bookingDetailProvider(bid));
      body = async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => (e is ApiException && (e.code == 'NOT_FOUND' || e.status == 404))
            // Missing OR another user's booking (owner-scoped 404) — a retry
            // would fail identically, so show a plain message.
            ? _Message(l.bookingNotFound(bid))
            : ErrorRetry(
                message: l.cust2BookingsLoadFailed(apiErrorText(l, e)),
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
  const _Message(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}

/// Localized payment-method label (display only).
String paymentMethodLabel(AppLocalizations l, String? m) => switch ((m ?? '').toLowerCase()) {
      'cash' => l.cust2PayCash,
      'vnpay' => 'VNPay',
      'momo' => 'MoMo',
      '' => '—',
      final other => other,
    };

String timelineLabel(AppLocalizations l, String kind) => switch (kind) {
      'created' => l.cust2TlCreated,
      'scheduled' => l.cust2TlScheduled,
      'claimed' => l.cust2TlClaimed,
      'started' => l.cust2TlStarted,
      'finished' => l.cust2TlFinished,
      'completed' => l.cust2TlCompleted,
      'customerConfirmed' => l.cust2TlCustomerConfirmed,
      'cashReceived' => l.cust2TlCashReceived,
      'settled' => l.cust2TlSettled,
      _ => kind,
    };

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
          if (b.taskerName != null) _row(context, l.cust2DetailProvider, b.taskerName!),
          _row(context, l.totalLabel, vnd),
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
                IconButton(
                  tooltip: l.cust2RatingStar('$i'),
                  onPressed: _busy ? null : () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star : Icons.star_border, color: cs.primary, size: 34),
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
