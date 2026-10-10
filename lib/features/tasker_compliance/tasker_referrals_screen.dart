import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/adaptive.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'tasker_compliance_providers.dart';
import 'package:kyco_mobile/core/labels.dart';

/// `/p/referrals` (A5 ) — the tasker's own referral code, a share affordance
/// (share_plus), the approximate earned-extra total, and a table of referred
/// partners. Money is DISPLAY-ONLY and, per the web + model docstring, the
/// earnedExtra figure is a documented APPROXIMATION (labelled as such).
class TaskerReferralsScreen extends ConsumerWidget {
  const TaskerReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final view = ref.watch(referralsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.provReferralsTitle)),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(referralsProvider);
            await refreshQuietly(ref.read(referralsProvider.future));
          },
          child: CenteredMaxWidth(
            maxWidth: 720,
            child: view.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 120),
                ErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(referralsProvider),
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
  final ReferralsView view;

  static String _shareUrl(String code) =>
      'https://kyco.vn/become-tasker?ref=$code';

  int _countByStatus(String status) =>
      view.referrals.where((r) => r.status == status).length;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final code = view.referralCode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (code == null || code.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: EmptyState(message: l.provReferralsNoCode, icon: Icons.card_giftcard),
          )
        else ...[
          _CodeCard(code: code, shareUrl: _shareUrl(code)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: l.provReferralsActive,
                  value: '${_countByStatus('active')}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: l.provReferralsCompleted,
                  value: '${_countByStatus('completed')}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: l.provReferralsEarned,
                  value: formatVnd(view.earnedExtraVnd),
                  emphasize: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            // The web labels earnedExtra as approximate (sum of ALL payouts).
            l.provReferralsApproxNote,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        SectionHeader(l.provReferralsList),
        if (view.referrals.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: EmptyState(message: l.noResults),
          )
        else
          _ReferralsTable(view.referrals, program: view.program),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code, required this.shareUrl});
  final String code;
  final String shareUrl;

  Future<void> _share(String subject) async {
    await SharePlus.instance.share(
      ShareParams(text: shareUrl, subject: subject),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.provReferralsYourCode,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                )),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 20,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l.copyAction,
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: shareUrl));
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(l.copiedAction)));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(shareUrl,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _share(l.provReferralsShareSubject),
                icon: const Icon(Icons.share_outlined),
                label: Text(l.provReferralsShare),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

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
                fontSize: 9,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant,
              )),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: emphasize ? 15 : 22,
                fontWeight: FontWeight.w800,
                color: emphasize ? cs.primary : null,
              )),
        ],
      ),
    );
  }
}

class _ReferralsTable extends StatelessWidget {
  const _ReferralsTable(this.rows, {this.program});
  final List<Referral> rows;
  final Map<String, dynamic>? program;

  int get _quota {
    final v = program?['referrerRewardJobs'];
    return v is num ? v.toInt() : 100;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // Horizontal scroll keeps the table from overflowing narrow phones.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 560),
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
          columns: [
            DataColumn(label: Text(l.provReferralsColPartner)),
            DataColumn(label: Text(l.provReferralsColArea)),
            DataColumn(label: Text(l.provReferralsColTarget), numeric: true),
            DataColumn(label: Text(l.statusLabel)),
          ],
          rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(r.refereeName ?? '—')),
                DataCell(Text(r.refereeDistrict ?? '—')),
                DataCell(Text('${r.jobsDone ?? 0} / $_quota')),
                DataCell(_ReferralStatusChip(r.status)),
              ]),
          ],
        ),
      ),
    );
  }
}

class _ReferralStatusChip extends StatelessWidget {
  const _ReferralStatusChip(this.status);
  final String? status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (status) {
      'active' => (const Color(0xFFD1FAE5), const Color(0xFF047857)),
      'completed' => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
      'pending_kyc' => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      _ => (cs.errorContainer, cs.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(referralStatusLabel(AppLocalizations.of(context), status),
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
