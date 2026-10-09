import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'account_providers.dart';

/// Shared signed-out body for the account sub-screens (guest-first: the route
/// is reachable, the data is not).
class SignInGate extends StatelessWidget {
  const SignInGate({super.key, required this.from});
  final String from;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: '🔒',
      message: l.signInToView,
      action: FilledButton(
        onPressed: () => context.push('/login?from=${Uri.encodeQueryComponent(from)}'),
        child: Text(l.login),
      ),
    );
  }
}

/// `/invite` — the user's invite code (`POST /v1/invites/code`, idempotent) +
/// referral counts (`GET /v1/invites/stats`). No money is shown or moved here.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn = ref.watch(authControllerProvider).status == AuthStatus.signedIn;
    return Scaffold(
      appBar: AppBar(title: Text(l.inviteFriends)),
      body: SafeArea(
        child: !signedIn
            ? const SignInGate(from: '/invite')
            : CenteredMaxWidth(maxWidth: 600, child: _InviteBody()),
      ),
    );
  }
}

class _InviteBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final code = ref.watch(inviteCodeProvider);
    final stats = ref.watch(inviteStatsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(inviteStatsProvider);
        ref.invalidate(inviteCodeProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.cust2InviteBody, style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: code.when(
                loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => ErrorRetry(
                  message: apiErrorText(l, e),
                  onRetry: () => ref.invalidate(inviteCodeProvider),
                ),
                data: (c) => Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.cust2InviteYourCode, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 4),
                          SelectableText(c,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 2)),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: c.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(ClipboardData(text: c));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text(l.cust2InviteCopied)));
                              }
                            },
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l.cust2InviteCopy),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          stats.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => ErrorBanner(apiErrorText(l, e)),
            data: (s) => Row(
              children: [
                Expanded(child: _StatTile(label: l.cust2InvitePending, value: s.pending)),
                const SizedBox(width: 12),
                Expanded(child: _StatTile(label: l.cust2InviteSignedUp, value: s.signedUp)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
