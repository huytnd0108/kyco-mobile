import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/models.dart';

/// The user's chosen (category, subcategory) from the filter sheet. All-null =
/// "All services" (the reset). Returned by [showServicesFilterSheet].
class FilterSelection {
  const FilterSelection({this.category, this.subSlug, this.subLabel});
  final String? category;
  final String? subSlug;
  final String? subLabel;
}

/// Full-catalog filter sheet — mirrors the web `/services` tree sidebar as a
/// mobile modal: an "All" reset plus every category with its subcategories.
/// Resolves with the tapped [FilterSelection], or null when dismissed.
Future<FilterSelection?> showServicesFilterSheet(
  BuildContext context, {
  required List<CatalogCategory> tree,
  required String locale,
  String? selectedCategory,
  String? selectedSubSlug,
}) {
  return showModalBottomSheet<FilterSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _FilterSheet(
      tree: tree,
      locale: locale,
      selectedCategory: selectedCategory,
      selectedSubSlug: selectedSubSlug,
    ),
  );
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.tree,
    required this.locale,
    this.selectedCategory,
    this.selectedSubSlug,
  });
  final List<CatalogCategory> tree;
  final String locale;
  final String? selectedCategory;
  final String? selectedSubSlug;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final allSelected = selectedCategory == null || selectedCategory!.isEmpty;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(l.popularCategories,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(allSelected ? Icons.check_circle : Icons.apps,
                  color: allSelected ? cs.primary : cs.onSurfaceVariant),
              title: Text(l.allCategories),
              onTap: () => Navigator.of(context).pop(const FilterSelection()),
            ),
            const Divider(height: 8),
            for (final c in tree)
              _CategoryBlock(
                category: c,
                locale: locale,
                selectedCategory: selectedCategory,
                selectedSubSlug: selectedSubSlug,
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBlock extends StatelessWidget {
  const _CategoryBlock({
    required this.category,
    required this.locale,
    this.selectedCategory,
    this.selectedSubSlug,
  });
  final CatalogCategory category;
  final String locale;
  final String? selectedCategory;
  final String? selectedSubSlug;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActiveCat = selectedCategory == category.slug;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: isActiveCat && category.subcategories.isNotEmpty,
      title: Text(category.displayName(locale),
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isActiveCat ? cs.primary : null)),
      onExpansionChanged: (expanded) {
        // Tapping the header row itself selects the whole category.
        if (expanded && category.subcategories.isEmpty) {
          Navigator.of(context).pop(FilterSelection(category: category.slug));
        }
      },
      childrenPadding: const EdgeInsets.only(left: 8, bottom: 4),
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.grid_view, size: 18),
          title: Text(AppLocalizations.of(context).allCategories),
          selected: isActiveCat && (selectedSubSlug == null || selectedSubSlug!.isEmpty),
          onTap: () =>
              Navigator.of(context).pop(FilterSelection(category: category.slug)),
        ),
        for (final s in category.subcategories)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chevron_right, size: 18),
            title: Text(s.displayName(locale)),
            selected: isActiveCat && selectedSubSlug == s.slug,
            onTap: () => Navigator.of(context).pop(FilterSelection(
              category: category.slug,
              subSlug: s.slug,
              subLabel: s.displayName(locale),
            )),
          ),
      ],
    );
  }
}
