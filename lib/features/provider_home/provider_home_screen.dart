import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'provider_home_providers.dart';

// TODO-i18n: this screen needs prov* home keys that the WF foundation did not
// add (only the tab/section-title keys exist). The VI literals below are lifted
// verbatim from the web `lib/i18n/sweep/provider.ts` (`prov.home.*`, `prov.kpi.*`,
// `prov.status.*`) so the integration pass can key them 1:1. See the unit report
// for the full missing-key list.

/// `/p` — the provider (CTV) dashboard. Mirrors the web `/provider` home, fully
/// API-backed from `providerWorkspace()` (single hop): greeting, KPI row (30d),
/// earnings + balance 💰 (display-only, server-derived), job counters, and the
/// Today / Upcoming job lists (tap → `/p/jobs/:id`). Pull-to-refresh refetches.
class ProviderHomeScreen extends ConsumerWidget {
  const ProviderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);

    // The shell already gates `/p` to signed-in providers; this is a defensive
    // fallback (and drives the "guest" golden) so the screen never renders a
    // dashboard for an anonymous session.
    if (auth.status != AuthStatus.signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.provHomeTitle)),
        body: _SignInRequired(message: l.provSignInRequired),
      );
    }

    final async = ref.watch(providerWorkspaceProvider);
    final firstName = _firstName(auth.user?.name);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(providerWorkspaceProvider);
            await ref.read(providerWorkspaceProvider.future);
          },
          child: async.when(
            loading: () => const _ScrollableCenter(child: CircularProgressIndicator()),
            error: (e, _) => _ScrollableCenter(
              child: ErrorRetry(
                message: l.genericError,
                onRetry: () => ref.invalidate(providerWorkspaceProvider),
              ),
            ),
            data: (ws) => _Dashboard(workspace: ws, firstName: firstName),
          ),
        ),
      ),
    );
  }

  static String _firstName(String? full) {
    if (full == null || full.trim().isEmpty) return '';
    final parts = full.trim().split(RegExp(r'\s+'));
    return parts.last; // VN: given name is last — mirrors the web greeting.
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.workspace, required this.firstName});
  final ProviderWorkspace workspace;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    final d = workspace.dashboard;
    final (today, upcoming) = _splitJobs(workspace.jobs.items);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── header ────────────────────────────────────────────────────────
        Text(
          firstName.isEmpty ? 'Xin chào' : 'Xin chào, $firstName', // prov.home.greeting
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Quản lý công việc, theo dõi thu nhập, và tận dụng giờ cao điểm.', // prov.home.subtitle
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),

        // ── KPI row (30d) ─────────────────────────────────────────────────
        _CapsLabel('KPI 30 ngày qua'), // prov.home.kpi_30d
        const SizedBox(height: 8),
        _KpiGrid(kpi: d.kpi),
        const SizedBox(height: 20),

        // ── earnings + balance 💰 (display-only, server-derived) ──────────
        _EarningsCard(earnings: d.earnings),
        const SizedBox(height: 20),

        // ── job counters ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: _StatTile(label: 'Đang làm', value: '${d.jobs.active}')), // prov.home.stat_active
            const SizedBox(width: 12),
            Expanded(child: _StatTile(label: 'Tổng', value: '${d.jobs.total}')), // prov.home.stat_total
          ],
        ),
        const SizedBox(height: 12),

        // ── today ─────────────────────────────────────────────────────────
        SectionHeader('Hôm nay'), // prov.home.today
        if (today.isEmpty)
          const _EmptyLine('Không có lịch hôm nay. Tận hưởng ngày nghỉ ☕.') // prov.home.today_empty
        else
          for (final j in today) _JobTile(job: j, showDuration: true),
        const SizedBox(height: 8),

        // ── upcoming ──────────────────────────────────────────────────────
        SectionHeader(
          'Sắp tới', // prov.home.upcoming
          trailing: TextButton(
            onPressed: () => context.push('/p/jobs'),
            child: const Text('Xem tất cả →'), // prov.home.see_all
          ),
        ),
        if (upcoming.isEmpty)
          const _EmptyLine('Chưa có lịch sắp tới.') // prov.home.upcoming_empty
        else
          for (final j in upcoming) _JobTile(job: j, showDuration: false),
      ],
    );
  }

  /// Web parity: "today" = scheduled within ±12h of now; "upcoming" = later than
  /// now+12h, soonest first, capped at 5. Jobs with no `scheduledAt` are omitted
  /// from both buckets (they still appear in the full `/p/jobs` list).
  static (List<ProviderJob>, List<ProviderJob>) _splitJobs(List<ProviderJob> jobs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    const window = 12 * 3600 * 1000;
    final today = <ProviderJob>[];
    final upcoming = <ProviderJob>[];
    for (final j in jobs) {
      final ms = _ms(j.scheduledAt);
      if (ms == null) continue;
      if (ms >= now - window && ms <= now + window) {
        today.add(j);
      } else if (ms > now + window) {
        upcoming.add(j);
      }
    }
    upcoming.sort((a, b) => (_ms(a.scheduledAt) ?? 0).compareTo(_ms(b.scheduledAt) ?? 0));
    return (today, upcoming.take(5).toList(growable: false));
  }

  static int? _ms(String? iso) =>
      (iso == null || iso.isEmpty) ? null : DateTime.tryParse(iso)?.millisecondsSinceEpoch;
}

// ── KPI ─────────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpi});
  final Map<String, dynamic> kpi;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _kpiCard('🎯', 'Nhận job', _pct(_entry('acceptance')['rate']), _tone('acceptance')), // prov.kpi.acceptance_label
      _kpiCard('✅', 'Hoàn thành', _pct(_entry('completion')['rate']), _tone('completion')), // prov.kpi.completion_label
      _kpiCard('⭐', 'Đánh giá', _rating(_entry('rating')['value']), _tone('rating')), // prov.kpi.rating_label
      _kpiCard('⏰', 'Đúng giờ', _pct(_entry('punctuality')['rate']), _tone('punctuality')), // prov.kpi.punctuality_label
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.9,
      children: cards,
    );
  }

  Map<String, dynamic> _entry(String k) =>
      kpi[k] is Map ? Map<String, dynamic>.from(kpi[k] as Map) : const {};
  String? _tone(String k) => _entry(k)['tone']?.toString();

  static String _pct(dynamic rate) {
    final r = (rate as num?)?.toDouble() ?? 0;
    return '${(r * 100).round()}%';
  }

  static String _rating(dynamic value) {
    final v = (value as num?)?.toDouble() ?? 0;
    return '${v.toStringAsFixed(2)}★';
  }

  Widget _kpiCard(String emoji, String label, String display, String? tone) =>
      _KpiCard(emoji: emoji, label: label, display: display, tone: tone);
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.emoji,
    required this.label,
    required this.display,
    required this.tone,
  });
  final String emoji;
  final String label;
  final String display;
  final String? tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = _toneColors(tone, cs);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const Spacer(),
              Text(display,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: fg)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              )),
        ],
      ),
    );
  }
}

/// Web tones: emerald (good) / amber (warn) / rose (bad). Fixed tints so the
/// signal reads the same in light and dark, matching the web KPI cards.
(Color, Color) _toneColors(String? tone, ColorScheme cs) {
  switch (tone) {
    case 'good':
      return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    case 'warn':
      return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
    case 'bad':
      return (const Color(0xFFFFE4E6), const Color(0xFFBE123C));
    default:
      return (cs.surfaceContainerHighest, cs.onSurfaceVariant);
  }
}

// ── earnings ──────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnings});
  final ProviderEarnings earnings;

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
          Text('THU NHẬP THÁNG', // prov.home.earnings_30d (server: monthVnd)
              style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant, letterSpacing: 0.6, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(formatVnd(earnings.monthVnd),
              style: tt.headlineMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MoneyRow(icon: '💰', label: 'Số dư ví', vnd: earnings.balanceVnd), // prov balance
              ),
              Expanded(
                child: _MoneyRow(icon: '📈', label: 'Luỹ kế', vnd: earnings.lifetimeVnd), // lifetime
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.icon, required this.label, required this.vnd});
  final String icon;
  final String label;
  final int vnd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$icon $label',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(formatVnd(vnd),
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── stat tile ────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant, letterSpacing: 0.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// ── job tile ────────────────────────────────────────────────────────────

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.showDuration});
  final ProviderJob job;
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = job.serviceName ?? 'Booking #${job.bookingId ?? job.jobId}';
    final when = _fmtWhen(job.scheduledAt);
    final line2 = showDuration
        ? [when, '${job.durationMinutes ?? 60} phút'].where((s) => s.isNotEmpty).join(' · ')
        : when;
    final address = [job.addressLine, job.ward, job.district]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return InkWell(
      onTap: () => context.push('/p/jobs/${job.jobId}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (job.confirmationCode != null) ...[
                        const SizedBox(width: 6),
                        Text(job.confirmationCode!,
                            style: tt.labelSmall?.copyWith(
                                fontFeatures: const [], color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                  if (line2.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(line2, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusChip(job.jobStatus),
                const SizedBox(height: 4),
                Text(formatVnd(job.totalVnd ?? 0),
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// TZ-independent, deterministic date/time (UTC components) so the same
  /// payload renders the same pixels regardless of the host timezone.
  static String _fmtWhen(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final u = dt.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(u.day)}/${two(u.month)}/${u.year} ${two(u.hour)}:${two(u.minute)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String? status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // prov.status.* labels + web tint mapping.
    final (label, bg, fg) = switch (status) {
      'pending' => ('đang chờ', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      'active' => ('đang làm', const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      'closed' => ('đã đóng', cs.surfaceContainerHighest, cs.onSurfaceVariant),
      _ => (status ?? '', cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ── small helpers ─────────────────────────────────────────────────────────

class _CapsLabel extends StatelessWidget {
  const _CapsLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: cs.onSurfaceVariant, letterSpacing: 0.6, fontWeight: FontWeight.w700));
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 160),
          Center(child: child),
        ],
      );
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/login?from=/p'),
              child: Text(AppLocalizations.of(context).login),
            ),
          ],
        ),
      ),
    );
  }
}
