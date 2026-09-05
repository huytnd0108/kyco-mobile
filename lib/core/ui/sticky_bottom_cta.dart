import 'package:flutter/material.dart';

/// A bar pinned above the bottom nav (web's `fixed bottom-16`): surface with a
/// top border and safe-area padding. Used by service detail (Đặt ngay →) and
/// checkout (subtotal + submit).
class StickyBottomCta extends StatelessWidget {
  const StickyBottomCta({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}
