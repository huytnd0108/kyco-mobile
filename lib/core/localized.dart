/// Single place that decides which half of a VI/EN pair to show.
///
/// [locale] is a language code ('vi' | 'en'; anything else is treated as 'vi',
/// the app's fallback). The matching side wins when non-empty; otherwise the
/// other side is used so a half-translated record still renders something
/// rather than a blank. Returns null when both are empty.
String? pickLocalized(String locale, {String? vi, String? en}) {
  String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s;
  final v = clean(vi);
  final e = clean(en);
  return locale == 'en' ? (e ?? v) : (v ?? e);
}

/// [pickLocalized] with a non-null result ('' when both are empty).
String pickLocalizedOr(String locale, {String? vi, String? en}) =>
    pickLocalized(locale, vi: vi, en: en) ?? '';
