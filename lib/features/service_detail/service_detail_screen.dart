import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/api/problem.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../services/services_providers.dart' show catalogLabelsProvider;
import 'review_list.dart';
import 'service_detail_providers.dart';
import '../../theme/app_semantics.dart';
import '../../core/text_scale.dart';
import '../../core/ui/media_image.dart';

/// Public service-detail screen (mirrors web services/[id]/page.tsx): hero,
/// pills, price + duration, description, rating + reviews, related rail, and a
/// sticky "Đặt ngay →" CTA visible to guests (the login wall is later, in
/// checkout). 404 → friendly not-found. Pull-to-refresh.
class ServiceDetailScreen extends ConsumerWidget {
  const ServiceDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(serviceDetailProvider(id));

    return detail.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) {
        final notFound = e is ApiException && e.status == 404;
        return Scaffold(
          appBar: AppBar(),
          body: notFound
              ? _NotFound(onExplore: () => context.go('/services'))
              : ListView(children: [
                  const SizedBox(height: 100),
                  ErrorRetry(
                    error: e,
                    onRetry: () => ref.invalidate(serviceDetailProvider(id)),
                  ),
                ]),
        );
      },
      data: (s) => _DetailBody(id: id, detail: s),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.id, required this.detail});
  final int id;
  final ServiceDetail detail;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(serviceDetailProvider(id));
    ref.invalidate(relatedServicesProvider(id));
    ref.invalidate(reviewsControllerProvider(id));
    await refreshQuietly(ref.read(serviceDetailProvider(id).future));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final reviews = ref.watch(reviewsControllerProvider(id)).valueOrNull;
    final agg = reviews?.aggregate ?? ReviewAggregate.empty;
    // The row carries category/subcategory SLUGS; show the localized names from
    // the catalogue tree (hidden until known - never the raw slug).
    final labels = ref.watch(catalogLabelsProvider);
    final lc = Localizations.localeOf(context).languageCode;
    final catLabel = labels.category(detail.category, lc);
    final subLabel = labels.subcategory(detail.category, detail.subcategory, lc);
    final cat = catLabel ?? l.servicesTitle;

    return Scaffold(
      appBar: AppBar(title: Text(cat)),
      bottomNavigationBar: StickyBottomCta(
        child: Row(
          children: [
            Expanded(
              child: PriceText(detail.basePriceVnd,
                  from: true, style: Theme.of(context).textTheme.titleLarge),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => context.push('/checkout/$id'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.bookNow),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CenteredMaxWidth(
          maxWidth: 900,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Hero(detail: detail, agg: agg, catLabel: catLabel, subLabel: subLabel)),
              SliverToBoxAdapter(child: _Overview(detail: detail, agg: agg, catLabel: catLabel, subLabel: subLabel)),
              SliverToBoxAdapter(child: ReviewList(id)),
              SliverToBoxAdapter(child: _RelatedRail(id: id)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero: cover image + bottom scrim + category/subcategory pills + name +
/// compact (white) rating line. Mirrors the web hero.
class _Hero extends StatelessWidget {
  const _Hero({required this.detail, required this.agg, this.catLabel, this.subLabel});
  final String? catLabel;
  final String? subLabel;
  final ServiceDetail detail;
  final ReviewAggregate agg;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 240 + scaledExtra(context, 100),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroImage(detail.imageUrl, label: detail.name, serviceId: detail.id),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xB3000000), Color(0x4D000000), Color(0x00000000)],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (catLabel != null) _GlassPill(catLabel!),
                    if (subLabel != null) _GlassPill(subLabel!),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  detail.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (agg.count > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, size: 16, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 4),
                      Text(
                        '${agg.average.toStringAsFixed(1)}  ·  ${l.reviewCount(agg.count)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage(this.url, {required this.label, this.serviceId});
  final int? serviceId;
  final String? url;
  final String label;
  @override
  Widget build(BuildContext context) {
    // The hero text is white, so the photo-less placeholder is the dark brand
    // gradient (white on it >= 5.9:1), not the pale primaryContainer.
    Widget placeholder() => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.semantics.brandGradient,
            ),
          ),
          child: const Icon(Icons.cleaning_services,
              color: Colors.white70, size: 44),
        );
    return ResolvedImageUrl(
      url: url,
      fallbackServiceId: serviceId,
      builder: (context, resolved, _) => resolved == null
          ? placeholder()
          : Image.network(
              resolved,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => placeholder(),
              loadingBuilder: (c, child, p) => p == null ? child : placeholder(),
            ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Pills (category / subcategory / duration), price + rating, description, and
/// the verified-partners trust line.
class _Overview extends StatelessWidget {
  const _Overview({required this.detail, required this.agg, this.catLabel, this.subLabel});
  final String? catLabel;
  final String? subLabel;
  final ServiceDetail detail;
  final ReviewAggregate agg;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (catLabel != null) _Chip(catLabel!, tone: _ChipTone.primary),
              if (subLabel != null) _Chip(subLabel!),
              if (detail.durationMinutes != null)
                _Chip(l.minutesShort(detail.durationMinutes!), icon: Icons.schedule),
            ],
          ),
          const SizedBox(height: 14),
          PriceText(detail.basePriceVnd,
              from: true,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          if (agg.count > 0) ...[
            const SizedBox(height: 8),
            RatingStars(agg.average, count: agg.count),
          ],
          const SizedBox(height: 16),
          Text(l.viewDetails,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            (detail.description?.trim().isNotEmpty ?? false)
                ? detail.description!
                : AppLocalizations.of(context).serviceNoDescription,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.providersAvailable,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

enum _ChipTone { primary, muted }

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.tone = _ChipTone.muted, this.icon});
  final String text;
  final _ChipTone tone;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = tone == _ChipTone.primary;
    final fg = primary ? cs.primary : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary
            ? cs.primary.withValues(alpha: 0.1)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(text,
              style:
                  TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Horizontal related-services rail → /services/:id. Hidden when empty.
class _RelatedRail extends ConsumerWidget {
  const _RelatedRail({required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final related = ref.watch(relatedServicesProvider(id));
    return related.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (rows) {
        if (rows.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(l.relatedServices),
            SizedBox(
              // A 240px-wide ServiceCard needs ~262px when the title wraps to
              // 2 lines with a category pill; 290 clears it (Home's rail = 296).
              height: 290 + scaledExtra(context, 168),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: 240,
                  child: ServiceCard(
                    rows[i],
                    onTap: () => context.push('/services/${rows[i].id}'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onExplore});
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l.serviceNotFound, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onExplore, child: Text(l.exploreServices)),
          ],
        ),
      ),
    );
  }
}
