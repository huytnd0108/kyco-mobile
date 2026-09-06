import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/provider_compliance/provider_cancellations_screen.dart';
import 'package:kyco_mobile/features/provider_compliance/provider_compliance_providers.dart';
import 'package:kyco_mobile/features/provider_compliance/provider_fine_appeal_screen.dart';
import 'package:kyco_mobile/features/provider_compliance/provider_fines_screen.dart';
import 'package:kyco_mobile/features/provider_compliance/provider_referrals_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

// ── Fixed, boundary-hunting fixtures ─────────────────────────────────────────
// A row per status branch, a long reason (ellipsis canary), and null paths.
final _fines = const FinesView(
  totalPendingVnd: 150000,
  totalChargedVnd: 480000,
  totalRefundedVnd: 90000,
  rows: [
    Fine(
      id: 91,
      amountVnd: 150000,
      status: 'pending',
      kind: 'late_arrival',
      reason: 'Đến trễ 25 phút so với giờ hẹn ban đầu của khách',
      bookingId: 4021,
      createdAt: '2026-08-20T09:15:00Z',
    ),
    Fine(
      id: 90,
      amountVnd: 330000,
      status: 'charged',
      kind: 'no_show',
      reason: 'Không đến làm việc',
      createdAt: '2026-08-11T02:00:00Z',
    ),
    Fine(
      id: 89,
      amountVnd: 90000,
      status: 'refunded',
      kind: 'quality',
      reason: null,
      createdAt: '2026-07-30T14:30:00Z',
    ),
  ],
);

final _fineDetailForm = const FineDetailView(
  fine: Fine(
    id: 91,
    amountVnd: 150000,
    status: 'pending',
    kind: 'late_arrival',
    reason: 'Đến trễ 25 phút',
    createdAt: '2026-08-20T09:15:00Z',
  ),
);

final _fineDetailExisting = FineDetailView(
  fine: _fineDetailForm.fine,
  existing: const FineAppeal(
    id: 5,
    fineId: 91,
    status: 'open',
    body: 'Khách đổi địa chỉ vào phút chót nên tôi đến trễ, mong được xem xét.',
    createdAt: '2026-08-21T01:00:00Z',
  ),
);

final _cancellations = const CancellationsView(
  countInWindow: 4, // one below the 7-day-suspend threshold → amber warning
  penaltyScore: 12,
  rows: [
    Cancellation(
      id: 30,
      reasonCode: 'sick',
      reasonText: 'Bị sốt cao đột ngột',
      penaltyScore: 3,
      bookingId: 5001,
      createdAt: '2026-08-24T03:00:00Z',
      scheduledAt: '2026-08-25T02:00:00Z',
    ),
    Cancellation(
      id: 29,
      reasonCode: 'other',
      reasonText: null,
      penaltyScore: 2,
      bookingId: null,
      createdAt: '2026-08-15T06:30:00Z',
    ),
  ],
);

final _referrals = const ReferralsView(
  referralCode: 'NGOCANH7',
  earnedExtraVnd: 750000,
  program: {'referrerRewardJobs': 100},
  referrals: [
    Referral(
      referralId: 1,
      status: 'active',
      jobsDone: 42,
      refereeName: 'Trần Thị B',
      refereeDistrict: 'Quận 1',
    ),
    Referral(
      referralId: 2,
      status: 'completed',
      jobsDone: 100,
      refereeName: 'Lê Văn C',
      refereeDistrict: 'Bình Thạnh',
    ),
    Referral(
      referralId: 3,
      status: 'pending_kyc',
      jobsDone: 0,
      refereeName: null,
      refereeDistrict: null,
    ),
  ],
);

/// Local pump for a plain-home screen (no routing needed at build time).
Future<void> _pump(
  WidgetTester tester, {
  required Widget screen,
  required List<Override> overrides,
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
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
      ...overrides,
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
  await tester.pump();
  await tester.pump();
}

/// The appeal screen reads `GoRouterState.of(context)`, so it needs a router.
Future<void> _pumpAppeal(
  WidgetTester tester, {
  required FineDetailView detail,
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
}) async {
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();

  final router = GoRouter(
    initialLocation: '/p/fines/91/appeal',
    routes: [
      GoRoute(
        path: '/p/fines/:id/appeal',
        builder: (_, _) => const ProviderFineAppealScreen(),
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      authControllerProvider.overrideWith(() => FakeAuthController(Fakes.signedIn)),
      fineDetailProvider(91).overrideWith((ref) => Future.value(detail)),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  const phone = GoldenDevice.iphone16;

  // ── Fines ──────────────────────────────────────────────────────────────────
  for (final b in [Brightness.light, Brightness.dark]) {
    goldenTest('fines ${b.name}', (t) async {
      await _pump(t,
          screen: const ProviderFinesScreen(),
          overrides: [finesProvider.overrideWith((ref) => Future.value(_fines))],
          device: phone,
          brightness: b);
      await expectGolden(t, goldenName('provider_compliance', 'fines', phone, b));
    });
  }

  // Fines empty — dashed EmptyState + zeroed tiles.
  goldenTest('fines empty', (t) async {
    await _pump(t,
        screen: const ProviderFinesScreen(),
        overrides: [
          finesProvider.overrideWith((ref) => Future.value(const FinesView())),
        ],
        device: phone);
    await expectGolden(t, goldenName('provider_compliance', 'fines_empty', phone, Brightness.light));
  });

  // ── Appeal (form + existing) ────────────────────────────────────────────────
  goldenTest('appeal form light', (t) async {
    await _pumpAppeal(t, detail: _fineDetailForm, device: phone);
    await expectGolden(t, goldenName('provider_compliance', 'appeal_form', phone, Brightness.light));
  });
  goldenTest('appeal existing dark', (t) async {
    await _pumpAppeal(t, detail: _fineDetailExisting, device: phone, brightness: Brightness.dark);
    await expectGolden(t, goldenName('provider_compliance', 'appeal_existing', phone, Brightness.dark));
  });

  // ── Cancellations ────────────────────────────────────────────────────────────
  for (final b in [Brightness.light, Brightness.dark]) {
    goldenTest('cancellations ${b.name}', (t) async {
      await _pump(t,
          screen: const ProviderCancellationsScreen(),
          overrides: [
            cancellationsProvider.overrideWith((ref) => Future.value(_cancellations)),
          ],
          device: phone,
          brightness: b);
      await expectGolden(t, goldenName('provider_compliance', 'cancellations', phone, b));
    });
  }

  // ── Referrals ────────────────────────────────────────────────────────────────
  for (final b in [Brightness.light, Brightness.dark]) {
    goldenTest('referrals ${b.name}', (t) async {
      await _pump(t,
          screen: const ProviderReferralsScreen(),
          overrides: [
            referralsProvider.overrideWith((ref) => Future.value(_referrals)),
          ],
          device: phone,
          brightness: b);
      await expectGolden(t, goldenName('provider_compliance', 'referrals', phone, b));
    });
  }

  // English, fines — locale-swap canary.
  goldenTest('fines en', (t) async {
    await _pump(t,
        screen: const ProviderFinesScreen(),
        overrides: [finesProvider.overrideWith((ref) => Future.value(_fines))],
        device: phone,
        locale: const Locale('en'));
    await expectGolden(t,
        goldenName('provider_compliance', 'fines', phone, Brightness.light, locale: const Locale('en')));
  });
}
