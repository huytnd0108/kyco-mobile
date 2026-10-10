// UX-M47: WCAG AA contrast over the theme ColorScheme + semantic tokens, light
// AND dark. Text pairs need 4.5:1, graphics (star glyphs, icons) 3:1.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/theme/app_semantics.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';

/// WCAG 2.x contrast ratio; [Color.computeLuminance] is the WCAG relative
/// luminance. Alpha is composited over [over] first.
double contrast(Color fg, Color bg, {Color over = Colors.white}) {
  Color flat(Color c, Color base) => Color.alphaBlend(c, base);
  final b = flat(bg, over);
  final f = flat(fg, b);
  final l1 = f.computeLuminance(), l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final schemes = {'light': lightColorScheme, 'dark': darkColorScheme};

  for (final e in schemes.entries) {
    final cs = e.value;
    group('ColorScheme ${e.key}', () {
      final pairs = <String, (Color, Color)>{
        'onPrimary on primary (filled buttons, badges)': (cs.onPrimary, cs.primary),
        'onSecondary on secondary': (cs.onSecondary, cs.secondary),
        'onTertiary on tertiary': (cs.onTertiary, cs.tertiary),
        'onPrimaryContainer on primaryContainer': (cs.onPrimaryContainer, cs.primaryContainer),
        'onSecondaryContainer on secondaryContainer': (cs.onSecondaryContainer, cs.secondaryContainer),
        'onTertiaryContainer on tertiaryContainer': (cs.onTertiaryContainer, cs.tertiaryContainer),
        'onError on error': (cs.onError, cs.error),
        'error text/outline on surface': (cs.error, cs.surface),
        'error text on card': (cs.error, cs.surfaceContainerLow),
        'onErrorContainer on errorContainer': (cs.onErrorContainer, cs.errorContainer),
        'onSurface on surface': (cs.onSurface, cs.surface),
        'onSurfaceVariant on surface': (cs.onSurfaceVariant, cs.surface),
        'onSurfaceVariant on surfaceContainer (chips/subtitles)': (cs.onSurfaceVariant, cs.surfaceContainer),
        'onSurfaceVariant on surfaceContainerHighest (muted)': (cs.onSurfaceVariant, cs.surfaceContainerHighest),
        'onSurfaceVariant on card': (cs.onSurfaceVariant, cs.surfaceContainerLow),
        'primary text/link on surface': (cs.primary, cs.surface),
      };
      pairs.forEach((name, p) {
        test('$name >= 4.5:1', () {
          final r = contrast(p.$1, p.$2);
          expect(r, greaterThanOrEqualTo(4.5), reason: '${r.toStringAsFixed(2)}:1');
        });
      });
    });
  }

  for (final e in {'light': AppSemantics.light, 'dark': AppSemantics.dark}.entries) {
    final s = e.value;
    group('AppSemantics ${e.key}', () {
      final pairs = <String, (Color, Color)>{
        'success': (s.onSuccessContainer, s.successContainer),
        'info': (s.onInfoContainer, s.infoContainer),
        'warning': (s.onWarningContainer, s.warningContainer),
        'white on brand gradient start': (Colors.white, s.brandGradient.first),
        'white on brand gradient end': (Colors.white, s.brandGradient.last),
      };
      pairs.forEach((name, p) {
        test('$name >= 4.5:1', () {
          final r = contrast(p.$1, p.$2);
          expect(r, greaterThanOrEqualTo(4.5), reason: '${r.toStringAsFixed(2)}:1');
        });
      });
      test('warning / success foreground on the page surface >= 4.5:1', () {
        final cs = e.key == 'light' ? lightColorScheme : darkColorScheme;
        expect(contrast(s.onWarningContainer, cs.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(s.onSuccessContainer, cs.surface), greaterThanOrEqualTo(4.5));
      });
    });
  }

  test('rating star glyph colour >= 3:1 (graphic) on light and dark surfaces', () {
    const star = Color(0xFFB45309); // RatingStars filled colour
    expect(contrast(star, lightColorScheme.surface), greaterThanOrEqualTo(3));
    expect(contrast(star, lightColorScheme.surfaceContainerLowest), greaterThanOrEqualTo(3));
    expect(contrast(star, darkColorScheme.surface), greaterThanOrEqualTo(3));
    expect(contrast(star, darkColorScheme.surfaceContainerLow), greaterThanOrEqualTo(3));
  });

  test('tone pills used on the tasker dashboard / referrals >= 4.5:1', () {
    const pills = {
      'good': (Color(0xFF15803D), Color(0xFFDCFCE7)),
      'warn': (Color(0xFFB45309), Color(0xFFFEF3C7)),
      'bad': (Color(0xFFBE123C), Color(0xFFFFE4E6)),
      'referral-active': (Color(0xFF047857), Color(0xFFD1FAE5)),
    };
    pills.forEach((k, p) => expect(contrast(p.$1, p.$2), greaterThanOrEqualTo(4.5), reason: k));
  });
}
