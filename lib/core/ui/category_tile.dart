import 'package:flutter/material.dart';

import '../../theme/app_semantics.dart';
import '../models.dart';
import 'media_image.dart';

/// A bento category tile (web): rounded-2xl full-bleed image + bottom scrim +
/// white title. [big] renders the 2x2 lead tile with a larger title.
class CategoryTile extends StatelessWidget {
  const CategoryTile(this.category, {super.key, this.onTap, this.big = false});
  final ServiceCategory category;
  final VoidCallback? onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final name = category.displayName(locale);
    final subtitle = category.displaySubtitle(locale);
    // Photo-less / failed / still-loading tiles show the dark brand gradient
    // (white text on it >= 5.9:1) with the category icon - never a blank tile.
    Widget placeholder() => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: context.semantics.brandGradient,
            ),
          ),
          child: const Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.cleaning_services, color: Colors.white54, size: 28),
            ),
          ),
        );
    // One labelled button per tile: the title Text, the decorative photo and the
    // InkWell overlay would otherwise be three separate (and unnamed) nodes.
    return Semantics(
      button: true,
      label: subtitle == null ? name : '$name, $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ResolvedImageUrl(
            url: category.imageUrl,
            builder: (context, resolved, _) => resolved == null
                ? placeholder()
                : Image.network(resolved,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => placeholder(),
                    loadingBuilder: (c, child, p) => p == null ? child : placeholder()),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Color(0xBF000000), Color(0x00000000)],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: big ? 20 : 15,
                    shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)],
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: big ? 14 : 12,
                      shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)],
                    ),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(onTap: onTap),
            ),
          ),
        ],
      ),
    ));
  }
}
