import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/subscriptions/subscriptions_providers.dart';
import 'package:kyco_mobile/features/subscriptions/subscriptions_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

// Fixed, deterministic fixtures (boundary-hunting: one long body, a null-price
// plan, one plan without a duration).
final _plans = <PlanCard>[
  const PlanCard(
    id: 1,
    slug: 'weekly',
    title: 'Gói tuần',
    body: 'Dọn dẹp định kỳ mỗi tuần với người quen tay, giá tốt hơn đặt lẻ.',
    priceMonthlyVnd: 1200000,
    durationMonths: 3,
  ),
  const PlanCard(
    id: 2,
    slug: 'biweekly',
    title: 'Gói 2 tuần',
    body: 'Cân bằng giữa chi phí và sự sạch sẽ.',
    priceMonthlyVnd: 720000,
    durationMonths: 6,
  ),
  const PlanCard(id: 3, slug: 'trial', title: 'Dùng thử', body: null),
];

final _mySubs = <SubscriptionItem>[
  const SubscriptionItem(
    id: 501,
    serviceId: 10,
    frequency: 'weekly',
    status: 'active',
    packageMonths: 3,
    monthlyAmountVnd: 1200000,
    totalAmountVnd: 3600000,
    sessionsTotal: 12,
    sessionsCompleted: 5,
    flexCreditsTotal: 2,
    flexCreditsUsed: 1,
    nextChargeAt: '2026-10-01T00:00:00Z',
    startedAt: '2026-07-01T00:00:00Z',
  ),
  const SubscriptionItem(
    id: 502,
    frequency: 'biweekly',
    status: 'paused',
    packageMonths: 6,
    monthlyAmountVnd: 720000,
    totalAmountVnd: 4320000,
    sessionsTotal: 12,
    sessionsCompleted: 12,
    flexCreditsTotal: 0,
    flexCreditsUsed: 0,
  ),
];

/// Local pump — mirrors [pumpGoldenScreen] but injects the subscriptions
/// providers (the shared harness can't, and is frozen).
Future<void> _pump(
  WidgetTester tester, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  AuthState auth = Fakes.signedOut,
  List<PlanCard>? plans,
  List<SubscriptionItem>? subs,
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
      authControllerProvider.overrideWith(() => FakeAuthController(auth)),
      plansProvider.overrideWith((ref) => Future.value(plans ?? _plans)),
      mySubscriptionsProvider.overrideWith((ref) => Future.value(subs ?? _mySubs)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SubscriptionsScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  // Guest browse — plans only, no own-subscriptions block.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.ipadAir]) {
    goldenTest('subscriptions guest ${d.name}', (t) async {
      await _pump(t, device: d, auth: Fakes.signedOut);
      await expectGolden(t, goldenName('subscriptions', 'guest', d, Brightness.light));
    });
  }

  // Signed-in — own subscriptions + plans.
  goldenTest('subscriptions signedin 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, auth: Fakes.signedIn);
    await expectGolden(t, goldenName('subscriptions', 'in', GoldenDevice.iphone16, Brightness.light));
  });

  // Dark, signed-in.
  goldenTest('subscriptions dark 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, auth: Fakes.signedIn, brightness: Brightness.dark);
    await expectGolden(t, goldenName('subscriptions', 'in', GoldenDevice.iphone16, Brightness.dark));
  });

  // Empty plans (guest) — dashed EmptyState.
  goldenTest('subscriptions empty 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, auth: Fakes.signedOut, plans: const []);
    await expectGolden(t, goldenName('subscriptions', 'empty', GoldenDevice.iphone16, Brightness.light));
  });

  // English, guest.
  goldenTest('subscriptions en 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, auth: Fakes.signedOut, locale: const Locale('en'));
    await expectGolden(t,
        goldenName('subscriptions', 'guest', GoldenDevice.iphone16, Brightness.light, locale: const Locale('en')));
  });
}
