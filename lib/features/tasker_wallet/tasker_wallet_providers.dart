import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

// Tasker wallet data plumbing — every read is a frozen kycoApiProvider money
// method (💰 server-derived). Nothing here computes a fee, net, or balance; the
// app only DISPLAYS server figures. The one user-supplied number is the payout
// amount, and even that is validated + balance-checked server-side.

/// Payout bounds mirrored from the web (`wallet-self-service-write.ts`) — used
/// ONLY for client-side hints. The SERVER is the source of truth: it re-checks
/// the range, whole-đồng integrality, and the live balance on every request.
const int kPayoutMinVnd = 100000;
const int kPayoutMaxVnd = 50000000;

/// Wallet summary (`GET /v1/tasker/wallet`) — balance + lifetime/month/fee
/// aggregates. All figures server-derived. 💰
final walletSummaryProvider = FutureProvider.autoDispose<WalletSummary>((ref) {
  return ref.watch(kycoApiProvider).taskerWallet();
});

/// The tasker's step-up posture (`GET /v1/auth/step-up`) — is a fresh grant
/// present, and can this account use a password (else OTP)? Never trusted as a
/// gate; the server re-checks on the payout POST. Fetched on demand (autoDispose
/// so a stale "fresh" never lingers between withdraw attempts).
final stepUpStatusProvider = FutureProvider.autoDispose<StepUpStatus>((ref) {
  return ref.watch(kycoApiProvider).stepUpStatus();
});

/// Accumulated cursor-paged data for a tasker-wallet list read.
class WalletTxnsData {
  const WalletTxnsData({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<WalletTxn> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;

  WalletTxnsData copyWith({
    List<WalletTxn>? items,
    String? nextCursor,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      WalletTxnsData(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Transaction ledger (`GET /v1/tasker/wallet/transactions`) with opaque
/// forward-cursor paging. 💰
final walletTxnsControllerProvider =
    AsyncNotifierProvider.autoDispose<WalletTxnsController, WalletTxnsData>(
        WalletTxnsController.new);

class WalletTxnsController extends AutoDisposeAsyncNotifier<WalletTxnsData> {
  KycoApi get _api => ref.read(kycoApiProvider);

  /// Set on dispose so a page fetch that resolves after the controller is gone
  /// never touches `state` (which would throw and surface as an unhandled async).
  bool _disposed = false;

  @override
  Future<WalletTxnsData> build() async {
    ref.onDispose(() => _disposed = true);
    final page = await _api.walletTxns();
    return WalletTxnsData(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  /// Append the next page. No-op when already loading, exhausted, or cursorless.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.loadingMore || !cur.hasMore || cur.nextCursor == null) {
      return;
    }
    final loading = cur.copyWith(loadingMore: true);
    state = AsyncData(loading);
    try {
      final page = await _api.walletTxns(cursor: cur.nextCursor);
      // Bail if the controller was disposed or a pull-refresh reset page 1 while
      // we awaited — never clobber fresh state with a stale append.
      if (_disposed || !identical(state.valueOrNull, loading)) return;
      // Rebuild explicitly (not copyWith) so a null `nextCursor` on the last
      // page is actually stored — copyWith's `?? this.nextCursor` would keep
      // the stale cursor. `hasMore` already rides along, but this makes the
      // exhausted state self-consistent and un-paginatable on its own.
      state = AsyncData(WalletTxnsData(
        items: [...cur.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // Keep the pages already shown; just drop the loading flag. Guard the
      // write: on a disposed notifier `state=` throws and would rethrow.
      if (_disposed) return;
      try {
        if (identical(state.valueOrNull, loading)) {
          state = AsyncData(cur.copyWith(loadingMore: false));
        }
      } catch (_) {}
    }
  }
}

/// Accumulated cursor-paged payouts.
class PayoutsData {
  const PayoutsData({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<Payout> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;

  PayoutsData copyWith({
    List<Payout>? items,
    String? nextCursor,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      PayoutsData(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Payout history (`GET /v1/tasker/payouts`) — held / released / withdrawn
/// rows with cursor paging. 💰
final payoutsControllerProvider =
    AsyncNotifierProvider.autoDispose<PayoutsController, PayoutsData>(
        PayoutsController.new);

class PayoutsController extends AutoDisposeAsyncNotifier<PayoutsData> {
  KycoApi get _api => ref.read(kycoApiProvider);

  /// Set on dispose so a page fetch that resolves after the controller is gone
  /// never touches `state` (which would throw and surface as an unhandled async).
  bool _disposed = false;

  @override
  Future<PayoutsData> build() async {
    ref.onDispose(() => _disposed = true);
    final page = await _api.payouts();
    return PayoutsData(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.loadingMore || !cur.hasMore || cur.nextCursor == null) {
      return;
    }
    final loading = cur.copyWith(loadingMore: true);
    state = AsyncData(loading);
    try {
      final page = await _api.payouts(cursor: cur.nextCursor);
      // Bail if the controller was disposed or a pull-refresh reset page 1 while
      // we awaited — never clobber fresh state with a stale append.
      if (_disposed || !identical(state.valueOrNull, loading)) return;
      // Rebuild explicitly (not copyWith) so a null `nextCursor` on the last
      // page is stored rather than silently keeping the stale cursor.
      state = AsyncData(PayoutsData(
        items: [...cur.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      if (_disposed) return;
      try {
        if (identical(state.valueOrNull, loading)) {
          state = AsyncData(cur.copyWith(loadingMore: false));
        }
      } catch (_) {}
    }
  }
}

/// Accumulated cursor-paged withdrawal requests.
class PayoutRequestsData {
  const PayoutRequestsData({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<PayoutRequest> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;

  PayoutRequestsData copyWith({bool? loadingMore}) => PayoutRequestsData(
        items: items,
        nextCursor: nextCursor,
        hasMore: hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Withdrawal requests (`GET /v1/tasker/payout-requests`, MQA-69) with cursor
/// paging. 💰 display-only.
final payoutRequestsControllerProvider = AsyncNotifierProvider.autoDispose<
    PayoutRequestsController, PayoutRequestsData>(PayoutRequestsController.new);

class PayoutRequestsController extends AutoDisposeAsyncNotifier<PayoutRequestsData> {
  KycoApi get _api => ref.read(kycoApiProvider);

  bool _disposed = false;

  @override
  Future<PayoutRequestsData> build() async {
    ref.onDispose(() => _disposed = true);
    final page = await _api.payoutRequests();
    return PayoutRequestsData(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  /// Append the next page. No-op when already loading, exhausted, or cursorless.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.loadingMore || !cur.hasMore || cur.nextCursor == null) {
      return;
    }
    final loading = cur.copyWith(loadingMore: true);
    state = AsyncData(loading);
    try {
      final page = await _api.payoutRequests(cursor: cur.nextCursor);
      // Bail if disposed or a refresh reset page 1 while we awaited.
      if (_disposed || !identical(state.valueOrNull, loading)) return;
      state = AsyncData(PayoutRequestsData(
        items: [...cur.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ));
    } catch (_) {
      if (_disposed) return;
      try {
        if (identical(state.valueOrNull, loading)) {
          state = AsyncData(cur.copyWith(loadingMore: false));
        }
      } catch (_) {}
    }
  }
}

// ── display helpers (labels only — never money math) ─────────────────────────

/// Human label for a wallet-transaction `reason`, mirroring the web's
/// REASON_LABELS. Falls back to the raw reason so an unknown kind still shows.
String walletReasonLabel(AppLocalizations l, String? reason) => switch (reason) {
      'tasker_earning' || 'cleaner_pay' => l.provWalletReasonEarning,
      'tip' => l.provWalletReasonTip,
      'bonus' => l.provWalletReasonBonus,
      'payout' => l.provWalletReasonPayout,
      'commission_due' => l.provWalletReasonCommission,
      'clawback' => l.provWalletReasonClawback,
      'adjustment' => l.provWalletReasonAdjustment,
      _ => (reason == null || reason.isEmpty) ? l.provWalletReasonDefault : reason,
    };

/// Vietnamese label + a semantic tone key for a payout status (mirrors the
/// web's PAYOUT_STATUS_LABEL). Tone is resolved to colours by the screen.
({String label, String tone}) payoutStatusLabel(AppLocalizations l, String? status) => switch (status) {
      'released' => (label: l.provWalletPayoutReleased, tone: 'success'),
      'withdrawn' => (label: l.provWalletPayoutWithdrawn, tone: 'info'),
      'reversed' => (label: l.provWalletPayoutReversed, tone: 'error'),
      _ => (label: l.provWalletPayoutHeld, tone: 'warning'),
    };

/// Localized date-time for a raw ISO-8601 timestamp; falls back to the raw
/// string, then to an em dash — never leaks an ISO blob or "null".
String formatWalletDate(BuildContext context, String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat.yMd(Localizations.localeOf(context).toString())
      .add_Hm()
      .format(dt.toLocal());
}
