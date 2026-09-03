import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/bookings/bookings_providers.dart';
import 'package:kyco_mobile/features/home/home_providers.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';

/// The 8-device matrix (research doc). Names become golden filename segments.
enum GoldenDevice {
  se(Size(375, 667)), // iPhone SE — compact, smallest phone
  iphone16(Size(393, 852)), // iPhone 16 — compact baseline
  proMax(Size(430, 932)), // iPhone 16 Pro Max — compact
  slideOver(Size(320, 1180)), // iPad 1/3 Slide Over — compact overflow canary
  halfSplit(Size(507, 1180)), // iPad 1/2 Split View — compact
  ipadMini(Size(744, 1133)), // iPad mini portrait — medium
  ipadAir(Size(820, 1180)), // iPad Air portrait — medium
  pro13(Size(1376, 1024)); // iPad Pro 13" landscape — expanded, two-pane

  const GoldenDevice(this.size);
  final Size size;
}

/// Golden PNGs are Linux-canonical; skip off-Linux so a macOS teammate's
/// `flutter test` stays green (regen only via tool/update_goldens.sh on Linux).
void goldenTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, body, skip: !Platform.isLinux);

/// Pumps [screen] in a production-equivalent MaterialApp with every networked /
/// persisted provider replaced by fakes (no network, no real storage).
Future<void> pumpGoldenScreen(
  WidgetTester tester, {
  required Widget screen,
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  double textScale = 1.0,
  AuthState auth = Fakes.signedIn,
  HomeComposite? home,
  List<Booking>? bookings,
  int? selectedBookingId,
}) async {
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = 1.0; // logical == physical → exact dp
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      authControllerProvider.overrideWith(() => FakeAuthController(auth)),
      homeProvider.overrideWith((ref) => Future.value(home ?? Fakes.home())),
      bookingsProvider.overrideWith((ref) => Future.value(bookings ?? Fakes.bookings())),
      if (selectedBookingId != null)
        selectedBookingIdProvider.overrideWith((ref) => selectedBookingId),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: screen,
    ),
  ));
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

/// Golden assertion that names an overflow explicitly before diffing pixels.
Future<void> expectGolden(WidgetTester tester, String name) async {
  final err = tester.takeException();
  if (err != null) {
    fail('Layout exception (likely RenderFlex overflow) before golden "$name": $err');
  }
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('_goldens/$name.png'));
}

/// Filename: `screen/state_WxH_light|dark[_x13][_en].png`
String goldenName(String screen, String state, GoldenDevice d, Brightness b,
        {double textScale = 1.0, Locale? locale}) =>
    '$screen/${state}_${d.size.width.toInt()}x${d.size.height.toInt()}'
    '_${b == Brightness.dark ? 'dark' : 'light'}'
    '${textScale != 1.0 ? '_x${(textScale * 10).round()}' : ''}'
    '${locale?.languageCode == 'en' ? '_en' : ''}';
