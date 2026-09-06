import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../../theme/app_semantics.dart';
import '../auth/auth_controller.dart';
import 'provider_wallet_providers.dart';
import 'wallet_export.dart';
import 'withdraw_sheet.dart';

/// `/p/wallet` — the provider wallet. Balance + lifetime/month/fee tiles, the
/// transaction ledger and payout history (both cursor-paged), a step-up-gated
/// withdraw flow, and a monthly CSV export. Every figure shown is server-derived
/// (💰); the app computes no fee, net, or balance and sends only the one
/// user-supplied payout amount, which the server validates + balance-checks.
class ProviderWalletScreen extends ConsumerWidget {
  const ProviderWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn =
        ref.watch(authControllerProvider).status == AuthStatus.signedIn;

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.provWalletTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l.provSignInRequired, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    return const _WalletBody();
  }
}

class _WalletBody extends ConsumerWidget {
  const _WalletBody();

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(walletSummaryProvider);
    ref.invalidate(walletTxnsControllerProvider);
    ref.invalidate(payoutsControllerProvider);
    await ref.read(walletSummaryProvider.future);
  }

  void _snack(ScaffoldMessengerState messenger, String? message) {
    if (message == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final summary = ref.watch(walletSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.provWalletTitle),
        actions: [
          IconButton(
            tooltip: 'Xuất CSV tháng này',
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              _snack(messenger, await exportWalletCsv(context, ref));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: summary.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 120),
              ErrorRetry(
                message: l.genericError,
                onRetry: () => ref.invalidate(walletSummaryProvider),
              ),
            ]),
            data: (s) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _BalanceCard(summary: s),
                const SizedBox(height: 16),
                _StatTiles(summary: s),
                const SizedBox(height: 16),
                _WithdrawCard(
                  balanceVnd: s.balanceVnd,
                  onWithdraw: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    _snack(messenger,
                        await runWithdrawFlow(context, ref, balanceVnd: s.balanceVnd));
                  },
                ),
                const SizedBox(height: 24),
                Text('Giao dịch',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const _TxnList(),
                const SizedBox(height: 24),
                Text('Lịch sử rút tiền',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Tiền được giữ và giải ngân theo lịch của Kyco.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                const _PayoutList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient balance hero — available balance + payout-schedule hint. 💰
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.summary});
  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final sem = context.semantics;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: sem.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SỐ DƯ KHẢ DỤNG',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(formatVnd(summary.balanceVnd),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.schedule, color: Colors.white70, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text('Giải ngân sau khi khách xác nhận, chuyển về tài khoản ngân hàng đã đăng ký.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Total-revenue / this-month / jobs / fee tiles — all server-derived. 💰
class _StatTiles extends StatelessWidget {
  const _StatTiles({required this.summary});
  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final sem = context.semantics;
    return Column(
      children: [
        // IntrinsicHeight bounds the Row's cross axis so equal-height stretch is
        // legal inside the vertically-unbounded ListView.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Tổng thu nhập',
                  value: formatVnd(summary.lifetimeEarningVnd),
                  valueColor: sem.onSuccessContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Tháng này',
                  value: formatVnd(summary.monthEarningVnd),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Số công việc',
                  value: '${summary.jobCount}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Phí đã trừ',
                  value: formatVnd(summary.lifetimeFeeVnd),
                  valueColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? cs.onSurface)),
        ],
      ),
    );
  }
}

/// Withdraw CTA — opens the step-up-gated payout flow. 💰
class _WithdrawCard extends StatelessWidget {
  const _WithdrawCard({required this.balanceVnd, required this.onWithdraw});
  final int balanceVnd;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canWithdraw = balanceVnd >= kPayoutMinVnd;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rút tiền về ngân hàng',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Yêu cầu rút tiền cần xác minh bảo mật để bảo vệ tài khoản.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (!canWithdraw)
            Text('Cần tối thiểu ${formatVnd(kPayoutMinVnd)} để rút tiền.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onWithdraw,
                icon: const Icon(Icons.account_balance),
                label: const Text('Rút tiền'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Transaction ledger — cursor-paged, with an inline load-more footer. 💰
class _TxnList extends ConsumerWidget {
  const _TxnList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(walletTxnsControllerProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _InlineError(
        onRetry: () => ref.invalidate(walletTxnsControllerProvider),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return EmptyState(icon: '🧾', message: l.noResults);
        }
        return Column(
          children: [
            for (final t in data.items) _TxnTile(t),
            if (data.hasMore)
              _LoadMoreFooter(
                loading: data.loadingMore,
                onLoadMore: () =>
                    ref.read(walletTxnsControllerProvider.notifier).loadMore(),
              ),
          ],
        );
      },
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile(this.txn);
  final WalletTxn txn;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = context.semantics;
    final isCredit = txn.type == 'credit';
    final amountColor = isCredit ? sem.onSuccessContainer : cs.error;
    final sign = isCredit ? '+' : '−';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(walletReasonLabel(txn.reason),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(formatWalletDate(context, txn.createdAt),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sign${formatVnd(txn.amountVnd)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: amountColor)),
              const SizedBox(height: 2),
              Text('Số dư ${formatVnd(txn.balanceAfterVnd)}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Payout history — held / released / withdrawn with status chips. 💰
class _PayoutList extends ConsumerWidget {
  const _PayoutList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(payoutsControllerProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _InlineError(
        onRetry: () => ref.invalidate(payoutsControllerProvider),
      ),
      data: (data) {
        if (data.items.isEmpty) {
          return EmptyState(icon: '💸', message: l.noResults);
        }
        return Column(
          children: [
            for (final p in data.items) _PayoutTile(p),
            if (data.hasMore)
              _LoadMoreFooter(
                loading: data.loadingMore,
                onLoadMore: () =>
                    ref.read(payoutsControllerProvider.notifier).loadMore(),
              ),
          ],
        );
      },
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile(this.payout);
  final Payout payout;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = payoutStatusLabel(payout.status);
    final when = payout.releasedAt ?? payout.createdAt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    payout.bookingId != null
                        ? 'Đơn #${payout.bookingId}'
                        : 'Rút tiền',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(formatWalletDate(context, when),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatVnd(payout.amountVnd),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              _StatusChip(label: status.label, tone: status.tone),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.tone});
  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final sem = context.semantics;
    final (bg, fg) = switch (tone) {
      'success' => (sem.successContainer, sem.onSuccessContainer),
      'info' => (sem.infoContainer, sem.onInfoContainer),
      'error' => (
          Theme.of(context).colorScheme.errorContainer,
          Theme.of(context).colorScheme.onErrorContainer
        ),
      _ => (sem.warningContainer, sem.onWarningContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(l.genericError,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l.retry),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loading, required this.onLoadMore});
  final bool loading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(onPressed: onLoadMore, child: Text(l.loadMore)),
      ),
    );
  }
}
