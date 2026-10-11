import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../config.dart';
import '../models.dart';
import '../launch.dart';
import '../legal.dart';

/// Web legal pages (verified 200 on kyco.vn): `/<locale>/legal/terms` and
/// `/<locale>/legal/privacy`. The in-app `/legal/:doc` screens only serve
/// `about` and `contact`, so terms/privacy open in the browser.
Uri legalWebUri(BuildContext context, String doc) {
  final code = Localizations.localeOf(context).languageCode;
  final loc = code == 'en' ? 'en' : 'vi';
  return Uri.parse('${AppConfig.webBase}/$loc/legal/$doc');
}

/// The page to open for [doc] (`terms` | `privacy`): the server's URL from
/// `/v1/legal` when it sent a valid https one, else [legalWebUri].
Uri legalDocUri(BuildContext context, LegalInfo? legal, String doc) =>
    (doc == 'terms' ? legal?.termsUrl : legal?.privacyUrl) ?? legalWebUri(context, doc);

/// Explicit consent before account creation (UX-M06 / web FE-47).
///
/// The box is required client-side whatever the server supports. Whether the
/// consent is also SENT is decided at submit time by `resolveLegal` (only when
/// GET /v1/legal answered 200; MQA-65: older servers reject unknown body keys).
/// The links use the server's locale-specific URLs when present, else the web
/// paths.
class ConsentCheckbox extends ConsumerWidget {
  const ConsentCheckbox({super.key, required this.value, required this.onChanged, this.showError = false});
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final legal = ref.watch(legalProvider).valueOrNull;
    void open(String doc) => ref.read(urlOpenerProvider)(legalDocUri(context, legal, doc));
    final err = showError && !value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          type: MaterialType.transparency,
          child: CheckboxListTile(
          key: const ValueKey('consent-checkbox'),
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(l.consentAgree),
          ),
        ),
        Wrap(
          children: [
            TextButton(
              key: const ValueKey('consent-terms-link'),
              onPressed: () => open('terms'),
              child: Text(l.consentTermsLink),
            ),
            TextButton(
              key: const ValueKey('consent-privacy-link'),
              onPressed: () => open('privacy'),
              child: Text(l.consentPrivacyLink),
            ),
          ],
        ),
        if (err)
          Semantics(
            liveRegion: true,
            child: Text(l.consentRequired, key: const ValueKey('consent-error'), style: TextStyle(color: cs.error)),
          ),
      ],
    );
  }
}
