import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The single date/time module (UX-M57/M58/M59).
///
/// Every instant the server sends is shown in **Asia/Ho_Chi_Minh wall-clock
/// time**, never the device zone. Vietnam has no DST and has been UTC+7 for the
/// whole life of this app, so a fixed offset is exact and no tz database is
/// pulled in.
///
/// A "VN wall-clock" value is represented as a `DateTime.utc(...)` whose
/// *fields* are the Vietnamese local fields (e.g. `2026-10-12 09:00`). intl's
/// `DateFormat` formats by fields, so it prints exactly those fields.
const Duration kVnOffset = Duration(hours: 7);

const String _dash = '—';

/// Parses a server timestamp to an absolute instant.
///
///  - ISO-8601 with `Z` / `±hh:mm` → that instant.
///  - Postgres style `2026-12-06 02:00:00+00` (space separator, short offset).
///  - Zone-less `2026-10-12T09:00:00` → the server reads these as VN wall-clock
///    (checkout sends `scheduledAt` that way), so it is interpreted as +07:00.
/// Returns null when [raw] is null / empty / not a date.
DateTime? parseInstant(String? raw) {
  var s = raw?.trim() ?? '';
  if (s.isEmpty) return null;
  // Postgres: "2026-12-06 02:00:00+00" → "2026-12-06T02:00:00+00:00".
  s = s.replaceFirstMapped(
      RegExp(r'^(\d{4}-\d{2}-\d{2}) (?=\d)'), (m) => '${m[1]}T');
  s = s.replaceFirstMapped(RegExp(r'(?<=\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?)([+-]\d{2})$'),
      (m) => '${m[1]}:00'); // "+00" → "+00:00"
  // Dart's parser silently rolls `2026-13-45` over to a later date; reject it.
  final ymd = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (ymd != null) {
    final y = int.parse(ymd[1]!), m = int.parse(ymd[2]!), d = int.parse(ymd[3]!);
    final check = DateTime.utc(y, m, d);
    if (m < 1 || m > 12 || check.month != m || check.day != d) return null;
  }
  final dt = DateTime.tryParse(s);
  if (dt == null) return null;
  if (dt.isUtc) return dt; // had Z or an explicit offset (already converted)
  // Zone-less: fields are VN wall-clock → shift to the true instant.
  return DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
          dt.millisecond, dt.microsecond)
      .subtract(kVnOffset);
}

/// VN wall-clock (UTC-flagged fields) of an absolute instant.
DateTime toVnWall(DateTime instant) => instant.toUtc().add(kVnOffset);

/// VN wall-clock of a server timestamp, or null when unparseable.
DateTime? vnWall(String? raw) {
  final i = parseInstant(raw);
  return i == null ? null : toVnWall(i);
}

/// "Now" in Vietnam (wall-clock fields). [now] is injectable for tests.
DateTime vnNow([DateTime? now]) => toVnWall(now ?? DateTime.now());

/// Today's VN calendar date as a date-only `DateTime` (local-flagged midnight,
/// suitable as `showDatePicker` first/initial/last date and for `yyyy-MM-dd`).
DateTime vnToday([DateTime? now]) {
  final w = vnNow(now);
  return DateTime(w.year, w.month, w.day);
}

/// `yyyy-MM-dd` of a VN date (API date wire format; never shown to users).
String vnDateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String _loc(String? locale) => (locale == null || locale.isEmpty) ? 'vi' : locale;

/// Localized date, e.g. `12/10/2026` (vi) / `10/12/2026` (en). '—' if invalid.
String formatVnDate(String? raw, {String? locale}) {
  final w = vnWall(raw);
  return w == null ? _dash : DateFormat.yMd(_loc(locale)).format(w);
}

/// Localized medium date, e.g. `12 thg 10, 2026` / `Oct 12, 2026`.
String formatVnDateMedium(String? raw, {String? locale}) {
  final w = vnWall(raw);
  return w == null ? _dash : DateFormat.yMMMd(_loc(locale)).format(w);
}

/// Localized date + 24h time, e.g. `12/10/2026 09:00`.
String formatVnDateTime(String? raw, {String? locale}) {
  final w = vnWall(raw);
  // Zero-padded 24h time in both locales (intl's vi `Hm` is the unpadded `H:mm`).
  return w == null
      ? _dash
      : '${DateFormat.yMd(_loc(locale)).format(w)} ${DateFormat('HH:mm').format(w)}';
}

/// Localized 24h time `HH:mm` in VN time.
String formatVnTime(String? raw, {String? locale}) {
  final w = vnWall(raw);
  return w == null ? _dash : DateFormat('HH:mm').format(w);
}

/// Long weekday + date of a `yyyy-MM-dd` VN date key (availability overrides),
/// e.g. `Thứ Hai, 12 thg 10, 2026`. '—' when [key] is not a date.
String formatVnDateKey(String? key, {String? locale}) {
  final d = DateTime.tryParse((key ?? '').trim());
  return d == null ? _dash : DateFormat.yMMMEd(_loc(locale)).format(d);
}

/// Localized picked checkout date (a date-only value from `showDatePicker`).
String formatPickedDate(DateTime d, {String? locale}) =>
    DateFormat.yMMMEd(_loc(locale)).format(d);

// ── BuildContext conveniences (locale from the active Localizations) ──────────

String _ctxLocale(BuildContext c) => Localizations.localeOf(c).toString();

String vnDate(BuildContext c, String? raw) =>
    formatVnDate(raw, locale: _ctxLocale(c));
String vnDateMedium(BuildContext c, String? raw) =>
    formatVnDateMedium(raw, locale: _ctxLocale(c));
String vnDateTime(BuildContext c, String? raw) =>
    formatVnDateTime(raw, locale: _ctxLocale(c));
String vnDateKeyLabel(BuildContext c, String? key) =>
    formatVnDateKey(key, locale: _ctxLocale(c));

// ── goal / bonus period keys (built from [vnNow]; see growth providers) ──────

/// Parsed form of a period key, for localized display.
typedef Period = ({bool isWeek, int year, int number});

/// Parses `2026-W41` / `2026-10`; null for anything else.
Period? parsePeriodKey(String? key) {
  final k = (key ?? '').trim();
  final w = RegExp(r'^(\d{4})-W(\d{1,2})$').firstMatch(k);
  if (w != null) {
    return (isWeek: true, year: int.parse(w[1]!), number: int.parse(w[2]!));
  }
  final m = RegExp(r'^(\d{4})-(\d{1,2})$').firstMatch(k);
  if (m != null) {
    final mo = int.parse(m[2]!);
    if (mo >= 1 && mo <= 12) {
      return (isWeek: false, year: int.parse(m[1]!), number: mo);
    }
  }
  return null;
}
