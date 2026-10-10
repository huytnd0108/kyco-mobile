import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/problem.dart';
import '../../core/datetime.dart';
import '../../core/di.dart';
import '../../core/launch.dart';
import '../../core/models.dart';
import '../../core/visible_poller.dart';
import '../auth/auth_controller.dart';

/// Booking statuses during which the customer may follow the tasker: from the
/// moment they set off until the job is running. The server additionally only
/// returns a position inside its live window (`position: null` otherwise).
const kTrackableStatuses = {'EN_ROUTE', 'ARRIVED', 'CHECKED_IN', 'ACTIVE'};

bool isTrackable(String status) => kTrackableStatuses.contains(status.toUpperCase());

/// How often the card re-reads the position while visible.
const Duration kTrackingPollInterval = Duration(seconds: 20);

/// A position older than this is labelled stale.
const int kStaleAfterSec = 120;

/// `GET /v1/jobs/{id}/location` for the signed-in customer. 404 (the server
/// answers a foreign / missing job like this, MQA-60) and 403 are "nothing to
/// show" rather than errors.
final jobTrackingProvider = FutureProvider.autoDispose.family<JobTracking, int>((ref, jobId) async {
  ref.watch(authUserIdProvider);
  try {
    return await ref.watch(kycoApiProvider).jobLocation(jobId);
  } on ApiException catch (e) {
    if (e.status == 404 || e.status == 403 || e.code == 'NOT_FOUND' || e.code == 'FORBIDDEN') {
      return const JobTracking();
    }
    rethrow;
  }
});

/// "Vị trí người làm": last-updated time (VN), server distance / ETA as text, a
/// static position and an "Open map" hand-off. No map SDK is bundled - the
/// position opens in the user's maps app. Polls every [kTrackingPollInterval]
/// only while visible; stops on dispose and when the app is backgrounded.
class TrackingCard extends ConsumerStatefulWidget {
  const TrackingCard({super.key, required this.jobId});
  final int jobId;

  @override
  ConsumerState<TrackingCard> createState() => _TrackingCardState();
}

class _TrackingCardState extends ConsumerState<TrackingCard> {
  late final VisiblePoller _poller;

  @override
  void initState() {
    super.initState();
    _poller = VisiblePoller(
      interval: kTrackingPollInterval,
      isVisible: () => mounted && TickerMode.valuesOf(context).enabled,
      onTick: () => ref.invalidate(jobTrackingProvider(widget.jobId)),
    )..start();
  }

  @override
  void dispose() {
    _poller.dispose();
    super.dispose();
  }

  Future<void> _openMap(JobTracking t) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(urlOpenerProvider)(mapsUri(t.lat!, t.lng!));
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.openLinkFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(jobTrackingProvider(widget.jobId));
    final t = async.valueOrNull;

    final children = <Widget>[];
    if (t != null && t.hasPosition) {
      final time = formatVnTime(t.recordedAt);
      if (time != '—') children.add(Text(l.trackUpdatedAt(time)));
      if ((t.ageSec ?? 0) > kStaleAfterSec) {
        children.add(Text(l.trackStale, style: TextStyle(color: cs.error)));
      }
      final d = t.distanceM;
      if (d != null) {
        children.add(Text(d < 1000
            ? l.trackDistanceM(d)
            : l.trackDistanceKm((d / 1000).toStringAsFixed(1))));
      }
      if (t.etaMin != null) children.add(Text(l.trackEta(t.etaMin!)));
      children.add(Text(l.trackCoords(t.lat!.toStringAsFixed(5), t.lng!.toStringAsFixed(5)),
          style: TextStyle(color: cs.onSurfaceVariant)));
      children.add(Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          container: true,
          button: true,
          label: l.trackOpenMapLabel,
          excludeSemantics: true,
          child: OutlinedButton.icon(
            key: const ValueKey('tracking-open-map'),
            onPressed: () => _openMap(t),
            icon: const Icon(Icons.map_outlined),
            label: Text(l.trackOpenMap),
          ),
        ),
      ));
    } else if (async.isLoading && t == null) {
      children.add(const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    } else if (async.hasError && t == null) {
      children.add(Text(l.trackLoadFailed, key: const ValueKey('tracking-error')));
    } else {
      children.add(Text(l.trackNoPosition, key: const ValueKey('tracking-empty')));
    }

    return Card(
      key: const ValueKey('tracking-card'),
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.my_location, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.trackCardTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            for (final w in children) Padding(padding: const EdgeInsets.only(top: 4), child: w),
          ],
        ),
      ),
    );
  }
}
