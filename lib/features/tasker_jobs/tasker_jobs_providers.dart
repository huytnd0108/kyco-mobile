import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// The tasker's accumulated assigned-jobs page + opaque forward cursor.
/// Mirrors the notifications controller shape: `build()` loads page 1 (Bearer
/// read via `taskerJobs()`), and [loadMore] follows `meta.nextCursor` and
/// appends. Money on each [TaskerJob] is the server-derived `totalVnd`; the
/// list never computes an amount.
class AssignedJobsData {
  const AssignedJobsData({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<TaskerJob> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;

  AssignedJobsData copyWith({
    List<TaskerJob>? items,
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

/// Assigned-jobs controller. The screen watches it once the tasker is signed
/// in; `ref.invalidate` (pull-to-refresh) resets to page 1.
final assignedJobsControllerProvider =
    AsyncNotifierProvider.autoDispose<AssignedJobsController, AssignedJobsData>(
        AssignedJobsController.new);

class AssignedJobsController extends AutoDisposeAsyncNotifier<AssignedJobsData> {
  KycoApi get _api => ref.read(kycoApiProvider);

  /// Set on dispose so a page fetch that resolves after the controller is gone
  /// never touches `state` (which would throw and surface as an unhandled async).
  bool _disposed = false;

  @override
  Future<AssignedJobsData> build() async {
    ref.onDispose(() => _disposed = true);
    final page = await _api.taskerJobs();
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
    final loading = cur.copyWith(loadingMore: true);
    state = AsyncData(loading);
    try {
      final page = await _api.taskerJobs(cursor: cur.nextCursor);
      // Bail if the controller was disposed or a pull-refresh reset page 1 while
      // we awaited — never clobber fresh state with a stale append.
      if (_disposed || !identical(state.valueOrNull, loading)) return;
      // Rebuild explicitly (not copyWith) so a null `nextCursor` on the last
      // page is stored rather than silently keeping the stale cursor.
      state = AsyncData(AssignedJobsData(
        items: [...cur.items, ...page.items],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // Guard the failure write too: on a disposed notifier `state=` throws and
      // would rethrow as an unhandled async error.
      if (_disposed) return;
      try {
        if (identical(state.valueOrNull, loading)) {
          state = AsyncData(cur.copyWith(loadingMore: false));
        }
      } catch (_) {}
    }
  }
}

/// The available-jobs view (A9): the claimable pool + this tasker's assigned
/// pipeline + the `canClaim` / `banReason` gate. Auto-disposes; refreshable via
/// `ref.invalidate`. The claim action lives on the screen (server-side amount).
final poolProvider = FutureProvider.autoDispose<PoolView>((ref) {
  return ref.watch(kycoApiProvider).poolJobs();
});

/// The snackbar text for a failed claim. The claim route refuses with a
/// localized, user-facing reason (time conflict with another job, wallet below
/// the floor, rank window not open yet, already claimed, suspended …) — show
/// THAT instead of a generic "try again". Transport failures / maintenance /
/// an empty message fall back to [fallback].
String claimErrorMessage(Object error, String fallback) {
  if (error is ApiException && !error.isMaintenance && error.code != 'network') {
    final msg = error.message.trim();
    if (msg.isNotEmpty && msg != 'Request failed') return msg;
  }
  return fallback;
}
