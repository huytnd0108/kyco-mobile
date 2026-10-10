import 'package:kyco_mobile/l10n/app_localizations.dart';

/// The backend falls back to a numbered placeholder ("Tasker #4") when a tasker
/// has no display name yet. That is a system label, never a person's name.
final _placeholderName = RegExp(r'^\s*(tasker|ctv|người làm|cộng tác viên)\s*#?\s*\d+\s*$',
    caseSensitive: false, unicode: true);

/// True for a missing / blank / "Tasker #N"-style placeholder name.
bool isPlaceholderPersonName(String? name) =>
    name == null || name.trim().isEmpty || _placeholderName.hasMatch(name);

/// The name to SHOW for a tasker: the real display name when there is one,
/// else the single localized term ("Cộng tác viên" / "Tasker") - never "Tasker #N".
String taskerDisplayName(AppLocalizations l, String? name) =>
    isPlaceholderPersonName(name) ? l.cust2DetailProvider : name!.trim();
