import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'provider_growth_providers.dart';

/// `/p/leaderboard` 💰 — ranked partners by server-provided revenue, scoped to
/// week/month + an optional district filter, with the signed-in provider's row
/// highlighted and their rank surfaced. Revenue is display-only.
class ProviderLeaderboardScreen extends ConsumerWidget {
  const ProviderLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.provLeaderboardTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leaderboardProvider);
            await ref.read(leaderboardProvider.future);
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const _FilterBar(),
              const SizedBox(height: 80),
              ErrorRetry(
                message: l.genericError,
                onRetry: () => ref.invalidate(leaderboardProvider),
              ),
            ]),
            data: (view) => _LeaderboardBody(view),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody(this.view);
  final LeaderboardView view;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return CenteredMaxWidth(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const _FilterBar(),
          if (view.myRank > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                // MISSING-ARB: 'Hạng của bạn: #{n}' / 'Your rank: #{n}'
                'Hạng của bạn: #${view.myRank}',
                style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: cs.primary),
              ),
            ),
          if (view.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 40, 16, 16),
              // MISSING-ARB: 'Chưa có dữ liệu xếp hạng.'
              child: Center(child: Text('Chưa có dữ liệu xếp hạng.')),
            )
          else
            for (var i = 0; i < view.rows.length; i++)
              _RankRow(row: view.rows[i], position: i + 1, myRank: view.myRank),
        ],
      ),
    );
  }
}

/// Scope tabs (week/month) + district dropdown, all driven by the state
/// providers so a change re-runs [leaderboardProvider].
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(leaderboardScopeProvider);
    final district = ref.watch(leaderboardDistrictProvider);
    final async = ref.watch(leaderboardProvider);
    final districts = async.valueOrNull?.districts ?? const <String>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          SegmentedButton<String>(
            segments: const [
              // MISSING-ARB: 'Tuần' / 'Week', 'Tháng' / 'Month'
              ButtonSegment(value: 'week', label: Text('Tuần')),
              ButtonSegment(value: 'month', label: Text('Tháng')),
            ],
            selected: {scope},
            showSelectedIcon: false,
            onSelectionChanged: (s) =>
                ref.read(leaderboardScopeProvider.notifier).state = s.first,
          ),
          const Spacer(),
          Flexible(
            child: DropdownButton<String?>(
              value: district,
              isExpanded: true,
              // MISSING-ARB: 'Toàn quốc' / 'Nationwide'
              hint: const Text('Toàn quốc'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                    value: null, child: Text('Toàn quốc')),
                for (final d in districts)
                  DropdownMenuItem<String?>(value: d, child: Text(d)),
              ],
              onChanged: (d) =>
                  ref.read(leaderboardDistrictProvider.notifier).state = d,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.row, required this.position, required this.myRank});
  final LeaderboardRow row;
  final int position;
  final int myRank;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSelf = myRank > 0 && row.rank == myRank;
    final medal = switch (position) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => null };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isSelf ? cs.primaryContainer : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSelf ? cs.primary : cs.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Text(medal, style: const TextStyle(fontSize: 22))
                : Text('$position',
                    textAlign: TextAlign.center,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(row.name ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        // MISSING-ARB: 'Bạn' / 'You'
                        child: Text('Bạn',
                            style: tt.labelSmall?.copyWith(
                                color: cs.onPrimary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                Text(
                  '${_tierIcon(row.tier)} ${row.district ?? '—'}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatVnd(row.revenueVnd),
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(
                // MISSING-ARB: '{n} đơn' / '{n} jobs'
                '${row.jobs} đơn',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _tierIcon(String? tier) {
  switch (tier) {
    case 'platinum':
      return '💎';
    case 'gold':
      return '🥇';
    case 'silver':
      return '🥈';
    case 'bronze':
      return '🥉';
    default:
      return '•';
  }
}
