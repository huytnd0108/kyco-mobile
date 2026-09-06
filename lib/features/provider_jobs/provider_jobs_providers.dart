import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// The provider's accumulated assigned-jobs page + opaque forward cursor.
/// Mirrors the notifications controller shape: `build()` loads page 1 (Bearer
/// read via `providerJobs()`), and [loadMore] follows `meta.nextCursor` and
/// appends. Money on each [ProviderJob] is the server-derived `totalVnd`; the
/// list never computes an amount.
class AssignedJobsData {
  const AssignedJobsData({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<ProviderJob> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;

  AssignedJobsData copyWith({
    List<ProviderJob>? items,
    String? nextCursor,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      AssignedJobsData(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Assigned-jobs controller. The screen watches it once the provider is signed
/// in; `ref.invalidate` (pull-to-refresh) resets to page 1.
final assignedJobsControllerProvider =
    AsyncNotifierProvider.autoDispose<AssignedJobsController, AssignedJobsData>(
        AssignedJobsController.new);

class AssignedJobsController extends AutoDisposeAsyncNotifier<AssignedJobsData> {
  KycoApi get _api => ref.read(kycoApiProvider);

  @override
  Future<AssignedJobsData> build() async {
    final page = await _api.providerJobs();
    return AssignedJobsData(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  /// Append the next page. No-op if already loading, no cursor, or exhausted.
  /// A failed fetch keeps the pages already shown and just drops the flag.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.loadingMore || !cur.hasMore || cur.nextCursor == null) {
      return;
    }
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final page = await _api.providerJobs(cursor: cur.nextCursor);
      state = AsyncData(cur.copyWith(
        items: [...cur.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(cur.copyWith(loadingMore: false));
    }
  }
}

/// The available-jobs view (A9): the claimable pool + this provider's assigned
/// pipeline + the `canClaim` / `banReason` gate. Auto-disposes; refreshable via
/// `ref.invalidate`. The claim action lives on the screen (server-side amount).
final poolProvider = FutureProvider.autoDispose<PoolView>((ref) {
  return ref.watch(kycoApiProvider).poolJobs();
});
