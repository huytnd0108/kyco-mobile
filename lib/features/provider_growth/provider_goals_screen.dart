import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'provider_growth_providers.dart';

/// `/p/goals` — weekly + monthly job + income targets with progress bars, and an
/// edit sheet that PUTs the chosen targets (`setGoal`). The income figure is the
/// provider's own *target*, never a computed payout.
class ProviderGoalsScreen extends ConsumerWidget {
  const ProviderGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.provGoalsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(goalsProvider);
            await ref.read(goalsProvider.future);
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 120),
              ErrorRetry(
                message: l.genericError,
                onRetry: () => ref.invalidate(goalsProvider),
              ),
            ]),
            data: (data) => _GoalsBody(data),
          ),
        ),
      ),
    );
  }
}

class _GoalsBody extends ConsumerWidget {
  const _GoalsBody(this.data);
  final GoalsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final wKey = isoWeekKeyOf(now);
    final mKey = monthKeyOf(now);
    final weekGoal = data.forPeriod('week', wKey);
    final monthGoal = data.forPeriod('month', mKey);

    return CenteredMaxWidth(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SectionHeader('${l.provGoalsThisWeek} · $wKey'),
          _GoalCard(
            periodKind: 'week',
            periodKey: wKey,
            goal: weekGoal,
            achievedJobs: null, // no frozen weekly-achieved source
            achievedVnd: null,
          ),
          SectionHeader('${l.provGoalsThisMonth} · $mKey'),
          _GoalCard(
            periodKind: 'month',
            periodKey: mKey,
            goal: monthGoal,
            achievedJobs: null, // no frozen monthly job-count source
            achievedVnd: data.monthVndAchieved, // server-derived month income
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.periodKind,
    required this.periodKey,
    required this.goal,
    required this.achievedJobs,
    required this.achievedVnd,
  });

  final String periodKind;
  final String periodKey;
  final Goal? goal;
  final int? achievedJobs;
  final int? achievedVnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final targetJobs = goal?.targetJobs ?? 0;
    final targetVnd = goal?.targetVnd ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jobs target.
          _GoalMetric(
            label: l.provGoalJobs,
            achievedText: achievedJobs?.toString() ?? '—',
            targetText: targetJobs > 0 ? '$targetJobs' : '—',
            value: (achievedJobs ?? 0).toDouble(),
            max: targetJobs.toDouble(),
          ),
          const SizedBox(height: 14),
          // Income target (display-only VND).
          _GoalMetric(
            label: l.provGoalIncome,
            achievedText: achievedVnd != null ? formatVnd(achievedVnd!) : '—',
            targetText: targetVnd > 0 ? formatVnd(targetVnd) : '—',
            value: (achievedVnd ?? 0).toDouble(),
            max: targetVnd.toDouble(),
            tone: cs.tertiary,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(goal == null ? l.provGoalSet : l.provGoalEdit),
              onPressed: () => _openEditor(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_GoalDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalEditor(
        periodKey: periodKey,
        initialJobs: goal?.targetJobs ?? (periodKind == 'week' ? 15 : 60),
        initialVnd: goal?.targetVnd ?? (periodKind == 'week' ? 3000000 : 12000000),
      ),
    );
    if (result == null || !context.mounted) return;
    final l = AppLocalizations.of(context);
    final ok = await saveGoal(
      ref,
      periodKind: periodKind,
      periodKey: periodKey,
      targetJobs: result.jobs,
      targetVnd: result.vnd,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? l.provGoalSaved : l.genericError)),
    );
  }
}

class _GoalMetric extends StatelessWidget {
  const _GoalMetric({
    required this.label,
    required this.achievedText,
    required this.targetText,
    required this.value,
    required this.max,
    this.tone,
  });

  final String label;
  final String achievedText;
  final String targetText;
  final double value;
  final double max;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fraction = max > 0 ? (value / max).clamp(0.0, 1.0) : 0.0;
    final pct = max > 0 ? (fraction * 100).round() : null;
    final color = tone ?? cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: tt.bodySmall,
                  children: [
                    TextSpan(
                        text: '$label  ',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    TextSpan(
                        text: achievedText,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' / $targetText',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            if (pct != null)
              Text('$pct%',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _GoalDraft {
  const _GoalDraft(this.jobs, this.vnd);
  final int jobs;
  final int vnd;
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({
    required this.periodKey,
    required this.initialJobs,
    required this.initialVnd,
  });
  final String periodKey;
  final int initialJobs;
  final int initialVnd;

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late final TextEditingController _jobs =
      TextEditingController(text: '${widget.initialJobs}');
  late final TextEditingController _vnd =
      TextEditingController(text: '${widget.initialVnd}');

  @override
  void dispose() {
    _jobs.dispose();
    _vnd.dispose();
    super.dispose();
  }

  void _submit() {
    final jobs = int.tryParse(_jobs.text.trim()) ?? 0;
    final vnd = int.tryParse(_vnd.text.trim()) ?? 0;
    Navigator.of(context).pop(_GoalDraft(jobs.clamp(0, 500), vnd < 0 ? 0 : vnd));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${l.provGoalTitle} · ${widget.periodKey}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _jobs,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.provGoalTargetJobs,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vnd,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.provGoalTargetIncome,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            child: Text(l.provGoalSave),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.provGoalCancel),
          ),
        ],
      ),
    );
  }
}
