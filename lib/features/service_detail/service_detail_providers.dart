import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';

/// Public service detail (GET /v1/services/:id). Family keyed by record id.
/// Auto-disposes; refreshable via `ref.invalidate(serviceDetailProvider(id))`.
final serviceDetailProvider =
    FutureProvider.autoDispose.family<ServiceDetail, int>((ref, id) {
  return ref.watch(kycoApiProvider).serviceDetail(id);
});

/// Public related rail (GET /v1/services/:id/related, up to 12 rows).
final relatedServicesProvider =
    FutureProvider.autoDispose.family<List<ServiceSummary>, int>((ref, id) {
  return ref.watch(kycoApiProvider).relatedServices(id);
});

/// Accumulating, cursor-paged review state for one service. The aggregate
/// (count + average) spans ALL rows; `nextCursor` is a numeric review-id
/// keyset cursor (opaque to the caller — round-tripped verbatim).
class ReviewsState {
  const ReviewsState({
    required this.reviews,
    required this.aggregate,
    this.nextCursor,
    this.loadingMore = false,
  });
  final List<Review> reviews;
  final ReviewAggregate aggregate;
  final int? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  ReviewsState copyWith({
    List<Review>? reviews,
    ReviewAggregate? aggregate,
    int? nextCursor,
    bool clearCursor = false,
    bool? loadingMore,
  }) =>
      ReviewsState(
        reviews: reviews ?? this.reviews,
        aggregate: aggregate ?? this.aggregate,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Loads the first review page, then appends subsequent pages on [loadMore].
class ReviewsController
    extends AutoDisposeFamilyAsyncNotifier<ReviewsState, int> {
  /// Set on dispose so a page fetch that resolves after the controller is gone
  /// never touches `state` (which would throw and surface as an unhandled async).
  bool _disposed = false;

  @override
  Future<ReviewsState> build(int id) async {
    ref.onDispose(() => _disposed = true);
    final page = await ref.watch(kycoApiProvider).serviceReviews(id);
    return ReviewsState(
      reviews: page.reviews,
      aggregate: page.aggregate,
      nextCursor: page.nextCursor,
    );
  }

  /// Append the next page. No-op when exhausted or already in flight. A failed
  /// page just clears the busy flag — the list already shown stays intact.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.nextCursor == null || cur.loadingMore) return;
    final loading = cur.copyWith(loadingMore: true);
    state = AsyncData(loading);
    try {
      final page = await ref
          .read(kycoApiProvider)
          .serviceReviews(arg, cursor: cur.nextCursor);
      // Bail if the controller was disposed or a pull-refresh reset page 1 while
      // we awaited — never clobber fresh state with a stale append.
      if (_disposed || !identical(state.valueOrNull, loading)) return;
      state = AsyncData(cur.copyWith(
        reviews: [...cur.reviews, ...page.reviews],
        aggregate: page.aggregate,
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        loadingMore: false,
      ));
    } catch (_) {
      // Guard the write: on a disposed notifier `state=` throws and would rethrow.
      if (_disposed) return;
      try {
        if (identical(state.valueOrNull, loading)) {
          state = AsyncData(cur.copyWith(loadingMore: false));
        }
      } catch (_) {}
    }
  }
}

final reviewsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ReviewsController, ReviewsState, int>(ReviewsController.new);
