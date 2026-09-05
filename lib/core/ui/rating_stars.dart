import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// A 5-star average with an optional "(N reviews)" count, mirroring the web.
class RatingStars extends StatelessWidget {
  const RatingStars(this.average, {super.key, this.count, this.size = 18});
  final double average;
  final int? count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const amber = Color(0xFFF59E0B);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            average >= i
                ? Icons.star
                : (average >= i - 0.5 ? Icons.star_half : Icons.star_border),
            size: size,
            color: amber,
          ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Text(AppLocalizations.of(context).reviewCount(count!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ],
    );
  }
}
