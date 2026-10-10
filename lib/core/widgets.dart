import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import 'api/problem.dart';
import 'ui/error_text.dart';


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
    // Live region: an error that appears after a submit is announced by
    // TalkBack / VoiceOver without moving focus.
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
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
    ));
  }
}

/// Full-screen error state with a retry action (used by data screens).
///
/// Pass the typed [error] (preferred): its copy comes from [apiErrorText], so
/// offline, maintenance and rate-limit each get their own message, and a 404
/// (removed / foreign id) shows a not-found message WITHOUT a pointless Retry.
/// [message] is only for errors that are not exceptions (e.g. a status string).
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, this.error, this.message, required this.onRetry})
      : assert(error != null || message != null, 'give an error or a message');
  final Object? error;
  final String? message;
  final VoidCallback onRetry;

  /// A missing resource never recovers by retrying.
  bool get _notFound {
    final e = error;
    return e is ApiException && (e.status == 404 || e.code == 'NOT_FOUND');
  }

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
            Text(message ?? apiErrorText(AppLocalizations.of(context), error), textAlign: TextAlign.center),
            if (!_notFound) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline error with a Retry action, for a section that failed while
/// the rest of the screen is usable (filter chips, a history list, a tier read).
/// A failure must never render as an empty or default "success" section.
class InlineErrorRow extends StatelessWidget {
  const InlineErrorRow({super.key, required this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final notFound = error is ApiException && ((error as ApiException).status == 404);
    return Row(
      children: [
        Icon(Icons.error_outline, size: 20, color: cs.error),
        const SizedBox(width: 8),
        Expanded(child: Text(apiErrorText(l, error), style: TextStyle(color: cs.onSurfaceVariant))),
        if (!notFound) TextButton(onPressed: onRetry, child: Text(l.retry)),
      ],
    );
  }
}

/// Pull-to-refresh body: wait for the reload but swallow its failure — an
/// offline pull must not throw out of `RefreshIndicator.onRefresh`; the screen's
/// `.when(error:)` already renders the failure with a Retry.
Future<void> refreshQuietly(Future<Object?> reload) async {
  try {
    await reload;
  } catch (_) {/* surfaced by the screen's error state */}
}
