import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/taskers/tasker_providers.dart';
import 'package:kyco_mobile/features/taskers/tasker_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

const _verified = TaskerPublicProfile(
  id: 42,
  displayName: 'Trần Thị Mỹ Hạnh',
  avatarUrl: null, // null → deterministic initials avatar (no network)
  tier: 'gold',
  verified: true,
  rating: 4.5,
  jobsCompleted: 238,
  joinedAt: '2023-04-18T00:00:00Z',
  reviewSummary: ReviewAggregate(count: 187, average: 4.5),
);

const _unverified = TaskerPublicProfile(
  id: 7,
  displayName: 'An',
  avatarUrl: null,
  tier: 'bronze',
  verified: false,
  rating: 0,
  jobsCompleted: 0,
  joinedAt: null,
  reviewSummary: ReviewAggregate.empty,
);

/// Local pump injecting the tasker-public family (frozen shared harness can't).
/// [error] overrides the family to throw (for the 404 not-found state).
Future<void> _pump(
  WidgetTester tester, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  TaskerPublicProfile profile = _verified,
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
      authControllerProvider.overrideWith(() => FakeAuthController(Fakes.signedOut)),
      taskerPublicProvider.overrideWith((ref, id) {
        if (error != null) throw error;
        return Future.value(profile);
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TaskerScreen(id: 42),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  // Verified, gold tier — full profile.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.ipadAir]) {
    goldenTest('tasker verified ${d.name}', (t) async {
      await _pump(t, device: d);
      await expectGolden(t, goldenName('tasker', 'verified', d, Brightness.light));
    });
  }

  // Dark, verified.
  goldenTest('tasker dark 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, brightness: Brightness.dark);
    await expectGolden(t, goldenName('tasker', 'verified', GoldenDevice.iphone16, Brightness.dark));
  });

  // Unverified, no join date, zero jobs — no verified badge.
  goldenTest('tasker unverified 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, profile: _unverified);
    await expectGolden(t, goldenName('tasker', 'unverified', GoldenDevice.iphone16, Brightness.light));
  });

  // 404 → friendly not-found.
  goldenTest('tasker notfound 393', (t) async {
    await _pump(t,
        device: GoldenDevice.iphone16, error: ApiException('NOT_FOUND', 'not found', status: 404));
    await expectGolden(t, goldenName('tasker', 'notfound', GoldenDevice.iphone16, Brightness.light));
  });

  // English, verified.
  goldenTest('tasker en 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, locale: const Locale('en'));
    await expectGolden(t,
        goldenName('tasker', 'verified', GoldenDevice.iphone16, Brightness.light, locale: const Locale('en')));
  });
}
