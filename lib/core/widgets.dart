import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';


// Shared UI kit (core/ui) — screens import `core/widgets.dart` and get the full
// set: ServiceCard, CategoryTile, StickyBottomCta, SearchField, SectionHeader,
// PriceText, RatingStars, EmptyState — alongside the brand/error helpers below.
export 'ui/service_card.dart';
export 'ui/category_tile.dart';
export 'ui/sticky_bottom_cta.dart';
export 'ui/search_field.dart';
export 'ui/section_header.dart';
export 'ui/price_text.dart';
export 'ui/rating_stars.dart';
export 'ui/empty_state.dart';

/// Kyco gradient mark + wordmark, reused on the auth screens.
class KycoBrand extends StatelessWidget {
  const KycoBrand({super.key});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          // The web logo (apps/kyco/public/icon.svg) rasterized byte-for-byte by
          // tool/brand/render-brand.mjs — never redrawn in Flutter.
          Image.asset('assets/brand/logo.png', height: 56, width: 56,
              semanticLabel: 'Kyco', filterQuality: FilterQuality.medium),
          const SizedBox(height: 10),
          const Text('Kyco', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      );
}

/// Inline error banner for form/API failures.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        border: Border.all(color: cs.error.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(color: cs.onErrorContainer))),
        ],
      ),
    );
  }
}

/// Full-screen error state with a retry action (used by data screens).
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
