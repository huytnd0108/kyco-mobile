import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/checkout/checkout_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

/// U4 checkout goldens — anon + signed-in, light + dark. Guest-composed from
/// public reads only (a fake api that never touches the network). NO baselines
/// are generated here (no --update-goldens); the integration pass regenerates
/// them deliberately.
class _FakeCheckoutApi extends KycoApi {
  _FakeCheckoutApi(super.c, super.t);

  @override
  Future<ServiceDetail> serviceDetail(int id) async => const ServiceDetail(
        id: 101,
        name: 'Vệ sinh nhà theo giờ',
        category: 'Vệ sinh',
        basePriceVnd: 480000,
        durationMinutes: 120,
        description: 'Dọn dẹp nhà cửa theo giờ, đội ngũ được đào tạo bài bản.',
      );

  @override
  Future<List<ActiveCity>> locationsTree() async => const [
        ActiveCity(id: 1, slug: 'ho-chi-minh', name: 'TP. Hồ Chí Minh', wards: [
          ActiveWard(code: 26734, name: 'Phường Bến Thành', provinceCode: 79),
          ActiveWard(code: 26737, name: 'Phường Bến Nghé', provinceCode: 79),
        ]),
      ];

  @override
  Future<List<Neighborhood>> neighborhoods(int wardCode) async => const [];
}

Future<void> pumpCheckout(
  WidgetTester tester, {
  required GoldenDevice device,
  required AuthState auth,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = device.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  final tokens = InMemoryTokenStore();
  final fakeApi = _FakeCheckoutApi(KycoApiClient(tokens: tokens), tokens);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      tokenStoreProvider.overrideWithValue(tokens),
      authControllerProvider.overrideWith(() => FakeAuthController(auth)),
      kycoApiProvider.overrideWithValue(fakeApi),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CheckoutScreen(serviceId: 101),
    ),
  ));
  await tester.pump(); // service future loading
  await tester.pump(); // service data + ward data
  await tester.pumpAndSettle(); // postframe seed + rebuild
}

void main() {
  // Anonymous checkout — the login gate shows in the submit slot.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.se]) {
    goldenTest('checkout anon ${d.name}', (t) async {
      await pumpCheckout(t, device: d, auth: Fakes.signedOut);
      await expectGolden(t, goldenName('checkout', 'anon', d, Brightness.light));
    });
  }

  // Signed-in checkout — the Confirm button shows.
  goldenTest('checkout signedin iphone16', (t) async {
    await pumpCheckout(t, device: GoldenDevice.iphone16, auth: Fakes.signedIn);
    await expectGolden(t, goldenName('checkout', 'signedin', GoldenDevice.iphone16, Brightness.light));
  });

  // Dark, both states.
  goldenTest('checkout anon dark se', (t) async {
    await pumpCheckout(t, device: GoldenDevice.se, auth: Fakes.signedOut, brightness: Brightness.dark);
    await expectGolden(t, goldenName('checkout', 'anon', GoldenDevice.se, Brightness.dark));
  });
  goldenTest('checkout signedin dark iphone16', (t) async {
    await pumpCheckout(t, device: GoldenDevice.iphone16, auth: Fakes.signedIn, brightness: Brightness.dark);
    await expectGolden(t, goldenName('checkout', 'signedin', GoldenDevice.iphone16, Brightness.dark));
  });
}
