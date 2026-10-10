import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/breakpoints.dart';
import '../../core/widgets.dart';
import 'checkout_providers.dart';

/// /book-now — the fast-booking funnel (mirrors the web book-now page). Fully
/// guest: pick a category (step 1), filter the service list inline (step 2),
/// tap a service → /checkout/:id. The login wall is downstream, at confirm.
class BookNowScreen extends ConsumerStatefulWidget {
  const BookNowScreen({super.key, this.category, this.q});
  final String? category;
  final String? q;

  @override
  ConsumerState<BookNowScreen> createState() => _BookNowScreenState();
}

class _BookNowScreenState extends ConsumerState<BookNowScreen> {
  late String? _category = (widget.category?.isNotEmpty ?? false) ? widget.category : null;
  late final TextEditingController _searchCtrl = TextEditingController(text: widget.q ?? '');
  late String _query = (widget.q ?? '').trim().toLowerCase();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.bookNow)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Step 1 — category.
          Text(l.step1Category, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _CategoryChips(
            selected: _category,
            onSelect: (slug) => setState(() => _category = slug),
          ),
          const SizedBox(height: 20),

          // Inline search (contains-filter, like the web).
          SearchField(
            controller: _searchCtrl,
            onSubmitted: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 20),

          // Step 2 — service.
          Text(l.step2Service, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _ServiceGrid(category: _category, query: _query),
        ],
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final catsAsync = ref.watch(bookNowCategoriesProvider);

    return catsAsync.when(
      loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => InlineErrorRow(error: e, onRetry: () => ref.invalidate(bookNowCategoriesProvider)),
      data: (cats) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: Text(l.allCategories),
            selected: selected == null,
            onSelected: (_) => onSelect(null),
          ),
          for (final c in cats)
            ChoiceChip(
              label: Text(c.displayName(locale)),
              selected: selected == c.slug,
              onSelected: (_) => onSelect(c.slug),
            ),
        ],
      ),
    );
  }
}

class _ServiceGrid extends ConsumerWidget {
  const _ServiceGrid({required this.category, required this.query});
  final String? category;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(bookNowServicesProvider(category));
    final cols = windowSizeOf(context) == WindowSize.compact ? 2 : 3;

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => ErrorRetry(
        error: e,
        onRetry: () => ref.invalidate(bookNowServicesProvider(category)),
      ),
      data: (all) {
        final filtered = query.isEmpty
            ? all
            : all
                .where((s) =>
                    s.name.toLowerCase().contains(query) ||
                    (s.category ?? '').toLowerCase().contains(query))
                .toList(growable: false);
        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: EmptyState(message: l.noResults),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: ServiceCardGridDelegate(
            crossAxisCount: cols,
            textScaler: MediaQuery.textScalerOf(context),
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) {
            final s = filtered[i];
            return ServiceCard(s, onTap: () => context.push('/checkout/${s.id}'));
          },
        );
      },
    );
  }
}
