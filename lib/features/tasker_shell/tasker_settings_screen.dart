import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../account/settings_sections.dart';

/// `/p/settings` - the tasker-side home for what the customer Account tab
/// offers: notifications, theme, language and account deletion (UX-M16). A
/// tasker cannot self-delete (the server answers 409), so the deletion row
/// opens the screen that routes them to support.
class TaskerSettingsScreen extends StatelessWidget {
  const TaskerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAndAccountTitle)),
      body: SafeArea(
        child: CenteredMaxWidth(
          maxWidth: 600,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                key: const ValueKey('tasker-settings-notifications'),
                leading: Icon(Icons.notifications_none, color: cs.onSurfaceVariant),
                title: Text(l.notificationsTitle, style: const TextStyle(fontWeight: FontWeight.w500)),
                trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => context.push('/notifications'),
              ),
              const SizedBox(height: 16),
              const ThemeSettings(),
              const SizedBox(height: 24),
              const LanguageSettings(),
              const SizedBox(height: 24),
              ListTile(
                key: const ValueKey('tasker-settings-delete'),
                leading: Icon(Icons.delete_outline, color: cs.error),
                title: Text(l.deleteAccountTitle,
                    style: TextStyle(fontWeight: FontWeight.w500, color: cs.error)),
                trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => context.push('/delete-account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
