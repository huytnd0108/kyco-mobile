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
    bool clearCursor = false,
    bool? hasMore,
    bool? loadingMore,
    bool? searching,
  }) =>
      ServicesFeed(
        // `clearCursor` wins so end-of-list (nextCursor:null) doesn't retain the
        // stale token — mirrors ReviewsState. Without it, `nextCursor ?? this…`
        // could never null out an exhausted cursor and loadMore would refetch it.
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
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
    final sub = await _resolveSub(arg);
    if (arg.isSearching) return _searchFeed(arg, sub);

    final page = await _api.services(category: _categoryParam, limit: _pageSize);
    return ServicesFeed(
      items: _applySubcategory(page.items, sub),
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  /// Search mode: real `search()` for the hits, real `services()` for full
  /// summary cards. Every real hit is shown — a hit whose service is in the
  /// scanned page gets its rich summary, one that isn't gets a row synthesized
  /// straight from the hit's own title/id so it is never dropped. When search()
  /// throws we fall back to a pure client name-contains over the scanned page.
  Future<ServicesFeed> _searchFeed(ServicesFilter arg, _SubFilter? sub) async {
    final needle = arg.query.toLowerCase();
    List<SearchHit> hits = const [];
    var searchOk = false;
    try {
      hits = (await _api.search(arg.query))
          .where((h) => h.kind == 'service')
          .toList(growable: false);
      searchOk = true;
    } catch (_) {
      // Search upstream hiccup -> fall back to pure client-contains below.
    }
    final page = await _api.services(category: _categoryParam, limit: _searchScanSize);
    final byId = {for (final s in page.items) s.id: s};

    final rows = searchOk
        ? [for (final h in hits) byId[h.id] ?? _summaryFromHit(h)]
        : page.items
            .where((s) => s.name.toLowerCase().contains(needle))
            .toList(growable: false);
    return ServicesFeed(items: _applySubcategory(rows, sub), searching: true);
  }

  /// A minimal summary card built from a real search hit whose full service row
  /// wasn't in the scanned page — so every /v1/search result is still shown.
  /// Price/duration are unknown from a hit; the card degrades gracefully.
  ServiceSummary _summaryFromHit(SearchHit h) =>
      ServiceSummary(id: h.id, name: h.title, basePriceVnd: 0);

  /// Resolve the active subcategory into a filter. List rows carry
  /// `subcategory == null`, and a URL-supplied `?subcategory=` slug has no
  /// label, so an exact-slug match alone always yields an empty grid. We read
  /// `catalogTree()` to recover (a) the member service-ids under the slug —
  /// locale-free, authoritative — and (b) its vi/en display names for the
  /// name-contains fallback. Any label the chip already supplied is kept, so
  /// in-app selection never regresses. Null = no subcategory active.
  Future<_SubFilter?> _resolveSub(ServicesFilter arg) async {
    final slug = arg.subcategory;
    if (slug == null || slug.isEmpty) return null;
    final labels = <String>{};
    final supplied = (arg.subcategoryLabel ?? '').trim();
    if (supplied.isNotEmpty) labels.add(supplied.toLowerCase());
    var memberIds = const <int>{};
    try {
      final tree = await ref.read(catalogTreeProvider.future);
      for (final c in tree) {
        for (final s in c.subcategories) {
          if (s.slug == slug) {
            memberIds = s.services.map((sv) => sv.id).toSet();
            if (s.nameVi.isNotEmpty) labels.add(s.nameVi.toLowerCase());
            if ((s.nameEn ?? '').isNotEmpty) labels.add(s.nameEn!.toLowerCase());
          }
        }
      }
    } catch (_) {
      // Tree unavailable -> rely on whatever label the chip supplied.
    }
    return _SubFilter(slug: slug, memberIds: memberIds, labels: labels.toList(growable: false));
  }

  /// Narrow a page to the active subcategory: authoritative catalog membership
  /// first, then the exact slug (if a row ever carries one), then a name-contains
  /// on any resolved label.
  List<ServiceSummary> _applySubcategory(List<ServiceSummary> items, _SubFilter? sub) {
    if (sub == null) return items;
    return items.where((s) {
      if (sub.memberIds.contains(s.id)) return true;
      if (s.subcategory == sub.slug) return true;
      if (sub.labels.isNotEmpty) {
        final n = s.name.toLowerCase();
        for (final l in sub.labels) {
          if (l.isNotEmpty && n.contains(l)) return true;
        }
      }
      return false;
    }).toList(growable: false);
  }

  /// Fetch the next opaque-cursor page and append. No-op while searching, at the
  /// end of the list, or when a fetch is already in flight.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.searching || !cur.hasMore || cur.loadingMore) return;
    if (cur.nextCursor == null) return;

    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final sub = await _resolveSub(arg);
      final page = await _api.services(
        category: _categoryParam,
        cursor: cur.nextCursor,
        limit: _pageSize,
      );
      state = AsyncData(cur.copyWith(
        items: [...cur.items, ..._applySubcategory(page.items, sub)],
        nextCursor: page.nextCursor,
        // End of list (or hasMore with no cursor) -> null the token so we don't
        // retain/refetch a stale cursor. Mirrors ReviewsState.loadMore.
        clearCursor: page.nextCursor == null,
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      // Keep what we have; a transient next-page failure must not blank the grid.
      state = AsyncData(cur.copyWith(loadingMore: false));
    }
  }
}

/// The resolved subcategory filter: the authoritative member service-ids under
/// the slug plus lowercased vi/en labels for the name-contains fallback. Built
/// by [ServicesFeedController._resolveSub] from `catalogTree()` so a URL-only
/// `?subcategory=` slug (no label) still narrows the grid instead of blanking it.
class _SubFilter {
  const _SubFilter({required this.slug, required this.memberIds, required this.labels});
  final String slug;
  final Set<int> memberIds;
  final List<String> labels;
}
