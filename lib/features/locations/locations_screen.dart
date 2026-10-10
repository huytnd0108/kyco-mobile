import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/breakpoints.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'locations_providers.dart';
import '../../core/text_scale.dart';

/// `/locations` — the active service-area index. Mirrors the web
/// `locations/page.tsx` "Active cities" grid: each city links into its landing.
/// Fully public (guest-first); API-backed via [locationsTreeProvider].
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cities = ref.watch(locationsTreeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.locationsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(locationsTreeProvider);
            await refreshQuietly(ref.read(locationsTreeProvider.future));
          },
          child: cities.when(
            loading: () =>
                const _Scroll(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _Scroll(
              child: Center(
                child: ErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(locationsTreeProvider),
                ),
              ),
            ),
            data: (list) => list.isEmpty
                ? _Scroll(
                    child: Center(
                        child: EmptyState(message: l.noResults, icon: Icons.place_outlined)))
                : _CityGrid(list),
          ),
        ),
      ),
    );
  }
}

class _CityGrid extends StatelessWidget {
  const _CityGrid(this.cities);
  final List<ActiveCity> cities;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final columns = locationsGridColumns(windowSizeOf(context));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(l.exploreServices,
                style: TextStyle(color: cs.onSurfaceVariant)),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 156 + scaledExtra(context, 110),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _CityCard(cities[i]),
              childCount: cities.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard(this.city);
  final ActiveCity city;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => context.push('/locations/${city.slug}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_city, color: cs.primary, size: 22),
              const Spacer(),
              Text(city.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (city.wards.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_wardCountLabel(context, city.wards.length),
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Text('${l.viewAll} →',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

String _wardCountLabel(BuildContext context, int n) {
  return AppLocalizations.of(context).wardsCount(n);
}

/// Scroll wrapper so RefreshIndicator drives even the loading/empty/error views.
class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.28),
          child,
        ],
      );
}
