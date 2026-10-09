import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'provider_compliance_providers.dart';

/// `/p/fines` (A3 💰) — the provider's penalty ledger. Three VND summary tiles
/// (pending / charged / refunded) over a per-fine history list; tapping a
/// non-refunded fine opens its appeal screen. MONEY IS DISPLAY-ONLY — nothing
/// on this screen sends a computed amount.
class ProviderFinesScreen extends ConsumerWidget {
  const ProviderFinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fines = ref.watch(finesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.provFinesTitle)),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(finesProvider);
            await ref.read(finesProvider.future);
          },
          child: CenteredMaxWidth(
            maxWidth: 720,
            child: fines.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 120),
                ErrorRetry(
                  message: l.homeLoadError(e.toString()),
                  onRetry: () => ref.invalidate(finesProvider),
                ),
              ]),
              data: (view) => _FinesBody(view),
            ),
          ),
        ),
      ),
    );
  }
}

class _FinesBody extends StatelessWidget {
  const _FinesBody(this.view);
  final FinesView view;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryTile(
                label: l.provFinesPending,
                vnd: view.totalPendingVnd,
                tone: _FineTone.pending.color(cs),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                label: l.provFinesDeducted,
                vnd: view.totalChargedVnd,
                tone: _FineTone.charged.color(cs),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryTile(
                label: l.provFinesRefunded,
                vnd: view.totalRefundedVnd,
                tone: _FineTone.refunded.color(cs),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SectionHeader(l.provFinesHistory),
        if (view.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: EmptyState(message: l.noResults),
          )
        else
          for (final f in view.rows) _FineRow(f),
      ],
    );
  }
}

/// Colour tone per fine status, mirroring the web's amber/rose/emerald.
enum _FineTone {
  pending,
  charged,
  refunded;

  Color color(ColorScheme cs) => switch (this) {
        _FineTone.pending => const Color(0xFFB45309), // amber-700
        _FineTone.charged => cs.error,
        _FineTone.refunded => const Color(0xFF047857), // emerald-700
      };

  static _FineTone of(String? status) => switch (status) {
        'refunded' => _FineTone.refunded,
        'charged' => _FineTone.charged,
        _ => _FineTone.pending,
      };
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.vnd, required this.tone});
  final String label;
  final int vnd;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
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
          Text(formatVnd(vnd),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: tone,
              )),
        ],
      ),
    );
  }
}

class _FineRow extends StatelessWidget {
  const _FineRow(this.fine);
  final Fine fine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final tone = _FineTone.of(fine.status);
    final canAppeal = fine.status != 'refunded';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Refunded fines are terminal — no appeal affordance (matches web).
        onTap: canAppeal ? () => context.push('/p/fines/${fine.id}/appeal') : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // kind / reason are backend enums — shown raw (server-derived).
                    Text(fine.kind ?? '—',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if ((fine.reason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(fine.reason!,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ],
                    if ((fine.createdAt ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(_shortDateTime(fine.createdAt!),
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('-${formatVnd(fine.amountVnd)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: cs.error,
                      )),
                  const SizedBox(height: 6),
                  _StatusPill(status: fine.status, tone: tone.color(cs)),
                  if (canAppeal) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.provFineAppealAction,
                            style: TextStyle(
                                color: cs.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Icon(Icons.chevron_right, size: 16, color: cs.primary),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.tone});
  final String? status;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      // status is a backend enum — displayed raw (no localized mapping in ARB).
      child: Text(status ?? '—',
          style: TextStyle(color: tone, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

/// Best-effort ISO → `dd/MM/yyyy HH:mm`; falls back to the first 16 chars.
String _shortDateTime(String iso) {
  // Server timestamps are UTC ISO strings — render in the device's local zone.
  final dt = DateTime.tryParse(iso)?.toLocal();
  if (dt == null) return iso.length >= 16 ? iso.substring(0, 16) : iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
