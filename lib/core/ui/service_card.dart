import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../models.dart';
import 'price_text.dart';

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
                  Row(
                    children: [
                      if (service.durationMinutes != null) ...[
                        Icon(Icons.schedule, size: 15, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(l.minutesShort(service.durationMinutes!),
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                        const Spacer(),
                      ] else
                        const Spacer(),
                      PriceText(service.basePriceVnd,
                          from: true, style: Theme.of(context).textTheme.titleSmall),
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
    if (url == null || url!.isEmpty || url!.startsWith('media:')) {
      return _placeholder(cs);
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      semanticLabel: label,
      errorBuilder: (_, _, _) => _placeholder(cs),
      loadingBuilder: (c, child, p) => p == null ? child : _placeholder(cs, loading: true),
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
