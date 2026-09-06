import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// The signed-in customer's notifications feed: the accumulated list, the
/// `meta.unread` count, and the opaque forward cursor. Fully API-backed
/// (`GET /v1/notifications` + `POST /v1/notifications` mark-all-read).
class NotificationsData {
  const NotificationsData({
    required this.items,
    required this.unread,
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<NotificationItem> items;
  final int unread;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;

  NotificationsData copyWith({
    List<NotificationItem>? items,
    int? unread,
    String? nextCursor,
    bool? hasMore,
    bool? loadingMore,
  }) =>
      NotificationsData(
        items: items ?? this.items,
        unread: unread ?? this.unread,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Notifications controller. `build()` loads the first page (Bearer read); the
/// screen only watches it once signed in. `loadMore()` follows the opaque
/// cursor; `markAllRead()` round-trips the POST then reflects read locally.
final notificationsControllerProvider =
    AsyncNotifierProvider.autoDispose<NotificationsController, NotificationsData>(
        NotificationsController.new);

class NotificationsController
    extends AutoDisposeAsyncNotifier<NotificationsData> {
  KycoApi get _api => ref.read(kycoApiProvider);

  /// Set on dispose so a page fetch that resolves after the controller is gone
  /// never touches `state` (which would throw and surface as an unhandled async).
  bool _disposed = false;

  @override
  Future<NotificationsData> build() async {
    ref.onDispose(() => _disposed = true);
    final (page, unread) = await _api.notifications();
    return NotificationsData(
      items: page.items,
      unread: unread,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  /// Append the next page. No-op if already loading, no cursor, or exhausted.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null ||
        cur.loadingMore ||
        !cur.hasMore ||
        cur.nextCursor == null) {
      return;
    }
    final loading = cur.copyWith(loadingMore: true);
    state = AsyncData(loading);
    try {
      final (page, unread) = await _api.notifications(cursor: cur.nextCursor);
      // Bail if the controller was disposed or a pull-refresh reset page 1 while
      // we awaited — never clobber fresh state with a stale append.
      if (_disposed || !identical(state.valueOrNull, loading)) return;
      // Rebuild explicitly (not copyWith) so a null `nextCursor` on the last
      // page is stored rather than silently keeping the stale cursor.
      state = AsyncData(NotificationsData(
        items: [...cur.items, ...page.items],
        unread: unread,
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

  /// POST mark-all-read, then reflect read + zero the badge without a refetch.
  /// Returns false (badge unchanged) if the POST fails so the caller can surface
  /// a message — never leaves the failure as an unhandled async exception.
  Future<bool> markAllRead() async {
    try {
      await _api.markNotificationsRead();
    } catch (_) {
      return false;
    }
    final cur = state.valueOrNull;
    if (cur == null) {
      ref.invalidateSelf();
      return true;
    }
    state = AsyncData(cur.copyWith(
      items: [for (final n in cur.items) _asRead(n)],
      unread: 0,
    ));
    return true;
  }

  static NotificationItem _asRead(NotificationItem n) => NotificationItem(
        id: n.id,
        type: n.type,
        title: n.title,
        body: n.body,
        link: n.link,
        createdAt: n.createdAt,
        read: true,
      );
}
