import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'tasker_compliance_providers.dart';
import 'package:kyco_mobile/core/datetime.dart';
import 'package:kyco_mobile/core/labels.dart';

/// Discipline thresholds mirrored from the web `lib/tasker-discipline.ts`.
/// The mobile `/tasker/cancellations` payload carries [CancellationsView.
/// countInWindow] (30-day count) but NOT the consecutive-cancel counter, so
/// only the count-in-window suspension warnings are derived here.
const int _kSoftSuspend7d = 5;
const int _kSoftSuspend30d = 8;

/// `/p/cancellations` (A6) — the tasker's cancellation history. Unlike fines
/// this is scored in POINTS, not money: a penaltyScore total plus a 30-day
/// count, per-row penalty points, and suspension warnings derived from the
/// window count. No money, no writes.
class TaskerCancellationsScreen extends ConsumerWidget {
  const TaskerCancellationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(cancellationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.provCancellationsTitle)),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cancellationsProvider);
            await refreshQuietly(ref.read(cancellationsProvider.future));
          },
          child: CenteredMaxWidth(
            maxWidth: 720,
            child: view.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 120),
                ErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(cancellationsProvider),
                ),
              ]),
              data: (data) => _Body(data),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.view);
  final CancellationsView view;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final count = view.countInWindow;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: l.provCancels30d,
                value: '$count',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: l.provCancelsPenaltyPoints,
                value: '${view.penaltyScore}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Suspension warnings, most severe first.
        if (count >= _kSoftSuspend30d - 1)
          _WarnBanner(
            severe: true,
            title: l.provCancelsSuspend30Title,
            body: l.provCancelsSuspend30Body(count, _kSoftSuspend30d),
          )
        else if (count >= _kSoftSuspend7d - 1)
          _WarnBanner(
            severe: false,
            title: l.provCancelsSuspend7Title,
            body: l.provCancelsSuspend7Body(count, _kSoftSuspend7d),
          ),
        SectionHeader(l.provCancelsHistory),
        if (view.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: EmptyState(message: l.noResults),
          )
        else
          for (final c in view.rows) _CancellationRow(c),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              )),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _WarnBanner extends StatelessWidget {
  const _WarnBanner({required this.severe, required this.title, required this.body});
  final bool severe;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tone = severe ? cs.error : const Color(0xFFB45309); // rose / amber-700
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.5), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontWeight: FontWeight.w700, color: tone)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(fontSize: 13, color: tone)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CancellationRow extends StatelessWidget {
  const _CancellationRow(this.c);
  final Cancellation c;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.bookingId != null
                        ? l.bookingNumber(c.bookingId!)
                        : l.provOrderNoNumber,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(cancelReasonLabel(l, c.reasonCode),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  if ((c.reasonText ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('"${c.reasonText}"',
                        style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: cs.onSurfaceVariant,
                            fontSize: 12)),
                  ],
                  if ((c.createdAt ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(vnDateTime(context, c.createdAt),
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(l.provCancelsPoints(c.penaltyScore ?? 0),
                  style: TextStyle(
                      color: cs.error, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
