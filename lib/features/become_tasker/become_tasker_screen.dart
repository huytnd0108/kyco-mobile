import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../provider_shell/provider_scaffold.dart';

/// Compiling stub — the D-unit for this folder fills it in. Renders a titled
/// "coming soon" scaffold; never invokes an API or a money call.
class BecomeTaskerScreen extends StatelessWidget {
  const BecomeTaskerScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      ProviderStubScreen(title: AppLocalizations.of(context).becomePartner, icon: Icons.handshake_outlined);
}
