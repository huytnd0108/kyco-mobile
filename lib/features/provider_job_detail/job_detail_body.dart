import 'package:flutter/material.dart';

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
            label: Text(tr(context, vi: 'Gửi khiếu nại về đơn này', en: 'Report a problem with this job')),
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
    final (label, icon, tone) = switch (phase) {
      JobPhase.pending => (tr(context, vi: 'Chờ bạn xác nhận', en: 'Awaiting your confirmation'), Icons.hourglass_top, cs.tertiary),
      JobPhase.enRoute => (tr(context, vi: 'Chuẩn bị di chuyển', en: 'Ready to head out'), Icons.directions_car, cs.primary),
      JobPhase.onSite => (tr(context, vi: 'Đang làm việc tại địa điểm', en: 'On site — in service'), Icons.cleaning_services, cs.primary),
      JobPhase.wrapUp => (tr(context, vi: 'Hoàn tất & báo xong', en: 'Wrap up & mark complete'), Icons.task_alt, cs.primary),
      JobPhase.awaitingCustomer => (tr(context, vi: 'Chờ khách xác nhận (tự động sau 2h)', en: 'Awaiting customer confirmation (auto in 2h)'), Icons.schedule, cs.tertiary),
      JobPhase.awaitingCash => (tr(context, vi: 'Chờ xác nhận tiền mặt', en: 'Awaiting cash confirmation'), Icons.payments, cs.tertiary),
      JobPhase.awaitingPayment => (tr(context, vi: 'Khách đang thanh toán', en: 'Customer is paying'), Icons.account_balance, cs.tertiary),
      JobPhase.settled => (tr(context, vi: 'Đã tất toán', en: 'Settled'), Icons.verified, Colors.green),
      JobPhase.closed => (tr(context, vi: 'Đã đóng', en: 'Closed'), Icons.lock_outline, cs.onSurfaceVariant),
      JobPhase.cancelled => (tr(context, vi: 'Đã huỷ', en: 'Cancelled'), Icons.cancel_outlined, cs.error),
      JobPhase.unknown => (tr(context, vi: 'Trạng thái công việc', en: 'Job status'), Icons.info_outline, cs.onSurfaceVariant),
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
    return _Card(
      title: tr(context, vi: 'Thông tin đơn', en: 'Order info'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(context, tr(context, vi: 'Khách hàng', en: 'Customer'), _s(cust['name']).isEmpty ? '—' : _s(cust['name'])),
          _kv(context, 'Email', _s(cust['email']).isEmpty ? '—' : _s(cust['email'])),
          _kv(context, tr(context, vi: 'Thời gian', en: 'Time'), fmtJobTime(_s(b['scheduledAt']).isEmpty ? null : _s(b['scheduledAt']))),
          _kv(context, tr(context, vi: 'Thời lượng', en: 'Duration'),
              duration == null ? '—' : tr(context, vi: '$duration phút', en: '$duration min')),
          _kv(context, tr(context, vi: 'Địa chỉ', en: 'Address'), where.isEmpty ? '—' : where),
          if (_s(b['notes']).isNotEmpty)
            _kv(context, tr(context, vi: 'Ghi chú', en: 'Notes'), _s(b['notes'])),
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
    final method = _payLabel(context, _s(b['paymentMethod']));
    return _Card(
      title: tr(context, vi: 'Thanh toán', en: 'Payment'),
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
                Text(tr(context, vi: 'Thu nhập của bạn', en: 'Your earnings')),
                Text(formatVnd(earnings.toInt()), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Text(
            tr(context,
                vi: 'Số tiền do Kyco tính và hiển thị — ứng dụng không tự tính.',
                en: 'Amounts are computed and shown by Kyco — the app never calculates them.'),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  String _payLabel(BuildContext context, String m) => switch (m) {
        'cash' => tr(context, vi: 'Tiền mặt', en: 'Cash'),
        'vnpay' => 'VNPay',
        'momo' => 'MoMo',
        'zalopay' => 'ZaloPay',
        'bank_transfer' => tr(context, vi: 'Chuyển khoản', en: 'Bank transfer'),
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
    final children = <Widget>[];

    switch (phase) {
      case JobPhase.pending:
        children.add(_action(context, 'confirm', tr(context, vi: 'Xác nhận & nhận việc', en: 'Confirm & accept'), Icons.check, onConfirm, primary: true));
        children.add(_action(context, 'decline', tr(context, vi: 'Từ chối', en: 'Decline'), Icons.close, onDecline, outlined: true));
        children.add(_action(context, 'cancel', tr(context, vi: 'Huỷ công việc', en: 'Cancel job'), Icons.cancel_outlined, onCancel, danger: true));
      case JobPhase.enRoute:
        children.add(_action(context, 'start', tr(context, vi: 'Bắt đầu di chuyển (dùng GPS)', en: 'Start heading out (GPS)'), Icons.directions_car, onStartTracking, primary: true));
        children.add(_action(context, 'checkin', tr(context, vi: 'Check-in tại địa điểm (GPS)', en: 'Check in on site (GPS)'), Icons.my_location, onCheckIn, primary: true));
        children.add(_action(context, 'cancel', tr(context, vi: 'Huỷ công việc', en: 'Cancel job'), Icons.cancel_outlined, onCancel, danger: true));
      case JobPhase.onSite:
        if (!counts.meetsCheckout) {
          children.add(_note(context,
              tr(context,
                  vi: 'Cần ≥ $kBeforePhotosRequired ảnh "trước ca" mới được check-out (hiện ${counts.before}/$kBeforePhotosRequired). Chụp ở khung ảnh bên dưới.',
                  en: 'Need ≥ $kBeforePhotosRequired "before" photos to check out (have ${counts.before}/$kBeforePhotosRequired). Capture in the photo box below.')));
        }
        children.add(_action(context, 'face', tr(context, vi: 'Xác minh khuôn mặt', en: 'Face verify'), Icons.face_retouching_natural, onFaceVerify, outlined: true));
        children.add(_action(context, 'checkout', tr(context, vi: 'Check-out (GPS)', en: 'Check out (GPS)'), Icons.logout, onCheckOut, primary: true));
      case JobPhase.wrapUp:
        children.add(_progress(context));
        children.add(_action(context, 'complete', tr(context, vi: 'Báo hoàn thành', en: 'Mark complete'), Icons.task_alt, onComplete, primary: true));
      case JobPhase.awaitingCash:
        if (_s(detail.booking?['paymentMethod']) == 'cash') {
          children.add(_action(context, 'cash', tr(context, vi: '✅ Đã nhận tiền mặt từ khách', en: '✅ Cash received from customer'), Icons.payments, onCashReceived, primary: true));
          children.add(_warn(context,
              tr(context,
                  vi: 'Kyco sẽ thu hoa hồng 20% cho đơn tiền mặt này (số tiền do hệ thống tính).',
                  en: 'Kyco charges a 20% commission on this cash order (system-computed).')));
        }
      case JobPhase.awaitingCustomer:
        children.add(_info(context, tr(context, vi: '⏳ Chờ khách xác nhận hoàn thành (tự động sau 2h).', en: '⏳ Awaiting customer confirmation (auto-confirms in 2h).')));
      case JobPhase.awaitingPayment:
        children.add(_info(context, tr(context, vi: '⏳ Khách đang thanh toán — Kyco sẽ chuyển 80% khi xác nhận.', en: '⏳ Customer is paying — Kyco transfers 80% on confirmation.')));
      case JobPhase.settled:
        children.add(_settled(context));
      case JobPhase.closed:
        children.add(_info(context, tr(context, vi: '🔒 Công việc đã đóng. Không còn hành động nào.', en: '🔒 This job is closed. No further actions.')));
      case JobPhase.cancelled:
        children.add(_info(context, tr(context, vi: 'Công việc đã huỷ.', en: 'This job was cancelled.')));
      case JobPhase.unknown:
        children.add(_info(context, tr(context, vi: 'Không có hành động khả dụng.', en: 'No actions available.')));
    }

    return _Card(
      title: tr(context, vi: 'Vòng đời công việc', en: 'Job lifecycle'),
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
          Text(tr(context, vi: 'Ảnh cần để hoàn thành (${counts.total}/$kPhotosTotalRequired)', en: 'Photos required to complete (${counts.total}/$kPhotosTotalRequired)'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          row(tr(context, vi: 'Trước ca', en: 'Before'), counts.before, kBeforePhotosRequired),
          row(tr(context, vi: 'Giữa ca', en: 'Mid'), counts.mid, kMidPhotosRequired),
          row(tr(context, vi: 'Sau ca', en: 'After'), counts.after, kAfterPhotosRequired),
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
          tr(context,
              vi: '✅ Kyco đã thanh toán cho bạn 80% giá trị đơn hàng, cảm ơn bạn đã đồng hành!',
              en: '✅ Kyco has paid you 80% of the booking total. Thank you for working with us!'),
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
    return _Card(
      title: tr(context, vi: 'Ảnh công việc (camera)', en: 'Job photos (camera)'),
      child: Column(
        children: [
          _slot(context, PhotoSlot.before, tr(context, vi: 'Trước ca', en: 'Before'), counts.before, kBeforePhotosRequired),
          const SizedBox(height: 8),
          _slot(context, PhotoSlot.mid, tr(context, vi: 'Giữa ca', en: 'Mid'), counts.mid, kMidPhotosRequired),
          const SizedBox(height: 8),
          _slot(context, PhotoSlot.after, tr(context, vi: 'Sau ca', en: 'After'), counts.after, kAfterPhotosRequired),
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
          label: Text(tr(context, vi: 'Chụp', en: 'Capture')),
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
      title: tr(context, vi: 'An toàn', en: 'Safety'),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
          onPressed: anyBusy ? null : onSos,
          icon: busy == 'sos'
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sos),
          label: Text(tr(context, vi: 'Gửi SOS khẩn cấp', en: 'Send emergency SOS')),
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
      title: tr(context, vi: '📍 Chia sẻ vị trí với khách', en: '📍 Share location with the customer'),
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
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: false,
      onChanged: null,
      title: Text(tr(context, vi: 'Chia sẻ vị trí trực tiếp — sắp ra mắt', en: 'Share my live location — coming soon')),
      subtitle: Text(
        tr(context,
            vi: 'Tính năng đang được phát triển. Khách chưa thể xem vị trí của bạn.',
            en: 'This feature is in development. The customer cannot see your location yet.'),
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
    final thread = widget.detail.thread;
    return _Card(
      title: tr(context, vi: 'Trò chuyện với khách', en: 'Chat with the customer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (thread.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(tr(context, vi: 'Chưa có tin nhắn nào.', en: 'No messages yet.'),
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
                    hintText: tr(context, vi: 'Nhập tin nhắn…', en: 'Type a message…'),
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
