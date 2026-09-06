import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../../theme/app_semantics.dart';
import '../auth/auth_controller.dart';
import 'provider_jobs_providers.dart';

// ── i18n gap (report) ────────────────────────────────────────────────────────
// These provider-jobs strings have no ARB key yet (l10n is frozen for this
// unit). They are inlined as Vietnamese literals — the app's default locale —
// and reported so the l10n unit can lift them into app_{vi,en}.arb. Existing
// keys reused: provJobsTitle, provJobsAssigned, provJobsAvailable,
// provSignInRequired, retry.
const _kJobStatusPending = 'Chờ xác nhận'; // provJobStatusPending
const _kJobStatusActive = 'Đang làm'; // provJobStatusActive
const _kJobStatusClosed = 'Đã đóng'; // provJobStatusClosed
const _kNetHint = '≈ 80% về bạn'; // provJobNetHint (rate label, not an amount)
const _kAssignedEmpty = 'Chưa có công việc nào'; // provJobsAssignedEmpty
const _kPoolEmpty = 'Hiện chưa có đơn nào để nhận'; // provPoolEmpty
const _kJobsLoadError = 'Không tải được công việc'; // provJobsLoadError
const _kPoolSectionAvailable = 'Đơn có thể nhận'; // provPoolAvailable
const _kPoolSectionAssigned = 'Đơn của bạn'; // provPoolAssigned
const _kClaimAction = 'Nhận đơn'; // provClaimAction
const _kClaimGateTitle = 'Bạn chưa thể nhận đơn'; // provClaimGateTitle
const _kClaimGateBody = 'Tài khoản của bạn đang bị tạm hạn chế nhận đơn.'; // provClaimGateBody
const _kClaimSuccess = 'Đã nhận đơn'; // provClaimSuccess
const _kClaimError = 'Không nhận được đơn, vui lòng thử lại'; // provClaimError

String _jobStatusLabel(String? status) => switch (status) {
      'pending' => _kJobStatusPending,
      'active' => _kJobStatusActive,
      'closed' => _kJobStatusClosed,
      _ => status ?? '',
    };

/// `/p/jobs` — the provider's jobs surface: two tabs, each API-backed with
/// pull-to-refresh. "Assigned" is the provider's own pipeline (`providerJobs()`,
/// cursor-paged); "Available" is the shared claimable pool (`poolJobs()`) with
/// the `canClaim` gate. Money is display-only (server `totalVnd`); the claim
/// action never sends an amount.
class ProviderJobsScreen extends ConsumerWidget {
  const ProviderJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn = ref.watch(authControllerProvider).status == AuthStatus.signedIn;

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.provJobsTitle)),
        body: _SignInPrompt(message: l.provSignInRequired),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.provJobsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l.provJobsAssigned),
              Tab(text: l.provJobsAvailable),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: TabBarView(
            children: const [
              _AssignedTab(),
              _AvailableTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.message});
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
            Icon(Icons.work_outline, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ── Assigned tab (cursor-paged) ──────────────────────────────────────────────

class _AssignedTab extends ConsumerStatefulWidget {
  const _AssignedTab();
  @override
  ConsumerState<_AssignedTab> createState() => _AssignedTabState();
}

class _AssignedTabState extends ConsumerState<_AssignedTab> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      ref.read(assignedJobsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(assignedJobsControllerProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(assignedJobsControllerProvider);
        await ref.read(assignedJobsControllerProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 120),
          ErrorRetry(
            message: _kJobsLoadError,
            onRetry: () => ref.invalidate(assignedJobsControllerProvider),
          ),
        ]),
        data: (data) => data.items.isEmpty
            ? ListView(children: const [
                SizedBox(height: 80),
                EmptyState(icon: '🧹', message: _kAssignedEmpty),
              ])
            : ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: data.items.length + (data.hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i >= data.items.length) {
                    return _LoadMoreFooter(
                      loading: data.loadingMore,
                      onLoadMore: () =>
                          ref.read(assignedJobsControllerProvider.notifier).loadMore(),
                    );
                  }
                  final job = data.items[i];
                  return _AssignedJobTile(
                    job,
                    onTap: () => context.push('/p/jobs/${job.jobId}'),
                  );
                },
              ),
      ),
    );
  }
}

class _AssignedJobTile extends StatelessWidget {
  const _AssignedJobTile(this.job, {required this.onTap});
  final ProviderJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = job.serviceName ?? job.confirmationCode ?? '#${job.bookingId ?? job.jobId}';
    final where = [job.addressLine, job.ward, job.district].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final subtitle = [if ((job.scheduledAt ?? '').isNotEmpty) job.scheduledAt!, if (where.isNotEmpty) where].join('\n');
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        isThreeLine: subtitle.contains('\n'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _JobStatusChip(job.jobStatus),
            const SizedBox(height: 6),
            _MoneyValue(job.totalVnd),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        iconColor: cs.onSurfaceVariant,
      ),
    );
  }
}

class _JobStatusChip extends StatelessWidget {
  const _JobStatusChip(this.status);
  final String? status;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.semantics;
    final (bg, fg) = switch (status) {
      'active' => (sem.successContainer, sem.onSuccessContainer),
      'pending' => (sem.warningContainer, sem.onWarningContainer),
      'closed' => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      _ => (cs.errorContainer, cs.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(_jobStatusLabel(status),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
    );
  }
}

/// 💰 + server-derived VND total. Display-only — no amount is ever computed.
class _MoneyValue extends StatelessWidget {
  const _MoneyValue(this.vnd);
  final int? vnd;
  @override
  Widget build(BuildContext context) {
    if (vnd == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('💰', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 4),
        PriceText(vnd!, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loading, required this.onLoadMore});
  final bool loading;
  final VoidCallback onLoadMore;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : OutlinedButton(onPressed: onLoadMore, child: Text(AppLocalizations.of(context).retry)),
      ),
    );
  }
}

// ── Available (pool) tab ─────────────────────────────────────────────────────

class _AvailableTab extends ConsumerWidget {
  const _AvailableTab();

  Future<void> _claim(BuildContext context, WidgetRef ref, int jobId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(kycoApiProvider).claimJob(jobId);
      messenger.showSnackBar(const SnackBar(content: Text(_kClaimSuccess)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(_kClaimError)));
    }
    // Refresh both surfaces — the claimed job leaves the pool and enters the
    // assigned pipeline / list.
    ref.invalidate(poolProvider);
    ref.invalidate(assignedJobsControllerProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(poolProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(poolProvider);
        await ref.read(poolProvider.future);
      },
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 120),
          ErrorRetry(message: _kJobsLoadError, onRetry: () => ref.invalidate(poolProvider)),
        ]),
        data: (view) {
          final empty = view.pool.isEmpty && view.assigned.isEmpty;
          if (empty && view.canClaim) {
            return ListView(children: const [
              SizedBox(height: 80),
              EmptyState(icon: '🧺', message: _kPoolEmpty),
            ]);
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (!view.canClaim) _ClaimGateBanner(reason: view.banReason),
              if (view.assigned.isNotEmpty) ...[
                SectionHeader('$_kPoolSectionAssigned (${view.assigned.length})'),
                for (final job in view.assigned)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: _AssignedPoolTile(
                      job,
                      onTap: () => context.push('/p/jobs/${job.jobId}'),
                    ),
                  ),
              ],
              SectionHeader('$_kPoolSectionAvailable (${view.pool.length})'),
              if (view.pool.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyState(icon: '🧺', message: _kPoolEmpty),
                )
              else
                for (final job in view.pool)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: _ClaimCard(
                      job,
                      canClaim: view.canClaim,
                      onClaim: () => _claim(context, ref, job.jobId),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

/// Ban / suspend gate — mirrors the web's banned/suspended banner. Shown when
/// the server reports `canClaim == false`; claim buttons render disabled.
class _ClaimGateBanner extends StatelessWidget {
  const _ClaimGateBanner({this.reason});
  final String? reason;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final body = (reason != null && reason!.isNotEmpty) ? reason! : _kClaimGateBody;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        border: Border.all(color: cs.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, color: cs.onErrorContainer, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_kClaimGateTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: cs.onErrorContainer, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A read-only tile for the provider's own assigned pipeline (already theirs —
/// no claim action). Taps through to the job detail hub.
class _AssignedPoolTile extends StatelessWidget {
  const _AssignedPoolTile(this.job, {required this.onTap});
  final PoolJob job;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final title = job.serviceName ?? job.confirmationCode ?? '#${job.bookingId ?? job.jobId}';
    final where = [job.addressLine, job.ward, job.district].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final subtitle = [if ((job.scheduledAt ?? '').isNotEmpty) job.scheduledAt!, if (where.isNotEmpty) where].join('\n');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
        isThreeLine: subtitle.contains('\n'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _JobStatusChip(job.jobStatus),
            const SizedBox(height: 6),
            _MoneyValue(job.totalVnd),
          ],
        ),
      ),
    );
  }
}

/// Quick-claim card. Shows the service, when/where, the server-derived VND
/// total (💰) and a rate hint (`≈ 80% về bạn`) — the net is never computed in
/// the app. "Claim" calls `claimJob(id)` (no amount) and is disabled when the
/// server gate (`canClaim`) is closed.
class _ClaimCard extends StatelessWidget {
  const _ClaimCard(this.job, {required this.canClaim, required this.onClaim});
  final PoolJob job;
  final bool canClaim;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = job.serviceName ?? '#${job.bookingId ?? job.jobId}';
    final where = [job.addressLine, job.ward, job.district].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if ((job.scheduledAt ?? '').isNotEmpty || job.durationMinutes != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if ((job.scheduledAt ?? '').isNotEmpty) job.scheduledAt!,
                            if (job.durationMinutes != null) '${job.durationMinutes} phút',
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                      if (where.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(where, style: const TextStyle(fontSize: 13)),
                      ],
                      if ((job.notes ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('"${job.notes}"',
                            style: TextStyle(
                                fontSize: 12, fontStyle: FontStyle.italic, color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MoneyValue(job.totalVnd),
                    const SizedBox(height: 2),
                    Text(_kNetHint, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: canClaim ? onClaim : null,
                icon: const Icon(Icons.add_task, size: 18),
                label: const Text(_kClaimAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
