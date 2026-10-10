import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Extra logical pixels a container with a fixed design height needs so its
/// text still fits at the user's font scale (UX-M46).
///
/// [textBase] is the part of the design height that is text at 1.0x. At 1.0x
/// the result is 0 (layout, and every golden, is unchanged); at 2.0x it adds
/// `textBase` more pixels. Never negative.
double scaledExtra(BuildContext context, double textBase) {
  final scaled = MediaQuery.textScalerOf(context).scale(textBase);
  return math.max(0, scaled - textBase);
}
