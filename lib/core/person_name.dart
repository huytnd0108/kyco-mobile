import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Since backend release-h a tasker's name is the real display name or null -
/// the numbered "Tasker #N" placeholder is never sent, so none is parsed here.
/// True for a missing / blank name.
bool isMissingPersonName(String? name) => name == null || name.trim().isEmpty;

/// The name to SHOW for a tasker: the real display name when there is one,
/// else the single localized term ("Cộng tác viên" / "Tasker").
String taskerDisplayName(AppLocalizations l, String? name) =>
    isMissingPersonName(name) ? l.cust2DetailProvider : name!.trim();
