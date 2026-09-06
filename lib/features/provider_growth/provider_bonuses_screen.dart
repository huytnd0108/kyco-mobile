import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'provider_growth_providers.dart';

/// `/p/bonuses` 💰 — weekly + monthly bonus preview cards + payout history.
///
/// Every VND figure is server-computed (`ProviderBonuses`); this screen only
/// formats and displays them — it never computes or posts an amount.
class ProviderBonusesScreen extends ConsumerWidget {
  const ProviderBonusesScreen({super.key});

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
            await ref.read(bonusesProvider.future);
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 120),
              ErrorRetry(
                message: l.genericError,
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
  final ProviderBonuses b;

  @override
  Widget build(BuildContext context) {
    // MISSING-ARB: 'Thưởng tuần này' / 'This week's bonuses'.
    return CenteredMaxWidth(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const SectionHeader('Thưởng tuần này'),
          _BonusGrid(b.weekly),
          const SectionHeader('Thưởng tháng này'),
          _BonusGrid(b.monthly),
          const SectionHeader('Lịch sử thưởng'),
          if (b.history.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
              // MISSING-ARB: 'Chưa có khoản thưởng nào được chi.'
              child: Text('Chưa có khoản thưởng nào được chi.'),
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
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        // MISSING-ARB: 'Không có thưởng khả dụng.'
        child: Text('Không có thưởng khả dụng.'),
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
                child: Text(_bonusLabel(bonus.kind),
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
                // MISSING-ARB: 'Đã đạt' / 'Tối đa'
                earned ? 'Đã đạt' : 'Tối đa',
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
    final cs = Theme.of(context).colorScheme;
    final bg = earned ? cs.primary : cs.surfaceContainerHigh;
    final fg = earned ? cs.onPrimary : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      // MISSING-ARB: 'Đã đạt' / 'Chưa đạt'
      child: Text(earned ? 'Đã đạt' : 'Chưa đạt',
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
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final period = [item.periodStart, item.periodEnd]
        .where((s) => s != null && s.isNotEmpty)
        .join(' → ');
    final paid = item.paidAt != null && item.paidAt!.length >= 10
        ? item.paidAt!.substring(0, 10)
        : null;
    final sub = [period, ?paid].where((s) => s.isNotEmpty).join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_bonusLabel(item.kind),
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

/// Vietnamese bonus labels — mirrors the web `BONUS_LABELS`. MISSING-ARB:
/// no l10n keys exist for these yet, so they are inlined and reported.
String _bonusLabel(String? kind) {
  switch (kind) {
    case 'weekly_jobs':
      return '🏆 Thưởng tuần (số đơn)';
    case 'monthly_revenue':
      return '🏅 Thưởng tháng (doanh thu)';
    case 'punctuality':
      return '📅 Thưởng chuyên cần';
    case 'rating':
      return '⭐ Thưởng rating cao';
    case 'referral':
      return '👥 Thưởng giới thiệu';
    default:
      return kind ?? '—';
  }
}
