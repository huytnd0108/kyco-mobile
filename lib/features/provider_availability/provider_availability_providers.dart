import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// The signed-in provider's recurring weekly grid + per-date overrides (A10).
///
/// GET /provider/availability is still pending on the backend (§A10): the
/// [KycoApiProvider.availability] method exists and is wired here, but until the
/// route ships this FutureProvider surfaces the API error through [AsyncValue]
/// — the screen renders a retryable error state rather than crashing.
final availabilityProvider = FutureProvider.autoDispose<AvailabilityWeek>((ref) {
  // Explicit extension application: KycoApi's base `availability(serviceId, date)`
  // (customer slot lookup) shadows the provider extension's no-arg `availability()`,
  // so the AvailabilityWeek variant must be invoked through KycoApiProvider(...).
  return KycoApiProvider(ref.watch(kycoApiProvider)).availability();
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

/// Feature-local strings. The shared ARB has no availability-editor keys yet
/// (this D-unit may not touch `lib/l10n`); these are reported for promotion to
/// `app_en.arb` / `app_vi.arb`. vi is the app default; en is the fallback.
class AvailL10n {
  const AvailL10n(this._vi);
  final bool _vi;

  factory AvailL10n.of(BuildContext context) =>
      AvailL10n(Localizations.localeOf(context).languageCode == 'vi');

  String get loadError => _vi
      ? 'Chưa tải được lịch làm việc. Máy chủ có thể đang bảo trì.'
      : "Couldn't load your schedule. The server may be unavailable.";
  String get weeklyHeading => _vi ? 'Lịch lặp hằng tuần' : 'Weekly schedule';
  String get weeklySub => _vi
      ? 'Khung giờ bạn nhận đơn mỗi tuần. Chạm một ngày để chỉnh.'
      : 'Recurring hours you accept jobs. Tap a day to edit.';
  String get overridesHeading => _vi ? 'Điều chỉnh theo ngày' : 'Date overrides';
  String get overridesSub => _vi
      ? 'Thay lịch cho một ngày cụ thể (ngày lễ, nghỉ phép…).'
      : 'Replace the schedule for a specific date (holiday, day off…).';
  String get addOverride => _vi ? 'Thêm điều chỉnh' : 'Add override';
  String get freeHoursTitle => _vi ? 'Tổng giờ rảnh mỗi tuần' : 'Free hours per week';
  String get noSlots => _vi ? 'Không nhận đơn' : 'Not available';
  String get unavailableFull => _vi ? 'Nghỉ cả ngày' : 'Off all day';
  String get editDay => _vi ? 'Chỉnh lịch ngày' : 'Edit day';
  String get addSlot => _vi ? 'Thêm khung giờ' : 'Add time slot';
  String get start => _vi ? 'Bắt đầu' : 'Start';
  String get end => _vi ? 'Kết thúc' : 'End';
  String get save => _vi ? 'Lưu' : 'Save';
  String get cancel => _vi ? 'Huỷ' : 'Cancel';
  String get saved => _vi ? 'Đã lưu lịch làm việc.' : 'Schedule saved.';
  String get saveFailed => _vi ? 'Lưu thất bại. Vui lòng thử lại.' : 'Save failed. Please try again.';
  String get pickDate => _vi ? 'Chọn ngày' : 'Pick a date';
  String get conflictTitle => _vi ? 'Trùng với đơn đã nhận' : 'Conflicts with committed jobs';
  String get saveAnyway => _vi ? 'Vẫn lưu' : 'Save anyway';
  String get emptyOverrides => _vi ? 'Chưa có điều chỉnh nào.' : 'No date overrides yet.';
  String get hoursUnit => _vi ? 'giờ' : 'h';
  String get slotOrderError =>
      _vi ? 'Giờ kết thúc phải sau giờ bắt đầu.' : 'End time must be after start time.';

  String conflictBody(List<int> jobIds) {
    final ids = jobIds.map((e) => '#$e').join(', ');
    return _vi
        ? 'Các đơn đã nhận sẽ không còn nằm trong lịch rảnh: $ids. Vẫn lưu?'
        : 'These committed jobs would fall outside your free hours: $ids. Save anyway?';
  }

  String weekdayShort(int dow) {
    const vi = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    const en = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return (_vi ? vi : en)[dow % 7];
  }

  String weekdayLong(int dow) {
    const vi = ['Chủ nhật', 'Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy'];
    const en = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return (_vi ? vi : en)[dow % 7];
  }

  /// `620` minutes → `10 giờ 20` / `10h 20m`; whole hours drop the minutes.
  String hoursLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (_vi) return m == 0 ? '$h giờ' : '$h giờ $m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
