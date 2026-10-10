import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'tasker_growth_providers.dart';
import 'package:kyco_mobile/core/datetime.dart';
import 'package:kyco_mobile/core/labels.dart';

/// `/p/bonuses` — weekly + monthly bonus preview cards + payout history.
///
/// Every VND figure is server-computed (`TaskerBonuses`); this screen only
/// formats and displays them — it never computes or posts an amount.
class TaskerBonusesScreen extends ConsumerWidget {
  const TaskerBonusesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(bonusesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.provBonusesTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bonusesProvider);
            await refreshQuietly(ref.read(bonusesProvider.future));
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 120),
              ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(bonusesProvider),
              ),
            ]),
            data: (b) => _BonusesBody(b),
          ),
        ),
      ),
    );
  }
}

class _BonusesBody extends StatelessWidget {
  const _BonusesBody(this.b);
  final TaskerBonuses b;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CenteredMaxWidth(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionHeader(l.provBonusesWeekTitle),
          _BonusGrid(b.weekly),
          SectionHeader(l.provBonusesMonthTitle),
          _BonusGrid(b.monthly),
          SectionHeader(l.provBonusesHistoryTitle),
          if (b.history.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(l.provBonusesHistoryEmpty),
            )
          else
            for (final h in b.history) _HistoryTile(h),
        ],
      ),
    );
  }
}

class _BonusGrid extends StatelessWidget {
  const _BonusGrid(this.bonuses);
  final List<Bonus> bonuses;

  @override
  Widget build(BuildContext context) {
    if (bonuses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(AppLocalizations.of(context).provBonusesNone),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoUp = constraints.maxWidth >= 480;
          final width = twoUp ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final bonus in bonuses)
                SizedBox(width: width, child: _BonusCard(bonus)),
            ],
          );
        },
      ),
    );
  }
}

class _BonusCard extends StatelessWidget {
  const _BonusCard(this.bonus);
  final Bonus bonus;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // The server sends `earned`/`reason` inside the raw BonusOutput map.
    final earned = bonus.raw['earned'] == true || bonus.eligible;
    final reason = bonus.raw['reason']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: earned ? cs.primaryContainer : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: earned ? cs.primary : cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(bonusKindLabel(l, bonus.kind),
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
              _EarnedBadge(earned: earned),
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reason,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                earned ? l.provBonusEarned : l.provBonusMax,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '+${formatVnd(bonus.amountVnd)}',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: earned ? cs.primary : cs.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EarnedBadge extends StatelessWidget {
  const _EarnedBadge({required this.earned});
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final bg = earned ? cs.primary : cs.surfaceContainerHigh;
    final fg = earned ? cs.onPrimary : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(earned ? l.provBonusEarned : l.provBonusNotEarned,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.item);
  final BonusHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final period = [item.periodStart, item.periodEnd]
        .where((s) => s != null && s.isNotEmpty)
        .map((s) => vnDateMedium(context, s))
        .join(' → ');
    final paid = (item.paidAt == null ? null : vnDate(context, item.paidAt));
    final sub = [period, ?paid].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bonusKindLabel(l, item.kind),
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (sub.isNotEmpty)
                  Text(sub, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('+${formatVnd(item.amountVnd)}',
              style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: cs.primary)),
        ],
      ),
    );
  }
}

