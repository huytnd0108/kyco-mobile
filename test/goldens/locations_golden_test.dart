import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/locations/city_screen.dart';
import 'package:kyco_mobile/features/locations/locations_providers.dart';
import 'package:kyco_mobile/features/locations/locations_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kyco_mobile/features/services/services_providers.dart' show catalogTreeProvider;
import '_fakes.dart';
import '_harness.dart';

// ── Fixed fake geography (deterministic, boundary-hunting) ──────────────────
const _citySlug = 'ho-chi-minh';

List<ActiveCity> _cities() => const [
      ActiveCity(
        id: 1,
        slug: _citySlug,
        name: 'TP. Hồ Chí Minh',
        wards: [
          ActiveWard(code: 26734, name: 'Phường Bến Nghé', provinceCode: 79),
          ActiveWard(code: 26737, name: 'Phường Bến Thành', provinceCode: 79),
          ActiveWard(code: 26740, name: 'Phường Cầu Ông Lãnh', provinceCode: 79),
        ],
      ),
      ActiveCity(
        id: 2,
        slug: 'ha-noi',
        name: 'Thủ đô Hà Nội — trung tâm hành chính quốc gia', // ellipsis canary
        wards: [ActiveWard(code: 1, name: 'Phường Hàng Bạc', provinceCode: 1)],
      ),
      ActiveCity(id: 3, slug: 'da-nang', name: 'Đà Nẵng'),
    ];

CityLanding _landing() => const CityLanding(
      city: CityInfo(id: 1, slug: _citySlug, name: 'TP. Hồ Chí Minh'),
      services: [
        ServiceSummary(
            id: 101,
            slug: 'don-nha-theo-gio',
            name: 'Vệ sinh nhà theo giờ',
            category: 'cleaning',
            basePriceVnd: 480000,
            durationMinutes: 120),
        ServiceSummary(
            id: 102,
            name: 'Vệ sinh sofa – nệm – rèm cửa cao cấp định kỳ', // ellipsis canary
            category: 'cleaning',
            basePriceVnd: 12345678,
            durationMinutes: 240),
        ServiceSummary(
            id: 103, name: 'Tổng vệ sinh', category: 'cleaning', basePriceVnd: 2400000),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  required Widget screen,
  required GoldenDevice device,
  required List<Override> overrides,
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
      // Guest-first: locations are fully public — render signed-out.
      authControllerProvider.overrideWith(() => FakeAuthController(Fakes.signedOut)),
      catalogTreeProvider.overrideWith((ref) => Future.value(Fakes.catalogTree)),
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
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

void main() {
  // Two window sizes (compact phone + medium tablet), each light + dark.
  const sizes = [GoldenDevice.se, GoldenDevice.ipadAir];

  // /locations — active-city grid.
  for (final d in sizes) {
    for (final b in Brightness.values) {
      goldenTest('locations list ${d.name} ${b.name}', (t) async {
        await _pump(
          t,
          screen: const LocationsScreen(),
          device: d,
          brightness: b,
          overrides: [
            locationsTreeProvider.overrideWith((ref) => Future.value(_cities())),
          ],
        );
        await expectGolden(t, goldenName('locations', 'list', d, b));
      });
    }
  }

  // /locations/:city — city landing with a services preview grid.
  for (final d in sizes) {
    for (final b in Brightness.values) {
      goldenTest('locations city ${d.name} ${b.name}', (t) async {
        await _pump(
          t,
          screen: const CityScreen(slug: _citySlug),
          device: d,
          brightness: b,
          overrides: [
            cityProvider(_citySlug).overrideWith((ref) => Future.value(_landing())),
          ],
        );
        await expectGolden(t, goldenName('city', 'landing', d, b));
      });
    }
  }
}
