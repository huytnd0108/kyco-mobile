import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/theme/app_semantics.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';

void main() {
  test('AppSemantics.lerp interpolates without throwing', () {
    final mid = AppSemantics.light.lerp(AppSemantics.dark, 0.5);
    expect(mid.brandGradient.length, 2);
    // extremes resolve to the endpoints
    expect(AppSemantics.light.lerp(AppSemantics.dark, 0).successContainer,
        AppSemantics.light.successContainer);
  });

  test('both themes expose AppSemantics and match web brand', () {
    final light = buildTheme(lightColorScheme);
    final dark = buildTheme(darkColorScheme);
    expect(light.extension<AppSemantics>(), isNotNull);
    expect(dark.extension<AppSemantics>(), isNotNull);
    expect(light.colorScheme.primary, const Color(0xFF0284C7)); // sky-600
    expect(dark.colorScheme.primary, const Color(0xFF3EBAF4));
    expect(dark.colorScheme.brightness, Brightness.dark);
  });
}
