import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import 'provider_job_detail_data.dart';

/// The scrolling lifecycle-hub body. Pure presentation: it reads the payload and
/// the derived [JobPhase] and calls back up to the screen for every mutation.
/// It renders NO computed money — all figures are payload fields.
class JobDetailBody extends StatelessWidget {
  const JobDetailBody({
    super.key,
    required this.detail,
    required this.busy,
    required this.onConfirm,
    required this.onDecline,
    required this.onCancel,
    required this.onStartTracking,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onCapture,
    required this.onFaceVerify,
    required this.onComplete,
    required this.onCashReceived,
    required this.onComplaint,
    required this.onSos,
    required this.onSendMessage,
  });

  final ProviderJobDetail detail;
  final String? busy;
  final VoidCallback onConfirm, onDecline, onCancel, onStartTracking, onCheckIn,
      onCheckOut, onFaceVerify, onComplete, onCashReceived, onComplaint, onSos;
  final void Function(PhotoSlot slot) onCapture;
  final void Function(String body) onSendMessage;

  bool get _anyBusy => busy != null;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final phase = deriveJobPhase(d);
    final counts = PhotoCounts.ofJob(d.job);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _PhaseBanner(phase: phase, detail: d),
        const SizedBox(height: 16),
        _OrderInfoCard(detail: d),
        const SizedBox(height: 16),
        _PaymentCard(detail: d),
        const SizedBox(height: 16),
        _LifecycleActionsCard(
          phase: phase,
          detail: d,
          counts: counts,
          busy: busy,
          anyBusy: _anyBusy,
          onConfirm: onConfirm,
          onDecline: onDecline,
          onCancel: onCancel,
          onStartTracking: onStartTracking,
          onCheckIn: onCheckIn,
          onCheckOut: onCheckOut,
          onFaceVerify: onFaceVerify,
          onComplete: onComplete,
          onCashReceived: onCashReceived,
        ),
        if (phase == JobPhase.onSite || phase == JobPhase.wrapUp || phase == JobPhase.enRoute) ...[
          const SizedBox(height: 16),
          _PhotosCard(
            counts: counts,
            busy: busy,
            anyBusy: _anyBusy,
            onCapture: onCapture,
          ),
        ],
        if (sosEnabled(d)) ...[
          const SizedBox(height: 16),
          _SosCard(anyBusy: _anyBusy, busy: busy, onSos: onSos),
        ],
        if (_s(d.job['status']).toLowerCase() == 'active') ...[
          const SizedBox(height: 16),
          _LiveShareCard(detail: d),
        ],
        const SizedBox(height: 16),
        _ChatCard(detail: d, anyBusy: _anyBusy, busy: busy, onSend: onSendMessage),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: _anyBusy ? null : onComplaint,
            icon: const Icon(Icons.report_gmailerrorred_outlined, size: 18),
            label: Text(AppLocalizations.of(context).provJdReportProblem),
          ),
        ),
      ],
    );
  }
}

String _s(dynamic v) => v == null ? '' : v.toString();

// ── phase banner ─────────────────────────────────────────────────────────────

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.phase, required this.detail});
  final JobPhase phase;
  final ProviderJobDetail detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final (label, icon, tone) = switch (phase) {
      JobPhase.pending => (l.provJdPhasePending, Icons.hourglass_top, cs.tertiary),
      JobPhase.enRoute => (l.provJdPhaseEnRoute, Icons.directions_car, cs.primary),
      JobPhase.onSite => (l.provJdPhaseOnSite, Icons.cleaning_services, cs.primary),
      JobPhase.wrapUp => (l.provJdPhaseWrapUp, Icons.task_alt, cs.primary),
      JobPhase.awaitingCustomer => (l.provJdPhaseAwaitingCustomer, Icons.schedule, cs.tertiary),
      JobPhase.awaitingCash => (l.provJdPhaseAwaitingCash, Icons.payments, cs.tertiary),
      JobPhase.awaitingPayment => (l.provJdPhaseAwaitingPayment, Icons.account_balance, cs.tertiary),
      JobPhase.settled => (l.provJdPhaseSettled, Icons.verified, Colors.green),
      JobPhase.closed => (l.provJdPhaseClosed, Icons.lock_outline, cs.onSurfaceVariant),
      JobPhase.cancelled => (l.provJdPhaseCancelled, Icons.cancel_outlined, cs.error),
      JobPhase.unknown => (l.provJdPhaseUnknown, Icons.info_outline, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface))),
        ],
      ),
    );
  }
}

// ── order info ───────────────────────────────────────────────────────────────

class _OrderInfoCard extends StatelessWidget {
  const _OrderInfoCard({required this.detail});
  final ProviderJobDetail detail;

  @override
  Widget build(BuildContext context) {
    final b = detail.booking ?? const {};
    final svc = detail.service ?? const {};
    final cust = detail.customer ?? const {};
    final where = [b['addressLine'], b['ward'], b['district']]
        .map(_s)
        .where((s) => s.isNotEmpty)
        .join(', ');
    final duration = svc['durationMinutes'];
    final l = AppLocalizations.of(context);
    return _Card(
      title: l.provJdOrderInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(context, l.provJdCustomer, _s(cust['name']).isEmpty ? '—' : _s(cust['name'])),
          _kv(context, l.email, _s(cust['email']).isEmpty ? '—' : _s(cust['email'])),
          _kv(context, l.provJdTime, fmtJobTime(_s(b['scheduledAt']).isEmpty ? null : _s(b['scheduledAt']))),
          _kv(context, l.provJdDuration,
              duration is num ? l.minutesShort(duration.toInt()) : '—'),
          _kv(context, l.provJdAddress, where.isEmpty ? '—' : where),
          if (_s(b['notes']).isNotEmpty)
            _kv(context, l.notesLabel, _s(b['notes'])),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ── payment (display-only) ───────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.detail});
  final ProviderJobDetail detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final b = detail.booking ?? const {};
    final total = detail.totalVnd;
    final earnings = detail.job['earningsVnd'];
    final l = AppLocalizations.of(context);
    final method = _payLabel(context, _s(b['paymentMethod']));
    return _Card(
      title: l.provJdPayment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(total == null ? '—' : formatVnd(total),
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: cs.primary)),
          const SizedBox(height: 2),
          Text(method, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          if (earnings is num) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.provJdYourEarnings),
                Text(formatVnd(earnings.toInt()), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            l.provJdAmountsComputed,
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  String _payLabel(BuildContext context, String m) => switch (m) {
        'cash' => AppLocalizations.of(context).provJdPayCash,
        'vnpay' => 'VNPay',
        'momo' => 'MoMo',
        'zalopay' => 'ZaloPay',
        'bank_transfer' => AppLocalizations.of(context).provJdPayBankTransfer,
        '' => '—',
        _ => m,
      };
}

// ── lifecycle actions ────────────────────────────────────────────────────────

class _LifecycleActionsCard extends StatelessWidget {
  const _LifecycleActionsCard({
    required this.phase,
    required this.detail,
    required this.counts,
    required this.busy,
    required this.anyBusy,
    required this.onConfirm,
    required this.onDecline,
    required this.onCancel,
    required this.onStartTracking,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onFaceVerify,
    required this.onComplete,
    required this.onCashReceived,
  });

  final JobPhase phase;
  final ProviderJobDetail detail;
  final PhotoCounts counts;
  final String? busy;
  final bool anyBusy;
  final VoidCallback onConfirm, onDecline, onCancel, onStartTracking, onCheckIn,
      onCheckOut, onFaceVerify, onComplete, onCashReceived;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final children = <Widget>[];

    switch (phase) {
      case JobPhase.pending:
        children.add(_action(context, 'confirm', l.provJdConfirmAccept, Icons.check, onConfirm, primary: true));
        children.add(_action(context, 'decline', l.provJdDecline, Icons.close, onDecline, outlined: true));
        children.add(_action(context, 'cancel', l.provJdCancelTitle, Icons.cancel_outlined, onCancel, danger: true));
      case JobPhase.enRoute:
        children.add(_action(context, 'start', l.provJdStartTracking, Icons.directions_car, onStartTracking, primary: true));
        children.add(_action(context, 'checkin', l.provJdCheckIn, Icons.my_location, onCheckIn, primary: true));
        children.add(_action(context, 'cancel', l.provJdCancelTitle, Icons.cancel_outlined, onCancel, danger: true));
      case JobPhase.onSite:
        if (!counts.meetsCheckout) {
          children.add(_note(context, l.provJdBeforePhotoGate(kBeforePhotosRequired, counts.before)));
        }
        children.add(_action(context, 'face', l.provJdFaceVerify, Icons.face_retouching_natural, onFaceVerify, outlined: true));
        children.add(_action(context, 'checkout', l.provJdCheckOut, Icons.logout, onCheckOut, primary: true));
      case JobPhase.wrapUp:
        children.add(_progress(context));
        children.add(_action(context, 'complete', l.provJdMarkComplete, Icons.task_alt, onComplete, primary: true));
      case JobPhase.awaitingCash:
        if (_s(detail.booking?['paymentMethod']) == 'cash') {
          children.add(_action(context, 'cash', l.provJdCashReceivedAction, Icons.payments, onCashReceived, primary: true));
          children.add(_warn(context, l.provJdCashCommissionNote));
        }
      case JobPhase.awaitingCustomer:
        children.add(_info(context, l.provJdAwaitingCustomerInfo));
      case JobPhase.awaitingPayment:
        children.add(_info(context, l.provJdAwaitingPaymentInfo));
      case JobPhase.settled:
        children.add(_settled(context));
      case JobPhase.closed:
        children.add(_info(context, l.provJdClosedInfo));
      case JobPhase.cancelled:
        children.add(_info(context, l.provJdCancelledInfo));
      case JobPhase.unknown:
        children.add(_info(context, l.provJdNoActions));
    }

    return _Card(
      title: l.provJdLifecycle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _action(BuildContext context, String key, String label, IconData icon, VoidCallback onTap,
      {bool primary = false, bool outlined = false, bool danger = false}) {
    final cs = Theme.of(context).colorScheme;
    final busyHere = busy == key;
    final onPressed = anyBusy ? null : onTap;
    final child = busyHere
        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(icon, size: 18);
    if (outlined) {
      return OutlinedButton.icon(onPressed: onPressed, icon: child, label: Text(label));
    }
    return FilledButton.icon(
      style: danger
          ? FilledButton.styleFrom(backgroundColor: cs.errorContainer, foregroundColor: cs.onErrorContainer)
          : primary
              ? null
              : FilledButton.styleFrom(backgroundColor: cs.secondaryContainer, foregroundColor: cs.onSecondaryContainer),
      onPressed: onPressed,
      icon: child,
      label: Text(label),
    );
  }

  Widget _progress(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget row(String label, int have, int need) => Row(
          children: [
            Icon(have >= need ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16, color: have >= need ? Colors.green : Colors.orange),
            const SizedBox(width: 6),
            Text('$label  $have/$need', style: const TextStyle(fontSize: 12)),
          ],
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: counts.meetsComplete ? Colors.green.withValues(alpha: 0.10) : Colors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.provJdPhotosRequired(counts.total, kPhotosTotalRequired),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          row(l.provJdBefore, counts.before, kBeforePhotosRequired),
          row(l.provJdMid, counts.mid, kMidPhotosRequired),
          row(l.provJdAfter, counts.after, kAfterPhotosRequired),
        ],
      ),
    );
  }

  Widget _note(BuildContext context, String text) => _banner(context, text, Colors.orange, Icons.photo_camera_outlined);
  Widget _warn(BuildContext context, String text) => _banner(context, text, Colors.orange, Icons.percent);
  Widget _info(BuildContext context, String text) {
    final cs = Theme.of(context).colorScheme;
    return Text(text, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant));
  }

  Widget _settled(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
        ),
        child: Text(
          AppLocalizations.of(context).provJdSettledThanks,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );

  Widget _banner(BuildContext context, String text, Color tone, IconData icon) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: tone.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: tone),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );
}

// ── photos ───────────────────────────────────────────────────────────────────

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({required this.counts, required this.busy, required this.anyBusy, required this.onCapture});
  final PhotoCounts counts;
  final String? busy;
  final bool anyBusy;
  final void Function(PhotoSlot) onCapture;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Card(
      title: l.provJdJobPhotos,
      child: Column(
        children: [
          _slot(context, PhotoSlot.before, l.provJdBefore, counts.before, kBeforePhotosRequired),
          const SizedBox(height: 8),
          _slot(context, PhotoSlot.mid, l.provJdMid, counts.mid, kMidPhotosRequired),
          const SizedBox(height: 8),
          _slot(context, PhotoSlot.after, l.provJdAfter, counts.after, kAfterPhotosRequired),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, PhotoSlot slot, String label, int have, int need) {
    final cs = Theme.of(context).colorScheme;
    final key = 'photo_${slot.wire}';
    final busyHere = busy == key;
    return Row(
      children: [
        Icon(have >= need ? Icons.check_circle : Icons.photo_camera_outlined,
            size: 18, color: have >= need ? Colors.green : cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text('$label  $have/$need', style: const TextStyle(fontWeight: FontWeight.w600))),
        OutlinedButton.icon(
          onPressed: anyBusy ? null : () => onCapture(slot),
          icon: busyHere
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_a_photo_outlined, size: 16),
          label: Text(AppLocalizations.of(context).provJdCapture),
        ),
      ],
    );
  }
}

// ── SOS ──────────────────────────────────────────────────────────────────────

class _SosCard extends StatelessWidget {
  const _SosCard({required this.anyBusy, required this.busy, required this.onSos});
  final bool anyBusy;
  final String? busy;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Card(
      title: AppLocalizations.of(context).provJdSafety,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
          onPressed: anyBusy ? null : onSos,
          icon: busy == 'sos'
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sos),
          label: Text(AppLocalizations.of(context).provJdSendSos),
        ),
      ),
    );
  }
}

// ── live-location share ──────────────────────────────────────────────────────

class _LiveShareCard extends StatelessWidget {
  const _LiveShareCard({required this.detail});
  final ProviderJobDetail detail;

  @override
  Widget build(BuildContext context) {
    final b = detail.booking ?? const {};
    final where = [b['addressLine'], b['ward'], b['district']].map(_s).where((s) => s.isNotEmpty).join(', ');
    return _Card(
      title: AppLocalizations.of(context).provJdShareLocation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (where.isNotEmpty)
            Text(where, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          const _LiveShareToggle(),
        ],
      ),
    );
  }
}

/// Live-location sharing has no backend endpoint wired yet, so this is an honest
/// "coming soon" stub: the control is disabled and it never claims to be sharing.
class _LiveShareToggle extends StatelessWidget {
  const _LiveShareToggle();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: false,
      onChanged: null,
      title: Text(l.provJdShareLiveTitle),
      subtitle: Text(
        l.provJdShareLiveBody,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

// ── chat ─────────────────────────────────────────────────────────────────────

class _ChatCard extends StatefulWidget {
  const _ChatCard({required this.detail, required this.anyBusy, required this.busy, required this.onSend});
  final ProviderJobDetail detail;
  final bool anyBusy;
  final String? busy;
  final void Function(String) onSend;
  @override
  State<_ChatCard> createState() => _ChatCardState();
}

class _ChatCardState extends State<_ChatCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final thread = widget.detail.thread;
    return _Card(
      title: l.provJdChatTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (thread.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l.provJdChatEmpty,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: thread.length,
                itemBuilder: (context, i) => _Bubble(msg: thread[i]),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l.provJdChatHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: widget.anyBusy ? null : _submit,
                icon: widget.busy == 'message'
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg});
  final Map<String, dynamic> msg;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mine = _s(msg['fromRole']) == 'provider';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_s(msg['body']), style: TextStyle(color: mine ? cs.onPrimary : cs.onSurface)),
            const SizedBox(height: 2),
            Text(fmtJobTime(_s(msg['createdAt']).isEmpty ? null : _s(msg['createdAt'])),
                style: TextStyle(fontSize: 10, color: (mine ? cs.onPrimary : cs.onSurfaceVariant).withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}

// ── shared card shell ────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
