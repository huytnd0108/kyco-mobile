import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import 'breakpoints.dart';

/// Caps + centers content on wide screens (iPad) so it never runs edge-to-edge.
class CenteredMaxWidth extends StatelessWidget {
  const CenteredMaxWidth({super.key, this.maxWidth = 1200, required this.child});
  final double maxWidth;
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

class _Dest {
  const _Dest(this.icon, this.selectedIcon, this.label);
  final IconData icon, selectedIcon;
  final String label;
}

/// One shell that swaps its navigation chrome by window size:
/// compact → bottom NavigationBar; medium → icon rail; expanded → extended rail.
/// The branch content (the shell) is identical across all three.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _go(int i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final dests = [
      _Dest(Icons.home_outlined, Icons.home, l.navHome),
      _Dest(Icons.grid_view_outlined, Icons.grid_view, l.navServices),
      _Dest(Icons.receipt_long_outlined, Icons.receipt_long, l.navBookings),
      _Dest(Icons.chat_bubble_outline, Icons.chat_bubble, l.navMessages),
      _Dest(Icons.person_outline, Icons.person, l.navAccount),
    ];
    final size = windowSizeOf(context);
    final i = navigationShell.currentIndex;

    if (size == WindowSize.compact) {
      return Scaffold(
        body: navigationShell,
        // Persistent primary CTA mirroring the web header's "⚡ Đặt ngay" pill.
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/book-now'),
          icon: const Text('⚡', style: TextStyle(fontSize: 16)),
          label: Text(l.bookNow),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
              // Same persistent primary CTA on the rail (leading button).
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: extended
                    ? FloatingActionButton.extended(
                        heroTag: 'bookNowRail',
                        onPressed: () => context.push('/book-now'),
                        icon: const Text('⚡', style: TextStyle(fontSize: 16)),
                        label: Text(l.bookNow),
                      )
                    : FloatingActionButton(
                        heroTag: 'bookNowRail',
                        onPressed: () => context.push('/book-now'),
                        child: const Text('⚡', style: TextStyle(fontSize: 20)),
                      ),
              ),
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
          // The rail already cleared the left safe-area inset; strip it from the
          // content so body SafeAreas don't add it a second time.
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
