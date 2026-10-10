import 'package:flutter/material.dart';

/// Semantic colors Material 3 has no role for: success / info / warning
/// containers and the Kyco brand gradient. One instance per brightness so they
/// adapt in dark mode; copyWith + lerp are required so a theme toggle animates
/// through them instead of snapping/throwing.
@immutable
class AppSemantics extends ThemeExtension<AppSemantics> {
  const AppSemantics({
    required this.successContainer,
    required this.onSuccessContainer,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.brandGradient,
  });

  final Color successContainer, onSuccessContainer;
  final Color infoContainer, onInfoContainer;
  final Color warningContainer, onWarningContainer;
  final List<Color> brandGradient;

  static const light = AppSemantics(
    successContainer: Color(0xFFDCFCE7), onSuccessContainer: Color(0xFF166534),
    infoContainer: Color(0xFFE0F2FE), onInfoContainer: Color(0xFF075985),
    warningContainer: Color(0xFFFEF3C7), onWarningContainer: Color(0xFF92400E),
    // Sky-700 → sky-800: white text on the gradient is 5.9:1 / 7.6:1 (the
    // old sky-500 → sky-600 gave 2.8:1 / 4.1:1, below WCAG AA).
    brandGradient: [Color(0xFF0369A1), Color(0xFF075985)],
  );

  static const dark = AppSemantics(
    successContainer: Color(0xFF14532D), onSuccessContainer: Color(0xFF86EFAC),
    infoContainer: Color(0xFF0C4A6E), onInfoContainer: Color(0xFF7DD3FC),
    warningContainer: Color(0xFF78350F), onWarningContainer: Color(0xFFFCD34D),
    // Dimmed pure sky (sky-700 → sky-800) for dark.
    brandGradient: [Color(0xFF0369A1), Color(0xFF075985)],
  );

  @override
  AppSemantics copyWith({
    Color? successContainer,
    Color? onSuccessContainer,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? warningContainer,
    Color? onWarningContainer,
    List<Color>? brandGradient,
  }) =>
      AppSemantics(
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
        infoContainer: infoContainer ?? this.infoContainer,
        onInfoContainer: onInfoContainer ?? this.onInfoContainer,
        warningContainer: warningContainer ?? this.warningContainer,
        onWarningContainer: onWarningContainer ?? this.onWarningContainer,
        brandGradient: brandGradient ?? this.brandGradient,
      );

  @override
  AppSemantics lerp(covariant AppSemantics? other, double t) {
    if (other == null) return this;
    return AppSemantics(
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      brandGradient: brandGradient.length == other.brandGradient.length
          ? [
              for (var i = 0; i < brandGradient.length; i++)
                Color.lerp(brandGradient[i], other.brandGradient[i], t)!,
            ]
          : (t < 0.5 ? brandGradient : other.brandGradient),
    );
  }
}

extension AppSemanticsX on BuildContext {
  AppSemantics get semantics => Theme.of(this).extension<AppSemantics>()!;
}
