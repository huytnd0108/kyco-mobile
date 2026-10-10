import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/tasker_availability/tasker_availability_providers.dart';
import 'package:kyco_mobile/features/tasker_availability/tasker_availability_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

/// A boundary-hunting week: two-slot day, single long-slot day, empty days, an
/// override that turns a date off, and an override with a slot. Fixed minutes →
/// TZ-independent, deterministic layout.
const _week = AvailabilityWeek(
  weekly: {
    1: [AvailabilitySlot(start: 480, end: 720), AvailabilitySlot(start: 780, end: 1020)], // Mon 08–12, 13–17
    2: [AvailabilitySlot(start: 540, end: 1080)], // Tue 09–18
    3: [], // Wed off
    4: [AvailabilitySlot(start: 420, end: 660)], // Thu 07–11
    5: [AvailabilitySlot(start: 480, end: 720)], // Fri 08–12
    6: [], // Sat off
    0: [], // Sun off
  },
  dates: [
    AvailabilityDateOverride(date: '2026-09-10'), // off all day
    AvailabilityDateOverride(date: '2026-09-15', slots: [AvailabilitySlot(start: 420, end: 540)]), // 07–09
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  AvailabilityWeek week = _week,
  Object? error,
}) async {
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      authControllerProvider.overrideWith(() => FakeAuthController(Fakes.signedIn)),
      availabilityProvider.overrideWith((ref) {
        if (error != null) throw error;
        return Future.value(week);
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TaskerAvailabilityScreen(),
    ),
  ));
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

void main() {
  // Full weekly grid + overrides, light, two device widths.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.ipadAir]) {
    goldenTest('tasker_availability grid ${d.name}', (t) async {
      await _pump(t, device: d);
      await expectGolden(
          t, goldenName('tasker_availability', 'grid', d, Brightness.light));
    });
  }

  // Dark.
  goldenTest('tasker_availability dark 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, brightness: Brightness.dark);
    await expectGolden(t,
        goldenName('tasker_availability', 'grid', GoldenDevice.iphone16, Brightness.dark));
  });

  // English copy.
  goldenTest('tasker_availability en 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, locale: const Locale('en'));
    await expectGolden(
        t,
        goldenName('tasker_availability', 'grid', GoldenDevice.iphone16, Brightness.light,
            locale: const Locale('en')));
  });

  // §A10 GET pending (503) → retryable error state with the typed maintenance copy (light + dark).
  goldenTest('tasker_availability error 393', (t) async {
    await _pump(t,
        device: GoldenDevice.iphone16,
        error: ApiException('UNAVAILABLE', 'route pending', status: 503));
    await expectGolden(t,
        goldenName('tasker_availability', 'error', GoldenDevice.iphone16, Brightness.light));
  });

  goldenTest('tasker_availability error dark 393', (t) async {
    await _pump(t,
        device: GoldenDevice.iphone16,
        brightness: Brightness.dark,
        error: ApiException('UNAVAILABLE', 'route pending', status: 503));
    await expectGolden(t,
        goldenName('tasker_availability', 'error', GoldenDevice.iphone16, Brightness.dark));
  });
}
