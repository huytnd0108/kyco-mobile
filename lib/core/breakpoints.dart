import 'package:flutter/widgets.dart';

/// Material 3 window size classes. Layout is a function of the WINDOW width,
/// never the device — on iPad, Split View / Slide Over hand the app a compact
/// window, so we must react to the window, not `Platform.isIOS`/isTablet.
enum WindowSize { compact, medium, expanded }

WindowSize windowSizeOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 600) return WindowSize.compact;
  if (w < 840) return WindowSize.medium;
  return WindowSize.expanded;
}

/// Two panes only when the window is genuinely roomy. The height guard keeps a
/// landscape iPhone (wide but short) on the single-pane phone layout.
bool canShowTwoPanes(BuildContext context) {
  final s = MediaQuery.sizeOf(context);
  return s.width >= 840 && s.height >= 600;
}
