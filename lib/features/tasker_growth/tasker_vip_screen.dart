import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/widgets.dart';
import 'tasker_growth_providers.dart';

/// `/p/vip` — VIP perks board. When the tasker's tier is known and below
/// platinum, an upsell explains how to reach it; otherwise (platinum, or tier
/// unavailable) the perks list is shown. Tier comes from [taskerTierProvider],
/// a read this unit owns; no money is displayed or computed here.
class TaskerVipScreen extends ConsumerWidget {
  const TaskerVipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(taskerTierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.provVipTitle)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // The perks stay readable, but a failed tier read is shown (with Retry)
          // instead of silently presenting the non-platinum view as known.
          error: (e, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: InlineErrorRow(error: e, onRetry: () => ref.invalidate(taskerTierProvider)),
              ),
              const Expanded(child: _PerksView(isPlatinum: false)),
            ],
          ),
          data: (tier) {
            // Known, below platinum → upsell. Platinum / unknown → perks.
            if (tier != null && tier != 'platinum') {
              return _UpsellView(tier: tier);
            }
            return _PerksView(isPlatinum: tier == 'platinum');
          },
        ),
      ),
    );
  }
}

class _Perk {
  const _Perk(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

List<_Perk> _perks(AppLocalizations l) => <_Perk>[
      _Perk(Icons.my_location, l.provVipPerkPriorityTitle, l.provVipPerkPriorityBody),
      _Perk(Icons.place_outlined, l.provVipPerkAreaTitle, l.provVipPerkAreaBody),
      _Perk(Icons.support_agent, l.provVipPerkSupportTitle, l.provVipPerkSupportBody),
      _Perk(Icons.emoji_events_outlined, l.provVipPerkBadgeTitle, l.provVipPerkBadgeBody),
      _Perk(Icons.card_giftcard, l.provVipPerkGiftTitle, l.provVipPerkGiftBody),
      _Perk(Icons.trending_up, l.provVipPerkBonusTitle, l.provVipPerkBonusBody),
    ];

class _PerksView extends StatelessWidget {
  const _PerksView({required this.isPlatinum});
  final bool isPlatinum;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return CenteredMaxWidth(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.primary),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPlatinum ? l.provVipWelcome : l.provVipPerksTitle,
                        style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.provVipPerksSubtitle,
                        style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.workspace_premium, size: 48, color: cs.primary),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoUp = constraints.maxWidth >= 480;
              final width =
                  twoUp ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in _perks(l))
                    SizedBox(width: width, child: _PerkCard(p)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  const _PerkCard(this.perk);
  final _Perk perk;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(perk.icon, size: 30, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(perk.title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(perk.body,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _UpsellView extends StatelessWidget {
  const _UpsellView({required this.tier});
  final String tier;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final reqs = <String>[
      l.provVipReqJobs,
      l.provVipReqRating,
      l.provVipReqCompletion,
      l.provVipReqComplaints,
    ];
    return CenteredMaxWidth(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
              child: Icon(Icons.workspace_premium, size: 64, color: cs.primary)),
          const SizedBox(height: 12),
          Text(
            l.provVipUnlockTitle,
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l.provVipUpsellBody(_tierLabel(l, tier)),
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.provVipReqTitle,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (final r in reqs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r, style: tt.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/p'),
            child: Text(l.provVipBackDashboard),
          ),
        ],
      ),
    );
  }
}

/// Vietnamese tier labels (mirrors the web `TASKER_TIER_LABELS`).
String _tierLabel(AppLocalizations l, String tier) {
  switch (tier) {
    case 'platinum':
      return l.provVipTierPlatinum;
    case 'gold':
      return l.provVipTierGold;
    case 'silver':
      return l.provVipTierSilver;
    case 'bronze':
      return l.provVipTierBronze;
    default:
      return l.labelOther;
  }
}
