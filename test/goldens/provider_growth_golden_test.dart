import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/provider_growth/provider_bonuses_screen.dart';
import 'package:kyco_mobile/features/provider_growth/provider_goals_screen.dart';
import 'package:kyco_mobile/features/provider_growth/provider_growth_providers.dart';
import 'package:kyco_mobile/features/provider_growth/provider_leaderboard_screen.dart';
import 'package:kyco_mobile/features/provider_growth/provider_vip_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

// ── Fixtures (fixed, boundary-hunting — never random, all money server-side) ──

final _bonuses = ProviderBonuses(
  weekly: const [
    Bonus(kind: 'weekly_jobs', amountVnd: 500000, eligible: true, raw: {
      'kind': 'weekly_jobs',
      'earned': true,
      'amountVnd': 500000,
      'reason': 'Đạt 22 job (≥20) · hạng gold (×1.2)',
    }),
    Bonus(kind: 'punctuality', amountVnd: 200000, raw: {
      'kind': 'punctuality',
      'earned': false,
      'amountVnd': 0,
      'reason': 'Cần ≥3 tuần chuyên cần, hiện 1',
    }),
  ],
  monthly: const [
    Bonus(kind: 'monthly_revenue', amountVnd: 1000000, eligible: true, raw: {
      'kind': 'monthly_revenue',
      'earned': true,
      'amountVnd': 1000000,
      'reason': 'Doanh thu 15.000.000đ · hạng gold (×1.2)',
    }),
    Bonus(kind: 'rating', amountVnd: 0, raw: {
      'kind': 'rating',
      'earned': false,
      'amountVnd': 0,
      'reason': 'Cần ≥10 review, hiện có 6',
    }),
  ],
  history: const [
    BonusHistoryItem(
      id: 91,
      kind: 'weekly_jobs',
      amountVnd: 450000,
      status: 'paid',
      periodStart: '2026-08-11',
      periodEnd: '2026-08-17',
      paidAt: '2026-08-19T09:00:00Z',
    ),
    BonusHistoryItem(
      id: 88,
      kind: 'monthly_revenue',
      amountVnd: 900000,
      status: 'paid',
      periodStart: '2026-07-01',
      periodEnd: '2026-07-31',
      paidAt: '2026-08-02T09:00:00Z',
    ),
  ],
);

const _goals = GoalsData(
  goals: [
    // periodKey is left generic; the screen matches on the current week/month
    // key at render time, so these exercise the "no goal set" empty targets too.
    Goal(id: 1, periodKind: 'week', periodKey: '2026-W36', targetJobs: 20, targetVnd: 3000000),
    Goal(id: 2, periodKind: 'month', periodKey: '2026-09', targetJobs: 80, targetVnd: 12000000),
  ],
  monthVndAchieved: 7200000,
);

const _leaderboard = LeaderboardView(
  scope: 'week',
  districts: ['Quận 1', 'Quận 3', 'Bình Thạnh'],
  myRank: 2,
  rows: [
    LeaderboardRow(
        providerId: 11,
        name: 'Nguyễn Văn Bình',
        district: 'Quận 1',
        tier: 'platinum',
        jobs: 34,
        revenueVnd: 18500000,
        rank: 1),
    LeaderboardRow(
        providerId: 7,
        name: 'Ngọc Anh',
        district: 'Quận 3',
        tier: 'gold',
        jobs: 28,
        revenueVnd: 15200000,
        rank: 2),
    LeaderboardRow(
        providerId: 22,
        name: 'Trần Thị Mỹ Hạnh Nguyễn', // long-name ellipsis canary
        district: 'Bình Thạnh',
        tier: 'silver',
        jobs: 19,
        revenueVnd: 9800000,
        rank: 3),
    LeaderboardRow(
        providerId: 5,
        name: 'An',
        district: null,
        tier: 'bronze',
        jobs: 4,
        revenueVnd: 1200000,
        rank: 4),
  ],
);

/// Pumps a provider_growth [screen] with every owned provider overridden by a
/// fixture (no network). [tier] drives the VIP gate.
Future<void> _pump(
  WidgetTester tester, {
  required Widget screen,
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  String? tier,
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
      bonusesProvider.overrideWith((ref) => Future.value(_bonuses)),
      goalsProvider.overrideWith((ref) => Future.value(_goals)),
      leaderboardProvider.overrideWith((ref) => Future.value(_leaderboard)),
      providerTierProvider.overrideWith((ref) => Future.value(tier)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: screen,
    ),
  ));
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

void main() {
  const d = GoldenDevice.iphone16;

  // Bonuses — light + dark.
  goldenTest('growth bonuses light', (t) async {
    await _pump(t, screen: const ProviderBonusesScreen(), device: d);
    await expectGolden(t, goldenName('provider_growth_bonuses', 'data', d, Brightness.light));
  });
  goldenTest('growth bonuses dark', (t) async {
    await _pump(t,
        screen: const ProviderBonusesScreen(), device: d, brightness: Brightness.dark);
    await expectGolden(t, goldenName('provider_growth_bonuses', 'data', d, Brightness.dark));
  });

  // Goals — light (targets + one live income bar).
  goldenTest('growth goals light', (t) async {
    await _pump(t, screen: const ProviderGoalsScreen(), device: d);
    await expectGolden(t, goldenName('provider_growth_goals', 'data', d, Brightness.light));
  });

  // Leaderboard — light + dark (self row highlighted, rank surfaced).
  goldenTest('growth leaderboard light', (t) async {
    await _pump(t, screen: const ProviderLeaderboardScreen(), device: d);
    await expectGolden(t, goldenName('provider_growth_leaderboard', 'data', d, Brightness.light));
  });
  goldenTest('growth leaderboard dark', (t) async {
    await _pump(t,
        screen: const ProviderLeaderboardScreen(), device: d, brightness: Brightness.dark);
    await expectGolden(t, goldenName('provider_growth_leaderboard', 'data', d, Brightness.dark));
  });

  // VIP — platinum shows perks; non-platinum shows the upsell.
  goldenTest('growth vip perks 393', (t) async {
    await _pump(t, screen: const ProviderVipScreen(), device: d, tier: 'platinum');
    await expectGolden(t, goldenName('provider_growth_vip', 'perks', d, Brightness.light));
  });
  goldenTest('growth vip upsell 393', (t) async {
    await _pump(t, screen: const ProviderVipScreen(), device: d, tier: 'gold');
    await expectGolden(t, goldenName('provider_growth_vip', 'upsell', d, Brightness.light));
  });
}
