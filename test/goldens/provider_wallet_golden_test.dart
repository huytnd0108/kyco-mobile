import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/provider_wallet/provider_wallet_providers.dart';
import 'package:kyco_mobile/features/provider_wallet/provider_wallet_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

// Fixed, boundary-hunting wallet data — one credit + one debit reason, and one
// payout per status branch (held/released/withdrawn), plus a null-bookingId row.
const _summary = WalletSummary(
  balanceVnd: 2480000,
  lifetimeEarningVnd: 48250000,
  lifetimeFeeVnd: 9650000,
  jobCount: 238,
  monthEarningVnd: 3120000,
);

const _txns = WalletTxnsData(
  items: [
    WalletTxn(id: 5, type: 'credit', amountVnd: 480000, reason: 'provider_earning', balanceAfterVnd: 2480000, createdAt: '2026-08-20T12:00:00Z'),
    WalletTxn(id: 4, type: 'credit', amountVnd: 50000, reason: 'tip', balanceAfterVnd: 2000000, createdAt: '2026-08-18T12:00:00Z'),
    WalletTxn(id: 3, type: 'debit', amountVnd: 96000, reason: 'commission_due', balanceAfterVnd: 1950000, createdAt: '2026-08-15T12:00:00Z'),
    WalletTxn(id: 2, type: 'debit', amountVnd: 1000000, reason: 'payout', balanceAfterVnd: 2046000, createdAt: '2026-08-10T12:00:00Z'),
    WalletTxn(id: 1, type: 'credit', amountVnd: 300000, reason: 'bonus', balanceAfterVnd: 3046000, createdAt: '2026-08-01T12:00:00Z'),
  ],
  hasMore: true,
);

const _payouts = PayoutsData(
  items: [
    Payout(id: 30, bookingId: 1042, amountVnd: 480000, platformFeeVnd: 96000, status: 'held', createdAt: '2026-08-20T12:00:00Z'),
    Payout(id: 29, bookingId: 1039, amountVnd: 350000, platformFeeVnd: 70000, status: 'released', releasedAt: '2026-08-12T12:00:00Z'),
    Payout(id: 28, bookingId: null, amountVnd: 1000000, platformFeeVnd: 0, status: 'withdrawn', createdAt: '2026-08-10T12:00:00Z'),
  ],
);

/// Fixed-state fake controllers (never touch the API).
class _FakeTxns extends WalletTxnsController {
  _FakeTxns(this._data);
  final WalletTxnsData _data;
  @override
  Future<WalletTxnsData> build() async => _data;
  @override
  Future<void> loadMore() async {}
}

class _FakePayouts extends PayoutsController {
  _FakePayouts(this._data);
  final PayoutsData _data;
  @override
  Future<PayoutsData> build() async => _data;
  @override
  Future<void> loadMore() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  WalletSummary summary = _summary,
  WalletTxnsData txns = _txns,
  PayoutsData payouts = _payouts,
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
      walletSummaryProvider.overrideWith((ref) => Future.value(summary)),
      walletTxnsControllerProvider.overrideWith(() => _FakeTxns(txns)),
      payoutsControllerProvider.overrideWith(() => _FakePayouts(payouts)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProviderWalletScreen(),
    ),
  ));
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

void main() {
  // Full wallet — balance, tiles, withdraw CTA, ledger + payouts.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.ipadAir]) {
    goldenTest('provider_wallet full ${d.name}', (t) async {
      await _pump(t, device: d);
      await expectGolden(t, goldenName('provider_wallet', 'full', d, Brightness.light));
    });
  }

  // Dark, full.
  goldenTest('provider_wallet dark 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, brightness: Brightness.dark);
    await expectGolden(t, goldenName('provider_wallet', 'full', GoldenDevice.iphone16, Brightness.dark));
  });

  // Empty ledger + payouts → dashed empty states.
  goldenTest('provider_wallet empty 393', (t) async {
    await _pump(t,
        device: GoldenDevice.iphone16,
        txns: const WalletTxnsData(items: []),
        payouts: const PayoutsData(items: []));
    await expectGolden(t, goldenName('provider_wallet', 'empty', GoldenDevice.iphone16, Brightness.light));
  });

  // English locale (reused ARB strings render in en; wallet copy stays vi until
  // the ARB keys land — see the unit report).
  goldenTest('provider_wallet en 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, locale: const Locale('en'));
    await expectGolden(t,
        goldenName('provider_wallet', 'full', GoldenDevice.iphone16, Brightness.light, locale: const Locale('en')));
  });
}
