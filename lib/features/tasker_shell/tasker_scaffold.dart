import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/breakpoints.dart';

class _Dest {
  const _Dest(this.icon, this.selectedIcon, this.label);
  final IconData icon, selectedIcon;
  final String label;
}

/// The tasker (`/p`) shell chrome — a sibling of the customer [AdaptiveScaffold]
/// with its own 5-tab set (Home / Jobs / Wallet / Availability / More). It reuses
/// the SAME theme, breakpoints and adaptive rail↔bottom-bar switch; it only swaps
/// the destination set, never forking theme or i18n.
class TaskerScaffold extends StatelessWidget {
  const TaskerScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _go(int i) =>
      navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dests = [
      _Dest(Icons.dashboard_outlined, Icons.dashboard, l.provTabHome),
      _Dest(Icons.work_outline, Icons.work, l.provTabJobs),
      _Dest(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, l.provTabWallet),
      _Dest(Icons.event_available_outlined, Icons.event_available, l.provTabAvailability),
      _Dest(Icons.menu, Icons.menu, l.provTabMore),
    ];
    final size = windowSizeOf(context);
    final i = navigationShell.currentIndex;

    if (size == WindowSize.compact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: _go,
          destinations: [
            for (final d in dests)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = size == WindowSize.expanded;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              extended: extended,
              labelType: extended ? null : NavigationRailLabelType.all,
              selectedIndex: i,
              onDestinationSelected: _go,
              backgroundColor: cs.surface,
              destinations: [
                for (final d in dests)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: cs.outlineVariant),
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: true,
              child: navigationShell,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared compiling placeholder for the tasker screens the parallel D-units
/// will flesh out. Renders a titled scaffold with a "coming soon" body — NEVER
/// invokes an API or a money call.
class TaskerStubScreen extends StatelessWidget {
  const TaskerStubScreen({super.key, required this.title, this.icon = Icons.construction});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l.provComingSoon, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
