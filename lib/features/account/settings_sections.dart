import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/locale_controller.dart';
import '../../theme/theme_mode_controller.dart';

/// Section heading used by the settings blocks.
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// Theme chooser (system / light / dark). Shared by the customer Account tab
/// and the tasker settings screen. Wrap (not SegmentedButton) so it never
/// overflows at 320dp / large Dynamic Type.
class ThemeSettings extends ConsumerWidget {
  const ThemeSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mode = ref.watch(themeModeControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionLabel(l.appearance),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (m, label, icon) in <(ThemeMode, String, IconData)>[
              (ThemeMode.system, l.themeSystem, Icons.brightness_auto),
              (ThemeMode.light, l.themeLight, Icons.light_mode),
              (ThemeMode.dark, l.themeDark, Icons.dark_mode),
            ])
              ChoiceChip(
                selected: mode == m,
                onSelected: (_) => ref.read(themeModeControllerProvider.notifier).set(m),
                avatar: Icon(icon, size: 18),
                label: Text(label),
              ),
          ],
        ),
      ],
    );
  }
}

/// Language chooser (system / vi / en).
class LanguageSettings extends ConsumerWidget {
  const LanguageSettings({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionLabel(l.language),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (code, label) in <(String, String)>[
              ('system', l.langSystem),
              ('vi', l.langVi),
              ('en', l.langEn),
            ])
              ChoiceChip(
                selected: (locale?.languageCode ?? 'system') == code,
                onSelected: (_) => ref
                    .read(localeControllerProvider.notifier)
                    .set(code == 'system' ? null : Locale(code)),
                label: Text(label),
              ),
          ],
        ),
      ],
    );
  }
}
