import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/idempotency_ledger.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import '../home/home_providers.dart';
import 'payment_flow.dart';
import 'package:kyco_mobile/core/labels.dart';

const kDisputeNoteMin = 10;
const kDisputeNoteMax = 2000;
const kCancelNoteMax = 500;

/// Cancel reasons the server enforces (contract update): exactly these codes;
/// `reasonText` is at most [kCancelNoteMax] characters.
const kCancelReasonCodes = <String>[
  'plan_changed',
  'wrong_time',
  'price',
  'found_other',
  'other',
];

/// Methods `confirm-completion` accepts (contract 3.1).
const kConfirmMethods = <String>['cash', 'momo', 'vnpay'];

/// Same rule as the server (`confirm-completion-write.ts`): trimmed 10..2000.
String? validateDisputeNote(AppLocalizations l, String raw) {
  final n = raw.trim().length;
  if (n < kDisputeNoteMin) return l.moneyDisputeTooShort(kDisputeNoteMin);
  if (n > kDisputeNoteMax) return l.moneyDisputeTooLong(kDisputeNoteMax);
  return null;
}

/// Success text: the server's fee / refund numbers when the response has them.
String cancelDoneText(AppLocalizations l, CancelResult r) => [
      l.moneyCancelDone,
      if ((r.feeVnd ?? 0) > 0) l.moneyCancelFeeLine(formatVnd(r.feeVnd!)),
      if ((r.refundVnd ?? 0) > 0) l.moneyCancelRefundLine(formatVnd(r.refundVnd!)),
      ?refundStatusLabel(l, r.refundStatus),
    ].join(' ');

void _refresh(WidgetRef ref, int bookingId) {
  ref.invalidate(bookingDetailProvider(bookingId));
  ref.invalidate(bookingsProvider);
}

/// A 409/422 means the server's view of the booking differs from ours (wrong
/// status, 24h lock ...): show its real state again.
bool _isStateMismatch(ApiException e) => e.status == 409 || e.status == 422;

/// All customer money actions of the booking detail: confirm / report an issue,
/// cancel, and the gateway pay + confirm-payment panel. Which ones appear is
/// decided by [BookingActions] (server status/flags only).
class BookingMoneySection extends ConsumerStatefulWidget {
  const BookingMoneySection(this.booking, {super.key});
  final BookingDetail booking;

  @override
  ConsumerState<BookingMoneySection> createState() => _BookingMoneySectionState();
}

class _BookingMoneySectionState extends ConsumerState<BookingMoneySection> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the browser/PSP app is NOT proof of payment: it only
    // triggers asking the server.
    if (state == AppLifecycleState.resumed &&
        ref.read(payFlowProvider(widget.booking.id)).phase == PayPhase.awaiting) {
      ref.read(payFlowProvider(widget.booking.id).notifier).check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final a = BookingActions.of(b);
    final pay = ref.watch(payFlowProvider(b.id));
    final showPay = a.canPay || pay.phase != PayPhase.idle;
    if (!a.canCancel && !a.canConfirm && !a.awaitingCashConfirm && !showPay && !b.manualSettlementRequired) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        if (b.manualSettlementRequired) _note(context, Icons.hourglass_top, l.moneyManualSettlementNote),
        if (a.awaitingCashConfirm) _note(context, Icons.hourglass_top, l.moneyCashAwaitingNote),
        if (a.canConfirm) ...[
          FilledButton(
            key: const ValueKey('booking-confirm-cta'),
            onPressed: () => _confirm(context),
            child: Text(l.moneyConfirmAction),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('booking-dispute-cta'),
            onPressed: a.canDispute ? () => _dispute(context) : null,
            child: Text(l.moneyDisputeAction),
          ),
          if (a.disputeWaiting)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(l.moneyDisputeWaiting, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
        ],
        if (showPay) _PayPanel(b),
        if (a.canCancel)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              key: const ValueKey('booking-cancel-cta'),
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
              onPressed: () => _cancel(context),
              child: Text(l.moneyCancelAction),
            ),
          ),
      ],
    );
  }

  Widget _note(BuildContext context, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );

  Future<void> _cancel(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final done = await showDialog<CancelResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CancelBookingDialog(bookingId: widget.booking.id, preview: widget.booking.cancelPreview,
          reasons: widget.booking.cancelReasons),
    );
    if (done != null) messenger.showSnackBar(SnackBar(content: Text(cancelDoneText(l, done))));
  }

  Future<void> _confirm(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConfirmCompletionDialog(booking: widget.booking),
    );
    if (done == true) messenger.showSnackBar(SnackBar(content: Text(l.moneyConfirmDone)));
  }

  Future<void> _dispute(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DisputeDialog(bookingId: widget.booking.id),
    );
    if (done == true) messenger.showSnackBar(SnackBar(content: Text(l.moneyDisputeSent)));
  }
}

// ── cancel ──────────────────────────────────────────────────────────────────

/// Confirms a customer cancel. States the policy in words only — the server
/// owns the fee and no preview exists, so NO amount is shown or computed.
class CancelBookingDialog extends ConsumerStatefulWidget {
  const CancelBookingDialog({super.key, required this.bookingId, this.preview, this.reasons = const []});
  final int bookingId;

  /// Server preview (`cancelPreview`); null = show the policy text only.
  final CancelPreview? preview;

  /// Server reasons with server-localized labels; empty = built-in fallback list.
  final List<CancelReasonOption> reasons;
  @override
  ConsumerState<CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends ConsumerState<CancelBookingDialog> {
  String? _reason;
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _reason;
    if (code == null || _busy) return;
    final l = AppLocalizations.of(context);
    final text = _note.text.trim();
    if (!_options(l).any((o) => o.code == code) || text.length > kCancelNoteMax) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(idempotencyLedgerProvider).run(
            'booking-cancel:${widget.bookingId}:$code.${IdempotencyLedger.textTag(text)}',
            (key) => ref.read(kycoApiProvider).cancelBooking(widget.bookingId,
                reasonCode: code, reasonText: text.isEmpty ? null : text, idempotencyKey: key),
          );
      _refresh(ref, widget.bookingId);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (e is ApiException && _isStateMismatch(e)) _refresh(ref, widget.bookingId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = apiErrorText(l, e);
      });
    }
  }

  /// Server list when present, else the customer fallback with ARB labels.
  List<CancelReasonOption> _options(AppLocalizations l) => widget.reasons.isNotEmpty
      ? widget.reasons
      : [for (final c in kCancelReasonCodes) CancelReasonOption(c, cancelReasonLabel(l, c))];

  /// Server numbers only — fee, refund when > 0, and the server's reason text.
  List<Widget> _previewLines(AppLocalizations l, CancelPreview p) => [
        const SizedBox(height: 12),
        if (p.reason != null) Text(p.reason!, key: const ValueKey('cancel-preview-reason')),
        if (p.feeVnd != null)
          Text(l.moneyCancelFeeLine(formatVnd(p.feeVnd!)),
              key: const ValueKey('cancel-preview-fee'), style: const TextStyle(fontWeight: FontWeight.w600)),
        if ((p.refundVnd ?? 0) > 0)
          Text(l.moneyCancelRefundLine(formatVnd(p.refundVnd!)),
              key: const ValueKey('cancel-preview-refund'), style: const TextStyle(fontWeight: FontWeight.w600)),
      ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l.moneyCancelTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.moneyCancelPolicy, key: const ValueKey('cancel-policy')),
              if (widget.preview != null) ..._previewLines(l, widget.preview!),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('cancel-reason'),
                initialValue: _reason,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.moneyCancelReasonLabel),
                items: [
                  for (final o in _options(l)) DropdownMenuItem(value: o.code, child: Text(o.label)),
                ],
                onChanged: _busy ? null : (v) => setState(() => _reason = v),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('cancel-note'),
                controller: _note,
                enabled: !_busy,
                maxLength: kCancelNoteMax,
                maxLines: 3,
                minLines: 2,
                decoration: InputDecoration(labelText: l.moneyCancelNoteLabel),
              ),
              if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('cancel-keep'),
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(l.moneyCancelKeep),
          ),
          FilledButton(
            key: const ValueKey('cancel-submit'),
            onPressed: (_busy || _reason == null) ? null : _submit,
            child: _busy ? const _Spinner() : Text(l.moneyCancelConfirm),
          ),
        ],
      ),
    );
  }
}

// ── confirm completion / dispute ────────────────────────────────────────────

class ConfirmCompletionDialog extends ConsumerStatefulWidget {
  const ConfirmCompletionDialog({super.key, required this.booking});
  final BookingDetail booking;
  @override
  ConsumerState<ConfirmCompletionDialog> createState() => _ConfirmCompletionDialogState();
}

class _ConfirmCompletionDialogState extends ConsumerState<ConfirmCompletionDialog> {
  late String _method;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = (widget.booking.paymentMethod ?? '').toLowerCase();
    _method = kConfirmMethods.contains(m) ? m : 'cash';
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final id = widget.booking.id;
    final method = _method;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(idempotencyLedgerProvider).run(
            'booking-confirm:$id:confirm:$method',
            (key) => ref
                .read(kycoApiProvider)
                .confirmCompletion(id, action: 'confirm', paymentMethod: method, idempotencyKey: key),
          );
      _refresh(ref, id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (e is ApiException && _isStateMismatch(e)) _refresh(ref, id);
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
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l.moneyConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.moneyConfirmMethodLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final m in kConfirmMethods)
                  ChoiceChip(
                    key: ValueKey('confirm-method-$m'),
                    label: Text(m == 'cash' ? l.cust2PayCash : (m == 'momo' ? 'MoMo' : 'VNPay')),
                    selected: _method == m,
                    onSelected: _busy ? null : (_) => setState(() => _method = m),
                  ),
              ]),
              if (_method != 'cash') ...[
                const SizedBox(height: 8),
                Text(l.moneyConfirmOnlineNote, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
              if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(l.moneyDialogClose),
          ),
          FilledButton(
            key: const ValueKey('confirm-submit'),
            onPressed: _busy ? null : _submit,
            child: _busy ? const _Spinner() : Text(l.moneyConfirmSubmit),
          ),
        ],
      ),
    );
  }
}

class DisputeDialog extends ConsumerStatefulWidget {
  const DisputeDialog({super.key, required this.bookingId});
  final int bookingId;
  @override
  ConsumerState<DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends ConsumerState<DisputeDialog> {
  final _note = TextEditingController();
  bool _busy = false;
  bool _attempted = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    setState(() => _attempted = true);
    if (validateDisputeNote(l, _note.text) != null) return;
    final note = _note.text.trim();
    final id = widget.bookingId;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(idempotencyLedgerProvider).run(
            'booking-confirm:$id:dispute:${IdempotencyLedger.textTag(note)}',
            (key) => ref
                .read(kycoApiProvider)
                .confirmCompletion(id, action: 'dispute', note: note, idempotencyKey: key),
          );
      _refresh(ref, id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (e is ApiException && _isStateMismatch(e)) _refresh(ref, id);
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
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l.moneyDisputeTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('dispute-note'),
                controller: _note,
                enabled: !_busy,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  labelText: l.moneyDisputeHint(kDisputeNoteMin, kDisputeNoteMax),
                  errorText: _attempted ? validateDisputeNote(l, _note.text) : null,
                ),
                onChanged: (_) {
                  if (_attempted) setState(() {});
                },
              ),
              if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(_error!)],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: Text(l.moneyDialogClose),
          ),
          FilledButton(
            key: const ValueKey('dispute-submit'),
            onPressed: _busy ? null : _submit,
            child: _busy ? const _Spinner() : Text(l.moneyDisputeSubmit),
          ),
        ],
      ),
    );
  }
}

// ── pay ─────────────────────────────────────────────────────────────────────

class _PayPanel extends ConsumerWidget {
  const _PayPanel(this.b);
  final BookingDetail b;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final st = ref.watch(payFlowProvider(b.id));
    final ctrl = ref.read(payFlowProvider(b.id).notifier);
    final method = (b.paymentMethod ?? '').toLowerCase() == 'momo' ? 'MoMo' : 'VNPay';

    Widget payButton({bool outlined = false, String? label}) {
      final child = st.phase == PayPhase.initiating
          ? const _Spinner()
          : Text(label ?? l.moneyPayAction(method));
      return outlined
          ? OutlinedButton(
              key: const ValueKey('pay-again'), onPressed: st.busy ? null : ctrl.pay, child: child)
          : FilledButton(key: const ValueKey('pay-cta'), onPressed: st.busy ? null : ctrl.pay, child: child);
    }

    Widget status(String text, {bool spinner = false}) => Row(children: [
          if (spinner) ...[const _Spinner(), const SizedBox(width: 10)],
          Expanded(child: Text(text, key: const ValueKey('pay-status'))),
        ]);

    final children = switch (st.phase) {
      PayPhase.idle || PayPhase.initiating => [payButton()],
      PayPhase.awaiting || PayPhase.checking => [
          status(l.moneyPayConfirming, spinner: true),
          const SizedBox(height: 4),
          Text(l.moneyPayWaitNote, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('pay-i-paid'),
            onPressed: st.busy ? null : ctrl.check,
            child: st.phase == PayPhase.checking ? const _Spinner() : Text(l.moneyPayIPaid),
          ),
          const SizedBox(height: 8),
          payButton(outlined: true, label: l.moneyPayReopen),
        ],
      PayPhase.paid => [status(l.moneyPayPaid)],
      PayPhase.failed => [ErrorBanner(l.moneyPayFailed), const SizedBox(height: 8), payButton()],
      PayPhase.timeout => [
          status(l.moneyPayTimeout),
          const SizedBox(height: 8),
          FilledButton(key: const ValueKey('pay-i-paid'), onPressed: ctrl.check, child: Text(l.moneyPayCheckAgain)),
          const SizedBox(height: 8),
          payButton(outlined: true, label: l.moneyPayReopen),
        ],
      PayPhase.cash => [status(l.moneyPayCash)],
      PayPhase.alreadyPaid => [status(l.moneyPayAlready)],
      PayPhase.noRail => [ErrorBanner(l.moneyPayNoRail)],
      PayPhase.openFailed => [ErrorBanner(l.moneyPayOpenFailed), const SizedBox(height: 8), payButton()],
      PayPhase.error => [
          ErrorBanner(apiErrorText(l, st.error)),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey('pay-retry'),
            onPressed: ctrl.pay,
            child: Text(l.retry),
          ),
        ],
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2));
}
