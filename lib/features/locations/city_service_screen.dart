import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/problem.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'locations_providers.dart';

/// `/locations/:city/:service` — a city-scoped service intro. Mirrors the web
/// `locations/[city]/[service]/page.tsx` leaf: a simple info block for the
/// service in that city + a prominent "book now" CTA into `/checkout/:id`.
///
/// The service is resolved from the city landing's own service set (by slug or
/// id) — no extra endpoint. Fully public; unknown city or service → not-found.
class CityServiceScreen extends ConsumerWidget {
  const CityServiceScreen({super.key, required this.citySlug, required this.service});
  final String citySlug;
  final String service;

  ServiceSummary? _resolve(CityLanding landing) {
    for (final s in landing.services) {
      if ((s.slug != null && s.slug == service) || s.id.toString() == service) {
        return s;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final landing = ref.watch(cityProvider(citySlug));
    final resolved =
        landing.maybeWhen(data: _resolve, orElse: () => null);

    return Scaffold(
      appBar: AppBar(title: Text(resolved?.name ?? l.locationsTitle)),
      bottomNavigationBar: resolved == null
          ? null
          : StickyBottomCta(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.subtotalLabel,
                            style: Theme.of(context).textTheme.labelSmall),
                        PriceText(resolved.basePriceVnd, from: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => context.push('/checkout/${resolved.id}'),
                    icon: const Icon(Icons.bolt),
                    label: Text(l.bookNow),
                  ),
                ],
              ),
            ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(cityProvider(citySlug));
            await ref.read(cityProvider(citySlug).future);
          },
          child: landing.when(
            loading: () =>
                const _Scroll(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => _Scroll(
              child: (e is ApiException && e.status == 404)
                  ? _NotFound(uri: '/locations/$citySlug/$service')
                  : Center(
                      child: ErrorRetry(
                        message: l.genericError,
                        onRetry: () => ref.invalidate(cityProvider(citySlug)),
                      ),
                    ),
            ),
            data: (data) {
              final svc = _resolve(data);
              if (svc == null) {
                return _Scroll(
                    child: _NotFound(uri: '/locations/$citySlug/$service'));
              }
              return _Intro(city: data.city, service: svc);
            },
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.city, required this.service});
  final CityInfo city;
  final ServiceSummary service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _HeroImage(service.imageUrl, label: service.name),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (service.category != null && service.category!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(service.category!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(height: 10),
              Text(service.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PriceText(service.basePriceVnd,
                      from: true, style: Theme.of(context).textTheme.titleMedium),
                  if (service.durationMinutes != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(l.minutesShort(service.durationMinutes!),
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(l.cityServices(city.name),
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l.guestCheckoutNotice,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push('/services/${service.id}'),
                icon: const Icon(Icons.info_outline),
                label: Text(l.viewDetails),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage(this.url, {required this.label});
  final String? url;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget placeholder({bool loading = false}) => Container(
          color: cs.primaryContainer,
          child: Center(
            child: loading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.cleaning_services,
                    color: cs.onPrimaryContainer, size: 34),
          ),
        );
    if (url == null || url!.isEmpty || url!.startsWith('media:')) {
      return placeholder();
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      semanticLabel: label,
      errorBuilder: (_, _, _) => placeholder(),
      loadingBuilder: (c, child, p) =>
          p == null ? child : placeholder(loading: true),
    );
  }
}

/// Friendly not-found for an unknown city or service leaf (API 404 / no match).
class _NotFound extends StatelessWidget {
  const _NotFound({required this.uri});
  final String uri;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        message: l.pageNotFound(uri),
        icon: '🧭',
        action: FilledButton(
          onPressed: () => context.go('/locations'),
          child: Text(l.locationsTitle),
        ),
      ),
    );
  }
}

/// Scroll wrapper so RefreshIndicator drives even the loading/error/not-found.
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
