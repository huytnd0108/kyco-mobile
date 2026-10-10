import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'filter_sheet.dart';
import 'services_providers.dart';

/// The services catalog — mirrors the web `/services` page: top search, category
/// + subcategory chips, an infinite-scroll grid of [ServiceCard]s fed by real
/// cursor pagination, a dashed empty state, and pull-to-refresh. Fully public.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key, this.category, this.subcategory, this.q});
  final String? category;
  final String? subcategory;
  final String? q;

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _scroll = ScrollController();
  late final TextEditingController _searchCtrl;

  String? _category;
  String? _subcategory; // slug
  String? _subLabel; // display name for the client-contains fallback
  String _q = '';

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _subcategory = widget.subcategory;
    _q = widget.q ?? '';
    _searchCtrl = TextEditingController(text: _q);
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ServicesScreen old) {
    super.didUpdateWidget(old);
    // Re-navigating to /services with new query params (e.g. a category deep
    // link from Home) rebuilds this same State — sync the incoming filter.
    if (old.category != widget.category ||
        old.subcategory != widget.subcategory ||
        old.q != widget.q) {
      setState(() {
        _category = widget.category;
        _subcategory = widget.subcategory;
        _subLabel = null;
        _q = widget.q ?? '';
        _searchCtrl.text = _q;
      });
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  ServicesFilter get _filter => ServicesFilter(
        category: _category,
        subcategory: _subcategory,
        subcategoryLabel: _subLabel,
        q: _q,
      );

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(servicesFeedProvider(_filter).notifier).loadMore();
    }
  }

  void _selectCategory(String? slug) {
    if (_category == slug && _subcategory == null) return;
    setState(() {
      _category = slug;
      _subcategory = null;
      _subLabel = null;
    });
  }

  void _selectSubcategory(String? slug, String? label) {
    setState(() {
      _subcategory = slug;
      _subLabel = label;
    });
  }

  void _submitSearch(String value) => setState(() => _q = value.trim());

  void _resetAll() {
    setState(() {
      _category = null;
      _subcategory = null;
      _subLabel = null;
      _q = '';
      _searchCtrl.clear();
    });
  }

  Future<void> _openFilterSheet(List<CatalogCategory> tree) async {
    final locale = Localizations.localeOf(context).languageCode;
    final sel = await showServicesFilterSheet(
      context,
      tree: tree,
      locale: locale,
      selectedCategory: _category,
      selectedSubSlug: _subcategory,
    );
    if (sel == null || !mounted) return;
    setState(() {
      _category = sel.category;
      _subcategory = sel.subSlug;
      _subLabel = sel.subLabel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tree = ref.watch(catalogTreeProvider);
    final feed = ref.watch(servicesFeedProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: Text(l.servicesTitle),
        actions: [
          IconButton(
            tooltip: l.allCategories,
            icon: const Icon(Icons.tune),
            onPressed: tree.maybeWhen(
              data: (t) => t.isEmpty ? null : () => _openFilterSheet(t),
              orElse: () => null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SearchField(
                controller: _searchCtrl,
                onSubmitted: _submitSearch,
              ),
            ),
            _ChipRows(
              tree: tree,
              category: _category,
              subcategory: _subcategory,
              onCategory: _selectCategory,
              onSubcategory: _selectSubcategory,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(servicesFeedProvider(_filter));
                  await refreshQuietly(ref.read(servicesFeedProvider(_filter).future));
                },
                child: feed.when(
                  loading: () => const _ScrollableCenter(child: CircularProgressIndicator()),
                  error: (e, _) => _ScrollableCenter(
                    child: ErrorRetry(
                      // Never leak raw `ApiException(...)` text to the user.
                      error: e,
                      onRetry: () => ref.invalidate(servicesFeedProvider(_filter)),
                    ),
                  ),
                  data: (f) => f.items.isEmpty
                      ? _EmptyResults(onReset: _resetAll)
                      : _ServicesGrid(feed: f, controller: _scroll),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scrollable single-child wrapper so RefreshIndicator can drive it in the
/// loading / error / empty states.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Padding(padding: const EdgeInsets.all(24), child: child)),
          ),
        ],
      );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            message: l.noResults,
            action: FilledButton.tonalIcon(
              onPressed: onReset,
              icon: const Icon(Icons.arrow_forward),
              label: Text(l.viewAll),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.feed, required this.controller});
  final ServicesFeed feed;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    // ServiceCard (frozen core/ui) needs ~150px of inner width or its footer
    // Row (duration + price) hairline-overflows. So the narrowest canary widths
    // fall back to a single wide column (web is 1-col on phones too); normal
    // phones get 2, expanded windows get 3.
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 840 ? 3 : (w >= 380 ? 2 : 1);
    final showFooter = feed.hasMore || feed.loadingMore;
    return CenteredMaxWidth(
      maxWidth: 1200,
      child: CustomScrollView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            sliver: SliverGrid(
              gridDelegate: ServiceCardGridDelegate(
                crossAxisCount: cols,
                textScaler: MediaQuery.textScalerOf(context),
                crossAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = feed.items[i];
                  return ServiceCard(s, onTap: () => context.push('/services/${s.id}'));
                },
                childCount: feed.items.length,
              ),
            ),
          ),
          if (showFooter)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 4),
                child: Center(
                  child: feed.loadingMore
                      ? const SizedBox(
                          height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal category chips + (when a category is active) its subcategory chips,
/// both sourced from `catalogTree()`.
class _ChipRows extends StatelessWidget {
  const _ChipRows({
    required this.tree,
    required this.category,
    required this.subcategory,
    required this.onCategory,
    required this.onSubcategory,
  });
  final AsyncValue<List<CatalogCategory>> tree;
  final String? category;
  final String? subcategory;
  final void Function(String? slug) onCategory;
  final void Function(String? slug, String? label) onSubcategory;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final cats = tree.asData?.value ?? const <CatalogCategory>[];
    if (cats.isEmpty) return const SizedBox(height: 4);

    CatalogCategory? active;
    for (final c in cats) {
      if (c.slug == category) {
        active = c;
        break;
      }
    }
    final subs = active?.subcategories ?? const <CatalogSubcategory>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Height comes from the chips (>= 48dp tap target, grows with the text
        // scale) - no fixed SizedBox that would clip at large font sizes.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _Chip(
                label: l.allCategories,
                selected: category == null || category!.isEmpty,
                onSelected: () => onCategory(null),
              ),
              for (final c in cats)
                _Chip(
                  label: c.displayName(locale),
                  selected: c.slug == category,
                  onSelected: () => onCategory(c.slug),
                ),
            ],
          ),
        ),
        if (subs.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _Chip(
                  label: l.allCategories,
                  selected: subcategory == null || subcategory!.isEmpty,
                  onSelected: () => onSubcategory(null, null),
                  small: true,
                ),
                for (final s in subs)
                  _Chip(
                    label: s.displayName(locale),
                    selected: s.slug == subcategory,
                    onSelected: () => onSubcategory(s.slug, s.displayName(locale)),
                    small: true,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.small = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onSelected(),
          // Standard density + padded tap target: the touch area is >= 48dp.
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}
