import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/problem.dart';
import '../../core/breakpoints.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'locations_providers.dart';

/// `/locations/:city` — a single city's landing. Mirrors the web
/// `locations/[city]/page.tsx`: city header + the services available there
/// (from the `GET /v1/city/:slug` composite, capped at 24). Each service card
/// deep-links to `/services/:id`. Fully public. Unknown slug → friendly
/// not-found.
class CityScreen extends ConsumerWidget {
  const CityScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final landing = ref.watch(cityProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(l.locationsTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cityProvider(slug));
            await ref.read(cityProvider(slug).future);
          },
          child: landing.when(
            loading: () =>
                const _Scroll(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _Scroll(
              child: (e is ApiException && e.status == 404)
                  ? _NotFound(slug: slug)
                  : Center(
                      child: ErrorRetry(
                        message: l.genericError,
                        onRetry: () => ref.invalidate(cityProvider(slug)),
                      ),
                    ),
            ),
            data: (data) => _CityBody(data),
          ),
        ),
      ),
    );
  }
}

class _CityBody extends StatelessWidget {
  const _CityBody(this.landing);
  final CityLanding landing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    // Service preview mirrors the web city page: 1 col on phones, 2 on tablet,
    // 3 on desktop. A single column on compact keeps the shared ServiceCard
    // footer (duration + price) from overflowing on narrow widths.
    final size = windowSizeOf(context);
    final columns = switch (size) {
      WindowSize.compact => 1,
      WindowSize.medium => 2,
      WindowSize.expanded => 3,
    };
    final services = landing.services;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(landing.city.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(l.cityServices(landing.city.name),
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        if (services.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: EmptyState(message: l.noResults)),
            ),
          )
        else if (columns == 1)
          // Single column on compact → let each ServiceCard take its natural
          // height (overflow-proof, no forced aspect ratio).
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: services.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) => ServiceCard(
                services[i],
                onTap: () => context.push('/services/${services[i].id}'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => ServiceCard(
                  services[i],
                  onTap: () => context.push('/services/${services[i].id}'),
                ),
                childCount: services.length,
              ),
            ),
          ),
      ],
    );
  }
}

/// Friendly not-found for an unknown/inactive city slug (API 404).
class _NotFound extends StatelessWidget {
  const _NotFound({required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        message: l.pageNotFound('/locations/$slug'),
        icon: '🧭',
        action: FilledButton(
          onPressed: () => context.go('/locations'),
          child: Text(l.locationsTitle),
        ),
      ),
    );
  }
}

/// Scroll wrapper so RefreshIndicator drives even the loading/error views.
class _Scroll extends StatelessWidget {
  const _Scroll({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          child,
        ],
      );
}
