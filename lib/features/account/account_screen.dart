import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/locale_controller.dart';
import '../../theme/theme_mode_controller.dart';
import '../auth/auth_controller.dart';

/// Account + settings. Public: usable signed-out so anyone can switch theme /
/// language; shows a sign-in prompt instead of the user card when signed out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authControllerProvider);
    final signedIn = auth.status == AuthStatus.signedIn;
    final mode = ref.watch(themeModeControllerProvider);
    final locale = ref.watch(localeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.accountTitle)),
      body: SafeArea(
        child: CenteredMaxWidth(
          maxWidth: 600,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // User card / sign-in prompt
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: signedIn
                      ? Row(children: [
                          CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            child: Icon(Icons.person, color: cs.onPrimaryContainer),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(auth.user?.name ?? l.myAccount,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          ),
                          TextButton.icon(
                            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                            icon: const Icon(Icons.logout),
                            label: Text(l.logout),
                          ),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(l.signInPrompt, style: TextStyle(color: cs.onSurfaceVariant)),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.go('/login'),
                            child: Text(l.login),
                          ),
                        ]),
                ),
              ),
              const SizedBox(height: 24),

              // Appearance
              _SectionLabel(l.appearance),
              // Wrap (not SegmentedButton) so it never overflows at 320dp
              // Slide Over / large Dynamic Type — chips flow to the next line.
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
              const SizedBox(height: 24),

              // Language
              _SectionLabel(l.language),
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
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
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
