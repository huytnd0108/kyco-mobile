import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Filled-star colour: amber-700 (>= 3:1 non-text contrast on white/near-white;
/// the old amber-500 was 2.15:1).
const Color _kStarColor = Color(0xFFB45309);

/// A 5-star average with an optional "(N reviews)" count, mirroring the web.
class RatingStars extends StatelessWidget {
  const RatingStars(this.average, {super.key, this.count, this.size = 18});
  final double average;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // One announcement ("4,5 trên 5 sao" + the review count) instead of five
    // unnamed icons.
    return Semantics(
      label: [
        l.ratingOutOf(average),
        if (count != null) l.reviewCount(count!),
      ].join(', '),
      excludeSemantics: true,
      child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            average >= i
                ? Icons.star
                : (average >= i - 0.5 ? Icons.star_half : Icons.star_border),
            size: size,
            color: _kStarColor,
          ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(AppLocalizations.of(context).reviewCount(count!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ],
    ));
  }
}
