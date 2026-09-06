import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'provider_compliance_providers.dart';

/// Discipline thresholds mirrored from the web `lib/provider-discipline.ts`.
/// The mobile `/provider/cancellations` payload carries [CancellationsView.
/// countInWindow] (30-day count) but NOT the consecutive-cancel counter, so
/// only the count-in-window suspension warnings are derived here.
const int _kSoftSuspend7d = 5;
const int _kSoftSuspend30d = 8;

/// `/p/cancellations` (A6) — the provider's cancellation history. Unlike fines
/// this is scored in POINTS, not money: a penaltyScore total plus a 30-day
/// count, per-row penalty points, and suspension warnings derived from the
/// window count. No money, no writes.
class ProviderCancellationsScreen extends ConsumerWidget {
  const ProviderCancellationsScreen({super.key});

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
            await ref.read(cancellationsProvider.future);
          },
          child: CenteredMaxWidth(
            maxWidth: 720,
            child: view.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 120),
                ErrorRetry(
                  message: l.homeLoadError(e.toString()),
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
    final count = view.countInWindow;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                // TODO-i18n: "Huỷ trong 30 ngày" tile label (no ARB key).
                label: 'Huỷ trong 30 ngày',
                value: '$count',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                // TODO-i18n: "Điểm phạt" penalty-score tile label (no ARB key).
                label: 'Điểm phạt',
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
            // TODO-i18n: 30-day suspension warning (no ARB key).
            title: 'Sắp bị tạm khoá 30 ngày',
            body: 'Bạn đã huỷ $count lần trong 30 ngày. '
                'Đạt $_kSoftSuspend30d lần sẽ bị tạm khoá 30 ngày.',
          )
        else if (count >= _kSoftSuspend7d - 1)
          _WarnBanner(
            severe: false,
            // TODO-i18n: 7-day suspension warning (no ARB key).
            title: 'Sắp bị tạm khoá 7 ngày',
            body: 'Bạn đã huỷ $count lần trong 30 ngày. '
                'Đạt $_kSoftSuspend7d lần sẽ bị tạm khoá 7 ngày.',
          ),
        // TODO-i18n: "Lịch sử huỷ" history header (no ARB key).
        SectionHeader('Lịch sử huỷ'),
        if (view.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: EmptyState(message: AppLocalizations.of(context).noResults),
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
                    // TODO-i18n: "Đơn #{id}" booking label (no ARB key).
                    c.bookingId != null ? 'Đơn #${c.bookingId}' : 'Đơn #—',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  // reasonCode is a backend enum — shown raw (server-derived).
                  Text(c.reasonCode ?? '—',
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
                    Text(_shortDateTime(c.createdAt!),
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
              // TODO-i18n: "+{n} điểm" penalty-points pill (no ARB key).
              child: Text('+${c.penaltyScore ?? 0} điểm',
                  style: TextStyle(
                      color: cs.error, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Best-effort ISO → `dd/MM/yyyy HH:mm`; falls back to the first 16 chars.
String _shortDateTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso.length >= 16 ? iso.substring(0, 16) : iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
}
