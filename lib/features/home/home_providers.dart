import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';

/// Public home composite (no auth). Auto-disposes; refreshable via ref.invalidate.
final homeProvider = FutureProvider.autoDispose<HomeComposite>((ref) {
  return ref.watch(kycoApiProvider).home();
});

/// The signed-in customer's bookings — FIRST page (Bearer read). Watches the
/// auth user id so a sign-out / account switch refetches (never shows the
/// previous user's orders). Seeds [bookingsPagerProvider] with the cursor;
/// later pages are appended there.
final bookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) async {
  // Signed out → nothing to show (and no doomed Bearer call).
  if (ref.watch(authUserIdProvider) == null) return const <Booking>[];
  final page = await ref.watch(kycoApiProvider).bookingsPage();
  ref.read(bookingsPagerProvider.notifier).reset(page.nextCursor, page.hasMore);
  return page.items;
});

/// Pages 2..n of the bookings list (keyset cursor from `meta.nextCursor`).
class BookingsPagerState {
  const BookingsPagerState({this.extra = const [], this.cursor, this.hasMore = false, this.loading = false});
  final List<Booking> extra;
  final String? cursor;
  final bool hasMore;
  final bool loading;
}

class BookingsPager extends Notifier<BookingsPagerState> {
  @override
  BookingsPagerState build() {
    ref.watch(authUserIdProvider);
    return const BookingsPagerState();
  }

  /// Called when page 1 (re)loads: drop appended pages, adopt the new cursor.
  void reset(String? cursor, bool hasMore) =>
      state = BookingsPagerState(cursor: cursor, hasMore: hasMore && cursor != null);

  /// Append the next page. Returns the failure (null on success / no-op).
  Future<Object?> loadMore() async {
    final cur = state;
    if (cur.loading || !cur.hasMore || cur.cursor == null) return null;
    state = BookingsPagerState(extra: cur.extra, cursor: cur.cursor, hasMore: cur.hasMore, loading: true);
    try {
      final page = await ref.read(kycoApiProvider).bookingsPage(cursor: cur.cursor);
      // A page-1 reset while we awaited wins — never append onto fresh state.
      if (state.cursor != cur.cursor) return null;
      state = BookingsPagerState(
        extra: [...cur.extra, ...page.items],
        cursor: page.nextCursor,
        hasMore: page.hasMore && page.nextCursor != null,
      );
      return null;
    } catch (e) {
      if (state.cursor == cur.cursor) {
        state = BookingsPagerState(extra: cur.extra, cursor: cur.cursor, hasMore: cur.hasMore);
      }
      return e;
    }
  }
}

final bookingsPagerProvider = NotifierProvider<BookingsPager, BookingsPagerState>(BookingsPager.new);

/// One booking's detail via the `/bookings/{id}/page` composite (owner-scoped).
final bookingDetailProvider = FutureProvider.autoDispose.family<BookingDetail, int>((ref, id) {
  ref.watch(authUserIdProvider);
  return ref.watch(kycoApiProvider).bookingDetail(id);
});
