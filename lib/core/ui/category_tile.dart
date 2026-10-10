import 'package:flutter/material.dart';

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
    final cs = Theme.of(context).colorScheme;
    // One labelled button per tile: the title Text, the decorative photo and the
    // InkWell overlay would otherwise be three separate (and unnamed) nodes.
    return Semantics(
      button: true,
      label: category.name,
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
                ? Container(color: cs.primaryContainer)
                : Image.network(resolved,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => Container(color: cs.primaryContainer)),
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
            child: Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: big ? 20 : 15,
              ),
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
