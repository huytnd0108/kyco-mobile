import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// The signed-in tasker's recurring weekly grid + per-date overrides (A10).
///
/// GET /tasker/availability is still pending on the backend (§A10): the
/// [KycoApiTasker.availability] method exists and is wired here, but until the
/// route ships this FutureProvider surfaces the API error through [AsyncValue]
/// — the screen renders a retryable error state rather than crashing.
final availabilityProvider = FutureProvider.autoDispose<AvailabilityWeek>((ref) {
  // Explicit extension application: KycoApi's base `availability(serviceId, date)`
  // (customer slot lookup) shadows the tasker extension's no-arg `availability()`,
  // so the AvailabilityWeek variant must be invoked through KycoApiTasker(...).
  return KycoApiTasker(ref.watch(kycoApiProvider)).availability();
});

/// Weekday columns in Mon..Sun display order, expressed as `dow` codes where the
/// backend uses Sun=0..Sat=6 (mirrors the web grid's Mon-first layout).
const kAvailabilityDows = <int>[1, 2, 3, 4, 5, 6, 0];

/// `end - start` clamped to a non-negative span, summed over [slots], in minutes.
int slotsMinutes(List<AvailabilitySlot> slots) {
  var total = 0;
  for (final s in slots) {
    final span = s.end - s.start;
    if (span > 0) total += span;
  }
  return total;
}

/// Total recurring free minutes across the whole week.
int weeklyFreeMinutes(Map<int, List<AvailabilitySlot>> weekly) {
  var total = 0;
  for (final slots in weekly.values) {
    total += slotsMinutes(slots);
  }
  return total;
}

/// `minutes-from-midnight` → `HH:mm` (24h, zero-padded). Values past 24h wrap
/// defensively so a bad payload can never throw during layout.
String formatMinutes(int minutes) {
  final m = minutes % (24 * 60);
  final h = (m ~/ 60).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h:$mm';
}

String formatSlot(AvailabilitySlot s) => '${formatMinutes(s.start)}–${formatMinutes(s.end)}';
