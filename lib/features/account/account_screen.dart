import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/locale_controller.dart';
import '../../theme/theme_mode_controller.dart';
import '../auth/auth_controller.dart';
import 'account_providers.dart';
import 'change_phone_sheet.dart';

/// Account tab — mirrors the web `mobile-account-sheet.tsx` drawer as a full
/// scrollable page. GUEST-FIRST: the whole page is usable signed-out (browse
/// links, switch theme / language). Only the My-account card and Sign-out are
/// authed affordances; the signed-in card is API-backed via `me()` but never
/// blocks the settings below.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
              // ── Identity header ────────────────────────────────────────
              if (signedIn)
                _AccountCard(auth: auth)
              else
                const _GuestHeader(),
              const SizedBox(height: 20),

              // ── Navigation rows (mirror the web sheet items) ───────────
              _AccountRow(
                icon: Icons.notifications_none,
                label: l.notificationsTitle,
                onTap: () => context.push('/notifications'),
              ),
              _AccountRow(
                icon: Icons.card_membership,
                label: l.subscriptionsTitle,
                onTap: () => context.push('/subscriptions'),
              ),
              if (signedIn)
                _AccountRow(
                  icon: Icons.receipt_long,
                  label: l.myBookings,
                  onTap: () => context.go('/bookings'),
                ),
              if (signedIn)
                _AccountRow(
                  icon: Icons.place_outlined,
                  label: l.cust2Addresses,
                  onTap: () => context.push('/addresses'),
                ),
              if (signedIn)
                _AccountRow(
                  icon: Icons.phone_iphone,
                  label: l.changePhoneTitle,
                  onTap: () => _runChangePhone(context, ref),
                ),
              const _RowDivider(),
              if (signedIn)
                _AccountRow(
                  icon: Icons.card_giftcard,
                  label: l.inviteFriends,
                  onTap: () => context.push('/invite'),
                ),
              // Role-aware entry: a tasker (or admin — the /p gate admits both)
              // gets the in-app /p workspace; everyone else the onboarding flow.
              if (auth.user?.role == 'tasker' || auth.user?.role == 'admin')
                _AccountRow(
                  icon: Icons.handshake_outlined,
                  label: l.provWorkspace,
                  onTap: () => context.go('/p'),
                )
              else
                _AccountRow(
                  icon: Icons.handshake_outlined,
                  label: l.becomePartner,
                  onTap: () => context.push('/become-tasker'),
                ),
              // Public curated content (GET /v1/legal/{doc}, /v1/help).
              _AccountRow(
                icon: Icons.chat_bubble_outline,
                label: l.contactUs,
                onTap: () => context.push('/legal/contact'),
              ),
              _AccountRow(
                icon: Icons.info_outline,
                label: l.aboutKyco,
                onTap: () => context.push('/legal/about'),
              ),
              _AccountRow(
                icon: Icons.help_outline,
                label: l.faqs,
                onTap: () => context.push('/help'),
              ),
              const SizedBox(height: 20),

              // ── Appearance ─────────────────────────────────────────────
              _SectionLabel(l.appearance),
              // Wrap (not SegmentedButton) so it never overflows at 320dp /
              // large Dynamic Type — chips flow to the next line (M1 fix).
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

              // ── Language ───────────────────────────────────────────────
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

              // ── Sign out (authed only) ─────────────────────────────────
              if (signedIn) ...[
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                  label: Text(l.logout),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Open the verified phone-change flow; on a confirmed change, refresh the
/// account/me read so the new number shows and confirm with a snackbar.
Future<void> _runChangePhone(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final changed = await showChangePhoneSheet(context);
  if (!changed) return;
  ref.invalidate(accountMeProvider);
  messenger.showSnackBar(SnackBar(content: Text(l.changePhoneSuccess)));
}

/// Signed-in identity card — API-backed by `me()`, falling back to the cached
/// auth user while the read loads or if it fails (never blocks the page).
class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.auth});
  final AuthState auth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final me = ref.watch(accountMeProvider).valueOrNull;
    final name = me?.name ?? auth.user?.name ?? l.myAccount;
    // AuthUser exposes no email (see report) — surface role as the subtitle.
    final subtitle = me?.role ?? auth.user?.role;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.person, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guest header — `notSignedIn` title + prompt + Sign in / Sign up buttons.
class _GuestHeader extends StatelessWidget {
  const _GuestHeader();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.notSignedIn,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            const SizedBox(height: 4),
            Text(l.signInPrompt, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/login'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    child: Text(l.login),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => context.push('/signup'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    child: Text(l.signup),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A single tappable (or informational) account row — icon + label + chevron.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: false,
      leading: Icon(icon, color: cs.onSurfaceVariant),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(
        Icons.chevron_right,
        size: 22,
        color: cs.onSurfaceVariant,
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 16, thickness: 0.5, indent: 8, endIndent: 8);
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
