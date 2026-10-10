import 'package:flutter/material.dart';

import 'app_semantics.dart';

/// Kyco brand seed = webapp "Sky Branding" primary (sky-600, hsl(200 98% 39%)).
/// Filled roles use sky-700 (0369A1): white on sky-600 is only 4.10:1, below
/// the WCAG AA 4.5:1 floor for button labels; sky-700 gives 5.93:1 (UX-M47).
/// Both schemes come from ColorScheme.fromSeed; .copyWith pins the roles the
/// webapp defines so light AND dark match kyco.vn exactly, while the seed fills
/// everything the web doesn't specify (tertiary, inverse*, shadow, …).
const kSeed = Color(0xFF0284C7); // sky-600

final ColorScheme lightColorScheme = ColorScheme.fromSeed(seedColor: kSeed).copyWith(
  primary: const Color(0xFF0369A1), // sky-700 — white on it = 5.93:1
  onPrimary: Colors.white,
  primaryContainer: const Color(0xFFE0F2FE), // web accent (sky-100)
  onPrimaryContainer: const Color(0xFF0369A1), // web accent-fg (sky-700)
  secondary: const Color(0xFF0369A1), // sky-700 (white on sky-500 was 2.77:1)
  onSecondary: Colors.white,
  secondaryContainer: const Color(0xFFE0F2FE), // sky-100 (keep sky family)
  onSecondaryContainer: const Color(0xFF0369A1), // sky-700
  // Pin tertiary to the sky family so fromSeed's algorithmic off-hue never
  // leaks into chips/containers — the whole palette stays sky/slate like web.
  tertiary: const Color(0xFF0369A1),
  onTertiary: Colors.white,
  tertiaryContainer: const Color(0xFFE0F2FE),
  onTertiaryContainer: const Color(0xFF0369A1),
  surfaceTint: const Color(0xFF0369A1), // elevation tint = sky primary
  error: const Color(0xFFC52020),
  onError: const Color(0xFFFAFAFA),
  errorContainer: const Color(0xFFFEE2E2), // red-100
  onErrorContainer: const Color(0xFF991B1B), // red-800
  surface: const Color(0xFFFAFDFF), // web background (faint sky tint)
  onSurface: const Color(0xFF0F172A), // slate-900
  surfaceContainerLowest: Colors.white, // web card
  surfaceContainerLow: Colors.white,
  surfaceContainer: const Color(0xFFF1F5F9), // NavigationBar bg — web muted
  surfaceContainerHighest: const Color(0xFFF1F5F9), // web muted (slate-100)
  onSurfaceVariant: const Color(0xFF475569), // slate-600: 6.9:1 on muted (slate-500 was 4.34)
  outlineVariant: const Color(0xFFD7E0EA), // web border (slate-200)
);

final ColorScheme darkColorScheme =
    ColorScheme.fromSeed(seedColor: kSeed, brightness: Brightness.dark).copyWith(
  primary: const Color(0xFF3EBAF4), // web dark primary (lighter sky)
  onPrimary: const Color(0xFF080C17),
  primaryContainer: const Color(0xFF204A60), // web dark accent
  onPrimaryContainer: const Color(0xFFFAFAFA),
  secondary: const Color(0xFF0369A1),
  onSecondary: const Color(0xFFFAFAFA),
  secondaryContainer: const Color(0xFF204A60),
  onSecondaryContainer: const Color(0xFFE0F2FE),
  tertiary: const Color(0xFF3EBAF4),
  onTertiary: const Color(0xFF080C17),
  tertiaryContainer: const Color(0xFF204A60),
  onTertiaryContainer: const Color(0xFFE0F2FE),
  surfaceTint: const Color(0xFF3EBAF4),
  error: const Color(0xFFF87171), // red-400: 6.7:1 on the dark card (D02F2F was 3.65:1)
  onError: const Color(0xFF080C17),
  errorContainer: const Color(0xFF7F1D1D), // red-900
  onErrorContainer: const Color(0xFFFECACA), // red-200 — ≥4.5:1 on red-900
  surface: const Color(0xFF080C17), // web dark background
  onSurface: const Color(0xFFFAFAFA),
  surfaceContainerLowest: const Color(0xFF080C17),
  surfaceContainerLow: const Color(0xFF0C1322), // web dark card
  surfaceContainer: const Color(0xFF0C1322),
  surfaceContainerHighest: const Color(0xFF1F2937), // web dark muted
  onSurfaceVariant: const Color(0xFF9CA3AF), // web dark muted-fg
  outlineVariant: const Color(0xFF1F2937), // web dark border
);

/// Radius from the web design system (0.625rem = 10px).
const double kRadius = 10;

ThemeData buildTheme(ColorScheme cs) {
  final isDark = cs.brightness == Brightness.dark;
  final radius = BorderRadius.circular(kRadius);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cs.surface,
    extensions: [isDark ? AppSemantics.dark : AppSemantics.light],
    cardTheme: CardThemeData(
      color: isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: cs.outlineVariant),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    // Selected booking tile: readable on primaryContainer (AA-compliant).
    listTileTheme: ListTileThemeData(selectedColor: cs.onPrimaryContainer),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        // Min HEIGHT 48 only. Size.fromHeight sets width=infinity which makes a
        // FilledButton demand infinite width as a non-flex child in a Row
        // (e.g. the sticky CTA). Full-width buttons rely on stretch columns.
        minimumSize: const Size(0, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
  );
}
