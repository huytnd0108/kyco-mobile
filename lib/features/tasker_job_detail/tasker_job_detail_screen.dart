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
import '../tasker_home/tasker_home_providers.dart';
import '../tasker_jobs/tasker_jobs_providers.dart';
import '../tasker_wallet/tasker_wallet_providers.dart';
import 'job_detail_body.dart';
import 'native_capture.dart';
import 'tasker_job_detail_data.dart';

/// `/p/jobs/:id` — the tasker lifecycle hub. API-backed via
/// [taskerJobDetailProvider] (A8, dark-launched → the AsyncValue loading/error
/// states cover the 503 window). Drives the full status machine —
/// pool/assigned → confirm → en-route → check-in (real GPS) → photos + face →
/// complete → awaiting-cash → cash-received (server 20% commission) → settled —
/// plus the decline / cancel / complaint / chat / SOS / live-share off-ramps.
///
/// Money is DISPLAY-ONLY: every figure comes from the payload or a mutation
/// response; the app never computes or sends an amount.
class TaskerJobDetailScreen extends ConsumerStatefulWidget {
  const TaskerJobDetailScreen({super.key, this.id});

  /// Injected in tests; in the running app it is read from the route path.
  final int? id;

  @override
  ConsumerState<TaskerJobDetailScreen> createState() => _TaskerJobDetailScreenState();
}

class _TaskerJobDetailScreenState extends ConsumerState<TaskerJobDetailScreen> {
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
        body: Center(child: Text(l.provJdNotFound)),
      );
    }

    final async = ref.watch(taskerJobDetailProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: Text(async.maybeWhen(
          data: (d) => _headerTitle(d),
          orElse: () => l.provJdTitle,
        )),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorRetry(
            message: e is ApiException && e.isMaintenance
                ? l.provJdFeatureEnabling
                : l.genericError,
            onRetry: () => ref.invalidate(taskerJobDetailProvider(id)),
          ),
          data: (d) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(taskerJobDetailProvider(id));
              try { await ref.read(taskerJobDetailProvider(id).future); } catch (_) {/* offline pull — UI recovers via .when(error:) */}
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
              onCapture: (slot) => _capturePhoto(id, slot, d.bookingId),
              onFaceVerify: () => _faceVerify(id),
              onComplete: () => _complete(id, d),
              onCashReceived: () => _cashReceived(id, d),
              onComplaint: () => _complaint(id),
              onSos: () => _sos(id),
              onSendMessage: (body) => _sendMessage(id, body),
              onResubmit: () => _resubmit(id, d),
              onLivePing: () => _livePing(id),
            ),
          ),
        ),
      ),
    );
  }

  String _headerTitle(TaskerJobDetail d) {
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

  /// Every job mutation changes what the tab shells show (they stay mounted):
  /// the assigned list, the home workspace pipeline and the claimable pool all
  /// carry this job, so refresh them alongside the detail. [wallet] is set ONLY
  /// after cash-received — it re-reads the server ledger (a refresh, no money is
  /// computed or moved client-side).
  void _refreshAfterMutation(int id, {bool wallet = false}) {
    if (!mounted) return;
    ref.invalidate(taskerJobDetailProvider(id));
    ref.invalidate(assignedJobsControllerProvider);
    ref.invalidate(taskerWorkspaceProvider);
    ref.invalidate(poolProvider);
    if (wallet) {
      ref.invalidate(walletSummaryProvider);
      ref.invalidate(walletTxnsControllerProvider);
    }
  }

  /// Runs a `Map`-returning mutation with busy-state + refetch + error surfacing.
  Future<Map<String, dynamic>?> _runMap(
    String action,
    int id,
    Future<Map<String, dynamic>> Function(KycoApi api) call, {
    bool refreshWallet = false,
  }) async {
    if (_busy != null) return null;
    setState(() => _busy = action);
    final api = ref.read(kycoApiProvider);
    final generic = AppLocalizations.of(context).genericError;
    try {
      final resp = await call(api);
      _refreshAfterMutation(id, wallet: refreshWallet);
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

  // Take a captured localizations handle (resolved before the await) so they can
  // be used after an await without tripping use_build_context_synchronously.
  static String _gpsFailureMessage(AppLocalizations l, CaptureFailure f) => switch (f) {
        CaptureFailure.locationServiceOff => l.provJdGpsOff,
        CaptureFailure.permissionDenied => l.provJdGpsPermNeeded,
        CaptureFailure.permissionDeniedForever => l.provJdGpsPermOff,
        _ => l.provJdGpsFailed,
      };

  static String _cameraFailureMessage(AppLocalizations l, CaptureFailure f) => switch (f) {
        CaptureFailure.cancelled => '',
        CaptureFailure.permissionDenied => l.provJdCamPermNeeded,
        _ => l.provJdPhotoUploadFailed,
      };

  // ── lifecycle actions ────────────────────────────────────────────────────────

  Future<void> _confirm(int id) => _runMap('confirm', id, (api) => api.confirmJob(id));

  Future<void> _decline(int id) async {
    final l = AppLocalizations.of(context);
    final reason = await _reasonDialog(
      title: l.provJdDeclineTitle,
      warning: l.provJdDeclineWarning,
      hint: l.provJdReasonOptional,
      confirmLabel: l.provJdDecline,
    );
    if (reason == null) return; // dismissed
    final resp = await _runMap('decline', id, (api) => api.declineJob(id, reason: reason.isEmpty ? null : reason));
    if (resp != null) _showFineOutcome(l, resp, l.provJdDeclined);
  }

  Future<void> _cancel(int id) async {
    final l = AppLocalizations.of(context);
    final reason = await _reasonDialog(
      title: l.provJdCancelTitle,
      warning: l.provJdCancelWarning,
      hint: l.provJdCancelReason,
      confirmLabel: l.provJdCancelJob,
    );
    if (reason == null) return;
    final resp = await _runMap('cancel', id,
        (api) => api.cancelJob(id, reasonCode: 'other', reasonText: reason.isEmpty ? null : reason));
    if (resp != null) _showFineOutcome(l, resp, l.provJdCancelled);
  }

  Future<void> _startTracking(int id) async {
    if (_busy != null) return;
    final l = AppLocalizations.of(context);
    // Prove location access up front so "en route" reflects a real permission.
    final gps = await const LocationService().currentPosition();
    if (!mounted) return; // GPS can take 10-30s; the screen may be gone.
    if (!gps.isOk) {
      _snack(_gpsFailureMessage(l, gps.failure!));
      return;
    }
    setState(() => _busy = 'start');
    final api = ref.read(kycoApiProvider);
    try {
      await api.startTracking(id);
      _refreshAfterMutation(id);
      _snack(l.provJdEnRouteSnack);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(l.genericError);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _checkIn(int id) async {
    if (_busy != null) return;
    final l = AppLocalizations.of(context);
    final gps = await const LocationService().currentPosition();
    if (!mounted) return; // GPS can take 10-30s; the screen may be gone.
    if (!gps.isOk) {
      _snack(_gpsFailureMessage(l, gps.failure!));
      return;
    }
    setState(() => _busy = 'checkin');
    final api = ref.read(kycoApiProvider);
    try {
      final r = await api.checkIn(id, lat: gps.fix!.lat, lon: gps.fix!.lon, accuracyM: gps.fix!.accuracyM);
      _refreshAfterMutation(id);
      _showCheckInOutcome(l, r);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(l.genericError);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _checkOut(int id) async {
    if (_busy != null) return;
    final l = AppLocalizations.of(context);
    final gps = await const LocationService().currentPosition();
    if (!mounted) return; // GPS can take 10-30s; the screen may be gone.
    if (!gps.isOk) {
      _snack(_gpsFailureMessage(l, gps.failure!));
      return;
    }
    setState(() => _busy = 'checkout');
    final api = ref.read(kycoApiProvider);
    try {
      // NOTE: check-out's body key is `lng` (asymmetric with check-in's `lon`).
      await api.checkOut(id, lat: gps.fix!.lat, lng: gps.fix!.lon, accuracyM: gps.fix!.accuracyM);
      _refreshAfterMutation(id);
      _snack(l.provJdCheckedOutSnack);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(l.genericError);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _capturePhoto(int id, PhotoSlot slot, int? bookingId) async {
    if (_busy != null) return;
    final l = AppLocalizations.of(context);
    // Job photos are stored against the BOOKING (canUpload checks the caller
    // is its assigned tasker) — without it the upload can't be addressed.
    if (bookingId == null) {
      _snack(l.provJdPhotoUploadFailed);
      return;
    }
    setState(() => _busy = 'photo_${slot.wire}');
    final api = ref.read(kycoApiProvider);
    try {
      final up = await PhotoCaptureService(api)
          .captureAndUpload(bookingId: bookingId, slotWire: slot.wire);
      if (!up.isOk) {
        final msg = _cameraFailureMessage(l, up.failure!);
        if (msg.isNotEmpty) _snack(msg);
        return;
      }
      await api.uploadJobPhotos(id, slot: slot.wire, mediaIds: [up.mediaId!]);
      _refreshAfterMutation(id);
      _snack(l.provJdPhotoUploaded);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(l.genericError);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _faceVerify(int id) async {
    final l = AppLocalizations.of(context);
    final resp = await _runMap('face', id, (api) => api.faceVerify(id));
    if (resp != null) {
      _snack(l.provJdFaceSubmitted);
    }
  }

  Future<void> _complete(int id, TaskerJobDetail d) async {
    final l = AppLocalizations.of(context);
    final counts = PhotoCounts.ofJob(d.job);
    final ok = await _completeGateDialog(counts);
    if (ok != true) return;
    final resp = await _runMap('complete', id, (api) => api.completeJob(id));
    if (resp != null) {
      _snack(l.provJdMarkedComplete);
    }
  }

  Future<void> _cashReceived(int id, TaskerJobDetail d) async {
    final bookingId = d.bookingId;
    if (bookingId == null) return;
    final l = AppLocalizations.of(context);
    final ok = await _confirmDialog(
      title: l.provJdCashConfirmTitle,
      body: l.provJdCashConfirmBody,
      confirmLabel: l.provJdCashReceived,
    );
    if (ok != true) return;
    // Money is server-derived: cashReceived charges the 20% commission and
    // returns the computed figures — we DISPLAY them, never compute.
    // Invalidate the SAME family key the screen watches (the route id) so the
    // post-cash refresh hits this instance, not a stale jobId-keyed one.
    final resp = await _runMap('cash', id, (api) => api.cashReceived(bookingId),
        refreshWallet: true);
    if (resp != null && mounted) _showCashOutcome(resp);
  }

  Future<void> _resubmit(int id, TaskerJobDetail d) async {
    final bookingId = d.bookingId;
    if (bookingId == null) return;
    final l = AppLocalizations.of(context);
    final resp = await _runMap('resubmit', id, (api) => api.resubmitCompletion(bookingId));
    if (resp != null) _snack(l.prov2ResubmitDone);
  }

  /// One opt-in live-location ping (job_detail_body's LiveShareToggle drives the
  /// cadence). Real GPS only — a failed fix or a refused POST returns false so
  /// the toggle switches itself off, with the reason surfaced once.
  Future<bool> _livePing(int id) async {
    final l = AppLocalizations.of(context);
    final gps = await const LocationService().currentPosition();
    if (!mounted) return false;
    if (!gps.isOk) {
      _snack(_gpsFailureMessage(l, gps.failure!));
      return false;
    }
    try {
      await ref.read(kycoApiProvider).pingJobLocation(id,
          lat: gps.fix!.lat, lng: gps.fix!.lon, accuracy: gps.fix!.accuracyM);
      return true;
    } on ApiException catch (e) {
      _snack(e.message.isEmpty ? l.prov2LiveShareStopped : e.message);
      return false;
    } catch (_) {
      _snack(l.prov2LiveShareStopped);
      return false;
    }
  }

  Future<void> _complaint(int id) async {
    final l = AppLocalizations.of(context);
    final reason = await _reasonDialog(
      title: l.provJdComplaintTitle,
      warning: l.provJdComplaintBody,
      hint: l.provJdComplaintHint,
      confirmLabel: l.provJdSend,
    );
    if (reason == null) return;
    // The server requires a description (422 `description:required`).
    // Server rule (376db7f): description required, ≥ 20 characters.
    if (reason.trim().length < 20) {
      _snack(l.prov2ComplaintNeedsText);
      return;
    }
    final resp = await _runMap('complaint', id,
        (api) => api.fileJobComplaint(id, category: 'other', description: reason.trim()));
    if (resp != null) _snack(l.provJdComplaintSent);
  }

  Future<void> _sos(int id) async {
    final l = AppLocalizations.of(context);
    final ok = await _confirmDialog(
      title: '🆘 SOS',
      body: l.provJdSosBody,
      confirmLabel: l.provJdSosConfirm,
      danger: true,
    );
    if (ok != true) return;
    // Best-effort location: never let a slow/denied GPS delay the alert.
    GpsFix? fix;
    try {
      final gps = await const LocationService()
          .currentPosition()
          .timeout(const Duration(seconds: 8));
      fix = gps.fix;
    } catch (_) {}
    if (!mounted) return;
    final resp = await _runMap('sos', id,
        (api) => api.triggerSos(
              jobId: id,
              lat: fix?.lat,
              lng: fix?.lon,
              accuracyM: fix?.accuracyM,
              note: 'SOS from the Kyco tasker app',
            ));
    if (resp != null) {
      _snack(l.provJdSosSent);
    }
  }

  Future<void> _sendMessage(int id, String body) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await _runMap('message', id, (api) => api.sendJobMessage(id, text));
  }

  // ── outcome surfaces ─────────────────────────────────────────────────────────

  void _showCheckInOutcome(AppLocalizations l, CheckInResult r) {
    final parts = <String>[l.provJdCheckedIn];
    if (r.geofenceWithin) {
      parts.add(l.provJdWithinGeofence);
    } else if (r.distanceM != null) {
      final m = r.distanceM!.round();
      parts.add(l.provJdMetersAway(m));
    }
    if (r.lateMinutes > 0) {
      parts.add(l.provJdMinLate(r.lateMinutes));
    }
    _snack(parts.join(' · '));
    // A server-computed late fine is money → show it, never compute it.
    if (r.lateFine.fine > 0) {
      _showInfoDialog(
        title: l.provJdLateFineTitle,
        body: l.provJdLateFineBody(formatVnd(r.lateFine.fine)),
      );
    }
  }

  void _showFineOutcome(AppLocalizations l, Map<String, dynamic> resp, String successMsg) {
    final money = serverMoneyFields(resp);
    final fine = money['fineVnd'] ?? money['penaltyVnd'];
    if (fine != null && fine > 0) {
      _showInfoDialog(
        title: l.provJdFineTitle,
        body: l.provJdFineBody(formatVnd(fine)),
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
        final l = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l.provJdCashRecorded),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.provJdCashRecordedBody),
              const SizedBox(height: 12),
              if (money.isEmpty)
                Text(l.provJdSeeWallet)
              else
                for (final e in money.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(moneyFieldLabel(e.key, l)),
                        Text(formatVnd(e.value), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l.provJdClose),
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
            child: Text(AppLocalizations.of(ctx).provJdClose),
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
              child: Text(AppLocalizations.of(ctx).provJdDialogCancel),
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
    // whenComplete disposes the controller once the dialog route is gone —
    // without it every open/dismiss leaks one TextEditingController.
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
              child: Text(AppLocalizations.of(ctx).provJdDialogCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  /// Photo-gated complete dialog: shows the per-slot deficit and only enables the
  /// confirm button when the quota is met (server re-enforces regardless).
  Future<bool?> _completeGateDialog(PhotoCounts counts) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx);
        Widget line(String label, int have, int need, int missing) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(have >= need ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16, color: have >= need ? Colors.green : Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(child: Text('$label  $have/$need')),
                  if (missing > 0)
                    Text(l.provJdNeedMore(missing),
                        style: const TextStyle(fontSize: 12, color: Colors.orange)),
                ],
              ),
            );
        return AlertDialog(
          title: Text(l.provJdCompleteTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.provJdCompleteGateBody),
              const SizedBox(height: 10),
              line(l.provJdBefore, counts.before, kBeforePhotosRequired, counts.missingBefore),
              line(l.provJdMid, counts.mid, kMidPhotosRequired, counts.missingMid),
              line(l.provJdAfter, counts.after, kAfterPhotosRequired, counts.missingAfter),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.provJdDialogCancel),
            ),
            FilledButton(
              onPressed: counts.meetsComplete ? () => Navigator.of(ctx).pop(true) : null,
              child: Text(l.provJdMarkComplete),
            ),
          ],
        );
      },
    );
  }
}
