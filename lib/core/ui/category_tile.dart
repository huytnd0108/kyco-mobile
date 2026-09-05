import 'package:flutter/material.dart';

import '../models.dart';

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
    final hasImage = category.imageUrl != null &&
        category.imageUrl!.isNotEmpty &&
        !category.imageUrl!.startsWith('media:');
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasImage)
            Image.network(category.imageUrl!,
                fit: BoxFit.cover,
                semanticLabel: category.name,
                errorBuilder: (_, _, _) => Container(color: cs.primaryContainer))
          else
            Container(color: cs.primaryContainer),
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
    );
  }
}
