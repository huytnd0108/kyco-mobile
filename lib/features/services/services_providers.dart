import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// Catalog megamenu tree (drives category + subcategory chips). Public/anon,
/// auto-disposed, refreshable via `ref.invalidate`.
final catalogTreeProvider = FutureProvider.autoDispose<List<CatalogCategory>>(
  (ref) => ref.watch(kycoApiProvider).catalogTree(),
);

/// The active services filter — the (category, subcategory, q) triple the screen
/// deep-links from `?category=&subcategory=&q=` and mutates as chips/search fire.
/// Value-equal so it keys the feed family (one accumulated page-stack per filter).
class ServicesFilter {
  const ServicesFilter({this.category, this.subcategory, this.subcategoryLabel, this.q});
  final String? category; // category slug -> real `services(category:)` param
  final String? subcategory; // subcategory slug -> client filter (list rows lack it -> label fallback)
  final String? subcategoryLabel; // display name, used for the name-contains fallback
  final String? q; // free-text query -> real `search()` + client contains

  String get query => (q ?? '').trim();
  bool get isSearching => query.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ServicesFilter &&
      other.category == category &&
      other.subcategory == subcategory &&
      other.subcategoryLabel == subcategoryLabel &&
      other.q == q;

  @override
  int get hashCode => Object.hash(category, subcategory, subcategoryLabel, q);
}

/// The accumulated feed for one filter: the page-stack so far plus the opaque
/// cursor to fetch the next page. `searching` mode is single-shot (search results
/// are not cursor-paged), so `hasMore` is false there.
class ServicesFeed {
  const ServicesFeed({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.loadingMore = false,
    this.searching = false,
  });
  final List<ServiceSummary> items;
  final String? nextCursor;
  final bool hasMore;
  final bool loadingMore;
  final bool searching;

  ServicesFeed copyWith({
    List<ServiceSummary>? items,
    String? nextCursor,
    bool? hasMore,
    bool? loadingMore,
    bool? searching,
  }) =>
      ServicesFeed(
        items: items ?? this.items,
        nextCursor: nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        searching: searching ?? this.searching,
      );
}

/// Cursor-paginated, filter-keyed service feed. `build` fetches the first page
/// (or runs a search); `loadMore` appends the next opaque-cursor page verbatim.
final servicesFeedProvider = AsyncNotifierProvider.autoDispose
    .family<ServicesFeedController, ServicesFeed, ServicesFilter>(
  ServicesFeedController.new,
);

class ServicesFeedController
    extends AutoDisposeFamilyAsyncNotifier<ServicesFeed, ServicesFilter> {
  static const _pageSize = 20;
  static const _searchScanSize = 50; // one wide scan when searching (no cursor paging)

  KycoApi get _api => ref.read(kycoApiProvider);
  String? get _categoryParam =>
      (arg.category != null && arg.category!.isNotEmpty) ? arg.category : null;

  @override
  Future<ServicesFeed> build(ServicesFilter arg) async {
    if (arg.isSearching) return _searchFeed(arg);

    final page = await _api.services(category: _categoryParam, limit: _pageSize);
    return ServicesFeed(
      items: _applySubcategory(page.items, arg),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  /// Search mode: real `search()` for matching ids, real `services()` for full
  /// summary cards, then a client name-contains fallback (mirrors book-now).
  Future<ServicesFeed> _searchFeed(ServicesFilter arg) async {
    final needle = arg.query.toLowerCase();
    Set<int> hitIds = const {};
    try {
      final hits = await _api.search(arg.query);
      hitIds = hits.where((h) => h.kind == 'service').map((h) => h.id).toSet();
    } catch (_) {
      // Search upstream hiccup -> fall back to pure client-contains below.
    }
    final page = await _api.services(category: _categoryParam, limit: _searchScanSize);
    final matched = _applySubcategory(page.items, arg)
        .where((s) => hitIds.contains(s.id) || s.name.toLowerCase().contains(needle))
        .toList(growable: false);
    return ServicesFeed(items: matched, searching: true);
  }

  /// List rows carry `subcategory == null` (per the catalog model contract), so
  /// an exact slug match usually can't fire -> fall back to a name-contains on the
  /// subcategory label so the chip still narrows the grid.
  List<ServiceSummary> _applySubcategory(List<ServiceSummary> items, ServicesFilter arg) {
    final slug = arg.subcategory;
    if (slug == null || slug.isEmpty) return items;
    final label = (arg.subcategoryLabel ?? '').toLowerCase();
    return items
        .where((s) =>
            s.subcategory == slug ||
            (label.isNotEmpty && s.name.toLowerCase().contains(label)))
        .toList(growable: false);
  }

  /// Fetch the next opaque-cursor page and append. No-op while searching, at the
  /// end of the list, or when a fetch is already in flight.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.searching || !cur.hasMore || cur.loadingMore) return;
    if (cur.nextCursor == null) return;

    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final page = await _api.services(
        category: _categoryParam,
        cursor: cur.nextCursor,
        limit: _pageSize,
      );
      state = AsyncData(cur.copyWith(
        items: [...cur.items, ..._applySubcategory(page.items, arg)],
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // Keep what we have; a transient next-page failure must not blank the grid.
      state = AsyncData(cur.copyWith(loadingMore: false));
    }
  }
}
