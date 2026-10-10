import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../auth/auth_controller.dart';

/// The tasker "More" tab — a menu into the secondary tasker surfaces and a
/// switch back to the customer app. Each row pushes a `/p/*` route (stubs for
/// now); "switch to customer" leaves the tasker shell for `/`.
class TaskerMoreScreen extends ConsumerWidget {
  const TaskerMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final items = <(IconData, String, String)>[
      (Icons.card_giftcard, l.provBonusesTitle, '/p/bonuses'),
      (Icons.flag_outlined, l.provGoalsTitle, '/p/goals'),
      (Icons.leaderboard_outlined, l.provLeaderboardTitle, '/p/leaderboard'),
      (Icons.workspace_premium_outlined, l.provVipTitle, '/p/vip'),
      (Icons.gavel_outlined, l.provFinesTitle, '/p/fines'),
      (Icons.event_busy_outlined, l.provCancellationsTitle, '/p/cancellations'),
      (Icons.share_outlined, l.provReferralsTitle, '/p/referrals'),
      (Icons.support_agent_outlined, l.provSupportTitle, '/p/support'),
      (Icons.settings_outlined, l.settingsAndAccountTitle, '/p/settings'),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.provMoreTitle)),
      body: SafeArea(
        child: CenteredMaxWidth(
          maxWidth: 600,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final (icon, label, path) in items)
                ListTile(
                  leading: Icon(icon, color: cs.onSurfaceVariant),
                  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => context.push(path),
                ),
              const Divider(height: 24),
              ListTile(
                leading: Icon(Icons.swap_horiz, color: cs.primary),
                title: Text(l.provSwitchToCustomer,
                    style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () => context.go('/'),
              ),
              if (ref.watch(authControllerProvider).status == AuthStatus.signedIn)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout),
                    label: Text(l.logout),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
