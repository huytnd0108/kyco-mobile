import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';

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
    // User-scoped: a sign-out / account switch rebuilds (drops the old feed).
    ref.watch(authUserIdProvider);
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

  /// Mark ONE notification read (`POST /notifications/{id}/read`) and reflect
  /// it locally (tile + badge). Idempotent client-side: an already-read item is
  /// a no-op. Returns false if the POST failed (state unchanged).
  Future<bool> markRead(int id) async {
    final cur = state.valueOrNull;
    final idx = cur?.items.indexWhere((n) => n.id == id) ?? -1;
    if (cur != null && idx >= 0 && cur.items[idx].read) return true;
    try {
      await _api.markNotificationRead(id);
    } catch (_) {
      return false;
    }
    if (_disposed) return true;
    final now = state.valueOrNull;
    if (now == null) return true;
    final i = now.items.indexWhere((n) => n.id == id);
    if (i < 0 || now.items[i].read) return true;
    state = AsyncData(now.copyWith(
      items: [for (final n in now.items) n.id == id ? _asRead(n) : n],
      unread: now.unread > 0 ? now.unread - 1 : 0,
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

/// Map a notification `link` (a web path, optionally absolute on a kyco host,
/// optionally locale-prefixed) onto an in-app route, or null when the app has
/// no screen for it (admin pages, /sos, /settings, foreign hosts …). Pure.
String? inAppRouteForLink(String? link) {
  if (link == null || link.trim().isEmpty) return null;
  final uri = Uri.tryParse(link.trim());
  if (uri == null) return null;
  if (uri.hasScheme) {
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    final host = uri.host.toLowerCase();
    if (host != 'kyco.vn' && !host.endsWith('.kyco.vn')) return null;
  }
  var segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.isNotEmpty && (segs.first == 'vi' || segs.first == 'en')) segs = segs.sublist(1);
  if (segs.isEmpty) return '/';
  bool isId(String s) => int.tryParse(s) != null;
  switch (segs.first) {
    case 'bookings':
      return segs.length >= 2 && isId(segs[1]) ? '/bookings/${segs[1]}' : '/bookings';
    case 'services':
      return segs.length >= 2 && isId(segs[1]) ? '/services/${segs[1]}' : '/services';
    case 'subscriptions':
      return '/subscriptions';
    case 'notifications':
    case 'messages':
    case 'account':
    case 'help':
    case 'invite':
    case 'addresses':
    case 'become-tasker':
      return '/${segs.first}';
    case 'taskers':
      // Public tasker profile (`/taskers/{id}`) — guest-visible in-app route.
      return segs.length >= 2 && isId(segs[1]) ? '/taskers/${segs[1]}' : null;
    case 'tasker':
      if (segs.length == 1) return '/p';
      switch (segs[1]) {
        case 'jobs':
          return segs.length >= 3 && isId(segs[2]) ? '/p/jobs/${segs[2]}' : '/p/jobs';
        case 'wallet':
        case 'fines':
        case 'bonuses':
        case 'goals':
        case 'availability':
        case 'referrals':
        case 'support':
          return '/p/${segs[1]}';
      }
      return '/p';
  }
  return null;
}
