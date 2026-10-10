import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/models.dart';
import '../../core/widgets.dart';
import '../../theme/app_semantics.dart';
import 'service_detail_providers.dart';
import 'package:kyco_mobile/core/datetime.dart';

/// The customer-reviews section: title, a verified-review list, and a numeric
/// cursor "load more". Mirrors the web's review block (every row is a verified
/// completed job by construction). Empty / loading / error handled gracefully.
class ReviewList extends ConsumerWidget {
  const ReviewList(this.serviceId, {super.key});
  final int serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(reviewsControllerProvider(serviceId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l.reviewsTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: state.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(reviewsControllerProvider(serviceId)),
            ),
            data: (s) => s.reviews.isEmpty
                ? EmptyState(
                    message: l.noReviewsYet,
                    icon: Icons.chat_bubble_outline,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final r in s.reviews) ...[
                        _ReviewCard(r),
                        const SizedBox(height: 12),
                      ],
                      if (s.hasMore)
                        Center(
                          child: OutlinedButton(
                            onPressed: s.loadingMore
                                ? null
                                : () => ref
                                    .read(reviewsControllerProvider(serviceId).notifier)
                                    .loadMore(),
                            child: s.loadingMore
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(l.loadMore),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard(this.review);
  final Review review;

  /// Localized short date in Vietnam time; '—' if unparseable.
  static String _formatDate(BuildContext context, String raw) =>
      vnDateMedium(context, raw);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RatingStars(review.rating.toDouble(), size: 16),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.semantics.successContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l.verifiedBadge,
                    style: TextStyle(
                      color: context.semantics.onSuccessContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(review.displayName.trim().isEmpty ? l.reviewAnonymous : review.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (review.createdAt.isNotEmpty) ...[
                  Text('  ·  ',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  Text(_formatDate(context, review.createdAt),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ],
            ),
            if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment!,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
