import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints, SliverGridLayout;
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../models.dart';
import 'price_text.dart';
import 'media_image.dart';

/// Service card mirroring the web services grid card: rounded-2xl, image,
/// category pill, title, optional 2-line description, footer (duration + price).
class ServiceCard extends StatelessWidget {
  const ServiceCard(this.service, {super.key, this.onTap});
  final ServiceSummary service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final desc = service is ServiceDetail ? (service as ServiceDetail).description : null;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _ServiceImage(service.imageUrl, label: service.name),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (service.category != null && service.category!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(service.category!,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 8),
                  Text(service.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                  const SizedBox(height: 10),
                  // Overflow-safe on narrow (2-col phone) cards: the duration
                  // ellipsizes inside Expanded, the price shrinks via FittedBox.
                  Row(
                    children: [
                      if (service.durationMinutes != null)
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.schedule, size: 15, color: cs.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(l.minutesShort(service.durationMinutes!),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                              ),
                            ],
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: PriceText(service.basePriceVnd,
                              from: true, style: Theme.of(context).textTheme.titleSmall),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceImage extends StatelessWidget {
  const _ServiceImage(this.url, {required this.label});
  final String? url;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ResolvedImageUrl(
      url: url,
      builder: (context, resolved, resolving) {
        if (resolved == null) return _placeholder(cs, loading: resolving);
        return Image.network(
          resolved,
          fit: BoxFit.cover,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => _placeholder(cs),
          loadingBuilder: (c, child, p) => p == null ? child : _placeholder(cs, loading: true),
        );
      },
    );
  }

  Widget _placeholder(ColorScheme cs, {bool loading = false}) => Container(
        color: cs.primaryContainer,
        child: Center(
          child: loading
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(Icons.cleaning_services, color: cs.onPrimaryContainer, size: 30),
        ),
      );
}

/// Grid delegate for [ServiceCard]s. Same shape as a fixed-aspect-ratio grid at
/// 1.0x text, but the row height grows with the text scale so the card's text
/// block is never clipped at 1.6x-2.0x (UX-M46).
class ServiceCardGridDelegate extends SliverGridDelegate {
  const ServiceCardGridDelegate({
    required this.crossAxisCount,
    required this.textScaler,
    this.aspectRatio = 0.68,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
  });
  final int crossAxisCount;
  final TextScaler textScaler;
  final double aspectRatio;
  final double mainAxisSpacing;
  final double crossAxisSpacing;

  /// Height (at 1.0x) of the card's text block: pill + title + description +
  /// footer.
  static const double textBlock = 168;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final usable = constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1);
    final width = usable / crossAxisCount;
    final extra = textScaler.scale(textBlock) - textBlock;
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisExtent: width / aspectRatio + (extra > 0 ? extra : 0),
    ).getLayout(constraints);
  }

  @override
  bool shouldRelayout(covariant ServiceCardGridDelegate old) =>
      old.crossAxisCount != crossAxisCount ||
      old.textScaler != textScaler ||
      old.aspectRatio != aspectRatio ||
      old.mainAxisSpacing != mainAxisSpacing ||
      old.crossAxisSpacing != crossAxisSpacing;
}
