import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'job_detail_body.dart';
import 'native_capture.dart';
import 'provider_job_detail_data.dart';

/// `/p/jobs/:id` — the provider lifecycle hub. API-backed via
/// [providerJobDetailProvider] (A8, dark-launched → the AsyncValue loading/error
/// states cover the 503 window). Drives the full status machine —
/// pool/assigned → confirm → en-route → check-in (real GPS) → photos + face →
/// complete → awaiting-cash → cash-received (server 20% commission) → settled —
/// plus the decline / cancel / complaint / chat / SOS / live-share off-ramps.
///
/// Money is DISPLAY-ONLY: every figure comes from the payload or a mutation
/// response; the app never computes or sends an amount.
class ProviderJobDetailScreen extends ConsumerStatefulWidget {
  const ProviderJobDetailScreen({super.key, this.id});

  /// Injected in tests; in the running app it is read from the route path.
  final int? id;

  @override
  ConsumerState<ProviderJobDetailScreen> createState() => _ProviderJobDetailScreenState();
}

class _ProviderJobDetailScreenState extends ConsumerState<ProviderJobDetailScreen> {
  /// The action currently in flight (button key) — disables the panel + shows a
  /// spinner. Null when idle.
  String? _busy;

  int? _routeId(BuildContext context) {
    if (widget.id != null) return widget.id;
    try {
      return int.tryParse(GoRouterState.of(context).pathParameters['id'] ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final id = _routeId(context);
    if (id == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(tr(context, vi: 'Không tìm thấy công việc', en: 'Job not found'))),
      );
    }

    final async = ref.watch(providerJobDetailProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen(
          data: (d) => _headerTitle(d),
          orElse: () => tr(context, vi: 'Chi tiết công việc', en: 'Job detail'),
        )),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(
            message: e is ApiException && e.isMaintenance
                ? tr(context, vi: 'Tính năng đang được bật, vui lòng thử lại sau ít phút.', en: 'This feature is being enabled — please try again shortly.')
                : l.genericError,
            onRetry: () => ref.invalidate(providerJobDetailProvider(id)),
          ),
          data: (d) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(providerJobDetailProvider(id));
              await ref.read(providerJobDetailProvider(id).future);
            },
            child: JobDetailBody(
              detail: d,
              busy: _busy,
              onConfirm: () => _confirm(id),
              onDecline: () => _decline(id),
              onCancel: () => _cancel(id),
              onStartTracking: () => _startTracking(id),
              onCheckIn: () => _checkIn(id),
              onCheckOut: () => _checkOut(id),
              onCapture: (slot) => _capturePhoto(id, slot),
              onFaceVerify: () => _faceVerify(id),
              onComplete: () => _complete(id, d),
              onCashReceived: () => _cashReceived(d),
              onComplaint: () => _complaint(id),
              onSos: () => _sos(id),
              onSendMessage: (body) => _sendMessage(id, body),
            ),
          ),
        ),
      ),
    );
  }

  String _headerTitle(ProviderJobDetail d) {
    final svc = (d.service?['name'] as String?)?.trim();
    if (svc != null && svc.isNotEmpty) return svc;
    final code = d.booking?['confirmationCode'] as String?;
    return code != null && code.isNotEmpty ? code : '#${d.bookingId ?? d.jobId ?? ''}';
  }

  // ── infra ──────────────────────────────────────────────────────────────────

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Runs a `Map`-returning mutation with busy-state + refetch + error surfacing.
  Future<Map<String, dynamic>?> _runMap(
    String action,
    int id,
    Future<Map<String, dynamic>> Function(KycoApi api) call,
  ) async {
    if (_busy != null) return null;
    setState(() => _busy = action);
    final api = ref.read(kycoApiProvider);
    final generic = AppLocalizations.of(context).genericError;
    try {
      final resp = await call(api);
      if (mounted) ref.invalidate(providerJobDetailProvider(id));
      return resp;
    } on ApiException catch (e) {
      _snack(e.message);
      return null;
    } catch (_) {
      _snack(generic);
      return null;
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  // Context-free (take a captured `en` flag) so they can be used after an await
  // without tripping use_build_context_synchronously.
  static String _gpsFailureMessage(bool en, CaptureFailure f) => switch (f) {
        CaptureFailure.locationServiceOff =>
          en ? 'Turn on Location services (GPS) to check in.' : 'Vui lòng bật Dịch vụ vị trí (GPS) để check-in.',
        CaptureFailure.permissionDenied =>
          en ? 'Location permission is needed to check in on site.' : 'Ứng dụng cần quyền vị trí để check-in tại địa điểm khách.',
        CaptureFailure.permissionDeniedForever =>
          en ? 'Location permission is off — re-enable it in Settings.' : 'Quyền vị trí đã bị tắt. Hãy cấp lại trong Cài đặt.',
        _ => en ? 'Could not get your location — try again.' : 'Không lấy được vị trí, vui lòng thử lại.',
      };

  static String _cameraFailureMessage(bool en, CaptureFailure f) => switch (f) {
        CaptureFailure.cancelled => '',
        CaptureFailure.permissionDenied =>
          en ? 'Camera permission is needed to take job photos.' : 'Ứng dụng cần quyền camera để chụp ảnh công việc.',
        _ => en ? 'Photo upload failed — try again.' : 'Không tải được ảnh lên, vui lòng thử lại.',
      };

  // ── lifecycle actions ────────────────────────────────────────────────────────

  Future<void> _confirm(int id) => _runMap('confirm', id, (api) => api.confirmJob(id));

  Future<void> _decline(int id) async {
    final en = isEnglish(context);
    final reason = await _reasonDialog(
      title: tr(context, vi: 'Từ chối công việc', en: 'Decline job'),
      warning: tr(context,
          vi: 'Từ chối sau khi đã nhận có thể bị tính phí phạt và ảnh hưởng điểm uy tín. Kyco sẽ hiển thị mức phí (nếu có) sau khi xác nhận.',
          en: 'Declining after accepting may incur a fine and affect your reliability score. Kyco shows the fine (if any) after you confirm.'),
      hint: tr(context, vi: 'Lý do (không bắt buộc)', en: 'Reason (optional)'),
      confirmLabel: tr(context, vi: 'Từ chối', en: 'Decline'),
    );
    if (reason == null) return; // dismissed
    final resp = await _runMap('decline', id, (api) => api.declineJob(id, reason: reason.isEmpty ? null : reason));
    if (resp != null) _showFineOutcome(en, resp, en ? 'Job declined' : 'Đã từ chối công việc');
  }

  Future<void> _cancel(int id) async {
    final en = isEnglish(context);
    final reason = await _reasonDialog(
      title: tr(context, vi: 'Huỷ công việc', en: 'Cancel job'),
      warning: tr(context,
          vi: 'Huỷ đơn đã nhận có thể phát sinh phí phạt theo chính sách. Mức phí do Kyco tính và hiển thị sau khi xác nhận.',
          en: 'Cancelling an accepted job may incur a policy fine. Kyco computes and shows the amount after you confirm.'),
      hint: tr(context, vi: 'Lý do huỷ', en: 'Cancellation reason'),
      confirmLabel: tr(context, vi: 'Huỷ đơn', en: 'Cancel job'),
    );
    if (reason == null) return;
    final resp = await _runMap('cancel', id,
        (api) => api.cancelJob(id, reasonCode: 'other', reasonText: reason.isEmpty ? null : reason));
    if (resp != null) _showFineOutcome(en, resp, en ? 'Job cancelled' : 'Đã huỷ công việc');
  }

  Future<void> _startTracking(int id) async {
    if (_busy != null) return;
    final en = isEnglish(context);
    final generic = AppLocalizations.of(context).genericError;
    // Prove location access up front so "en route" reflects a real permission.
    final gps = await const LocationService().currentPosition();
    if (!gps.isOk) {
      _snack(_gpsFailureMessage(en, gps.failure!));
      return;
    }
    setState(() => _busy = 'start');
    final api = ref.read(kycoApiProvider);
    try {
      await api.startTracking(id);
      if (mounted) ref.invalidate(providerJobDetailProvider(id));
      _snack(en ? 'You are now en route' : 'Đã bắt đầu di chuyển đến khách');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(generic);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _checkIn(int id) async {
    if (_busy != null) return;
    final en = isEnglish(context);
    final generic = AppLocalizations.of(context).genericError;
    final gps = await const LocationService().currentPosition();
    if (!gps.isOk) {
      _snack(_gpsFailureMessage(en, gps.failure!));
      return;
    }
    setState(() => _busy = 'checkin');
    final api = ref.read(kycoApiProvider);
    try {
      final r = await api.checkIn(id, lat: gps.fix!.lat, lon: gps.fix!.lon, accuracyM: gps.fix!.accuracyM);
      if (mounted) ref.invalidate(providerJobDetailProvider(id));
      _showCheckInOutcome(en, r);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(generic);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _checkOut(int id) async {
    if (_busy != null) return;
    final en = isEnglish(context);
    final generic = AppLocalizations.of(context).genericError;
    final gps = await const LocationService().currentPosition();
    if (!gps.isOk) {
      _snack(_gpsFailureMessage(en, gps.failure!));
      return;
    }
    setState(() => _busy = 'checkout');
    final api = ref.read(kycoApiProvider);
    try {
      // NOTE: check-out's body key is `lng` (asymmetric with check-in's `lon`).
      await api.checkOut(id, lat: gps.fix!.lat, lng: gps.fix!.lon, accuracyM: gps.fix!.accuracyM);
      if (mounted) ref.invalidate(providerJobDetailProvider(id));
      _snack(en
          ? 'Checked out. The booking moved to customer confirmation & payment.'
          : 'Đã check-out. Đơn được chuyển sang chờ khách xác nhận & thanh toán.');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(generic);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _capturePhoto(int id, PhotoSlot slot) async {
    if (_busy != null) return;
    final en = isEnglish(context);
    final generic = AppLocalizations.of(context).genericError;
    setState(() => _busy = 'photo_${slot.wire}');
    final api = ref.read(kycoApiProvider);
    try {
      final up = await PhotoCaptureService(api).captureAndUpload(purpose: 'job_photo');
      if (!up.isOk) {
        final msg = _cameraFailureMessage(en, up.failure!);
        if (msg.isNotEmpty) _snack(msg);
        return;
      }
      await api.uploadJobPhotos(id, slot: slot.wire, mediaIds: [up.mediaId!]);
      if (mounted) ref.invalidate(providerJobDetailProvider(id));
      _snack(en ? 'Photo uploaded' : 'Đã tải ảnh lên');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(generic);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _faceVerify(int id) async {
    final en = isEnglish(context);
    final resp = await _runMap('face', id, (api) => api.faceVerify(id));
    if (resp != null) {
      _snack(en ? 'Face verification submitted' : 'Đã gửi xác minh khuôn mặt');
    }
  }

  Future<void> _complete(int id, ProviderJobDetail d) async {
    final en = isEnglish(context);
    final counts = PhotoCounts.ofJob(d.job);
    final ok = await _completeGateDialog(counts);
    if (ok != true) return;
    final resp = await _runMap('complete', id, (api) => api.completeJob(id));
    if (resp != null) {
      _snack(en ? 'Job marked complete' : 'Đã báo hoàn thành công việc');
    }
  }

  Future<void> _cashReceived(ProviderJobDetail d) async {
    final bookingId = d.bookingId;
    if (bookingId == null) return;
    final ok = await _confirmDialog(
      title: tr(context, vi: 'Xác nhận đã nhận tiền mặt', en: 'Confirm cash received'),
      body: tr(context,
          vi: 'Kyco sẽ thu hoa hồng 20% cho đơn tiền mặt này. Xác nhận bạn đã nhận đủ tiền từ khách?',
          en: 'Kyco charges a 20% commission on this cash order. Confirm you received the full amount from the customer?'),
      confirmLabel: tr(context, vi: 'Đã nhận tiền', en: 'Cash received'),
    );
    if (ok != true) return;
    // Money is server-derived: cashReceived charges the 20% commission and
    // returns the computed figures — we DISPLAY them, never compute.
    final resp = await _runMap('cash', d.jobId ?? bookingId, (api) => api.cashReceived(bookingId));
    if (resp != null && mounted) _showCashOutcome(resp);
  }

  Future<void> _complaint(int id) async {
    final en = isEnglish(context);
    final reason = await _reasonDialog(
      title: tr(context, vi: 'Gửi khiếu nại', en: 'File a complaint'),
      warning: tr(context,
          vi: 'Mô tả sự cố với đơn này. Đội hỗ trợ Kyco sẽ xem xét.',
          en: 'Describe the problem with this job. Kyco support will review it.'),
      hint: tr(context, vi: 'Nội dung khiếu nại', en: 'What happened'),
      confirmLabel: tr(context, vi: 'Gửi', en: 'Send'),
    );
    if (reason == null) return;
    final resp = await _runMap('complaint', id,
        (api) => api.fileJobComplaint(id, category: 'other', description: reason.isEmpty ? null : reason));
    if (resp != null) _snack(en ? 'Complaint sent' : 'Đã gửi khiếu nại');
  }

  Future<void> _sos(int id) async {
    final en = isEnglish(context);
    final ok = await _confirmDialog(
      title: '🆘 SOS',
      body: tr(context,
          vi: 'Gửi cảnh báo khẩn cấp tới Kyco cho công việc này? Đội an toàn sẽ liên hệ ngay.',
          en: 'Send an emergency alert to Kyco for this job? The safety team will contact you immediately.'),
      confirmLabel: tr(context, vi: 'Gửi SOS', en: 'Send SOS'),
      danger: true,
    );
    if (ok != true) return;
    final resp = await _runMap('sos', id,
        (api) => api.fileJobComplaint(id, category: 'sos', description: 'SOS from provider app'));
    if (resp != null) {
      _snack(en ? 'SOS sent. Kyco safety will contact you now.' : 'Đã gửi SOS. Đội an toàn Kyco sẽ liên hệ ngay.');
    }
  }

  Future<void> _sendMessage(int id, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _runMap('message', id, (api) => api.sendJobMessage(id, text));
  }

  // ── outcome surfaces ─────────────────────────────────────────────────────────

  void _showCheckInOutcome(bool en, CheckInResult r) {
    final parts = <String>[en ? 'Checked in' : 'Đã check-in'];
    if (r.geofenceWithin) {
      parts.add(en ? 'within site geofence' : 'trong phạm vi địa điểm');
    } else if (r.distanceM != null) {
      final m = r.distanceM!.round();
      parts.add(en ? '~${m}m away' : 'cách ~${m}m');
    }
    if (r.lateMinutes > 0) {
      parts.add(en ? '${r.lateMinutes} min late' : 'trễ ${r.lateMinutes} phút');
    }
    _snack(parts.join(' · '));
    // A server-computed late fine is money → show it, never compute it.
    if (r.lateFine.fine > 0) {
      _showInfoDialog(
        title: en ? 'Late fine' : 'Phí trễ giờ',
        body: en
            ? 'Kyco recorded a late fine: ${formatVnd(r.lateFine.fine)}. This amount is system-computed.'
            : 'Kyco ghi nhận phí trễ giờ: ${formatVnd(r.lateFine.fine)}. Số tiền do hệ thống tính.',
      );
    }
  }

  void _showFineOutcome(bool en, Map<String, dynamic> resp, String successMsg) {
    final money = serverMoneyFields(resp);
    final fine = money['fineVnd'] ?? money['penaltyVnd'];
    if (fine != null && fine > 0) {
      _showInfoDialog(
        title: en ? 'Fine applied' : 'Phí phạt',
        body: en
            ? 'Kyco applied a fine: ${formatVnd(fine)}. This amount is system-computed and final.'
            : 'Kyco áp dụng phí phạt: ${formatVnd(fine)}. Số tiền do hệ thống tính, không thể thay đổi.',
      );
    } else {
      _snack(successMsg);
    }
  }

  void _showCashOutcome(Map<String, dynamic> resp) {
    final money = serverMoneyFields(resp);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final en = isEnglish(ctx);
        return AlertDialog(
          title: Text(tr(ctx, vi: 'Đã ghi nhận tiền mặt', en: 'Cash recorded')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(ctx,
                  vi: 'Kyco đã tính hoa hồng 20% cho đơn này. Số liệu dưới đây do hệ thống tính:',
                  en: 'Kyco charged the 20% commission on this order. The figures below are system-computed:')),
              const SizedBox(height: 12),
              if (money.isEmpty)
                Text(tr(ctx, vi: 'Xem ví để biết chi tiết.', en: 'See your wallet for details.'))
              else
                for (final e in money.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(moneyFieldLabel(e.key, en: en)),
                        Text(formatVnd(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr(ctx, vi: 'Đóng', en: 'Close')),
            ),
          ],
        );
      },
    );
  }

  void _showInfoDialog({required String title, required String body}) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(tr(ctx, vi: 'Đóng', en: 'Close')),
          ),
        ],
      ),
    );
  }

  // ── dialogs ──────────────────────────────────────────────────────────────────

  Future<bool?> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    bool danger = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr(ctx, vi: 'Đóng', en: 'Cancel')),
            ),
            FilledButton(
              style: danger ? FilledButton.styleFrom(backgroundColor: cs.error) : null,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  /// Reason-collecting dialog. Returns the (possibly empty) text on confirm, or
  /// null if dismissed. The warning line carries the policy/fine caveat.
  Future<String?> _reasonDialog({
    required String title,
    required String warning,
    required String hint,
    required String confirmLabel,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(warning, style: TextStyle(fontSize: 12, color: cs.onSurface)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr(ctx, vi: 'Đóng', en: 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  /// Photo-gated complete dialog: shows the per-slot deficit and only enables the
  /// confirm button when the quota is met (server re-enforces regardless).
  Future<bool?> _completeGateDialog(PhotoCounts counts) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final en = isEnglish(ctx);
        Widget line(String label, int have, int need, int missing) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(have >= need ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16, color: have >= need ? Colors.green : Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$label  $have/$need')),
                  if (missing > 0)
                    Text(en ? 'need $missing more' : 'còn thiếu $missing',
                        style: const TextStyle(fontSize: 12, color: Colors.orange)),
                ],
              ),
            );
        return AlertDialog(
          title: Text(tr(ctx, vi: 'Hoàn thành công việc', en: 'Complete job')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(ctx,
                  vi: 'Cần đủ ảnh trước/giữa/sau ca mới được báo hoàn thành:',
                  en: 'Enough before/mid/after photos are required to complete:')),
              const SizedBox(height: 10),
              line(tr(ctx, vi: 'Trước ca', en: 'Before'), counts.before, kBeforePhotosRequired, counts.missingBefore),
              line(tr(ctx, vi: 'Giữa ca', en: 'Mid'), counts.mid, kMidPhotosRequired, counts.missingMid),
              line(tr(ctx, vi: 'Sau ca', en: 'After'), counts.after, kAfterPhotosRequired, counts.missingAfter),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr(ctx, vi: 'Đóng', en: 'Cancel')),
            ),
            FilledButton(
              onPressed: counts.meetsComplete ? () => Navigator.of(ctx).pop(true) : null,
              child: Text(tr(ctx, vi: 'Báo hoàn thành', en: 'Mark complete')),
            ),
          ],
        );
      },
    );
  }
}
