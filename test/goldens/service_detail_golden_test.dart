import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/service_detail/service_detail_providers.dart';
import 'package:kyco_mobile/features/service_detail/service_detail_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import 'package:kyco_mobile/features/services/services_providers.dart' show catalogTreeProvider;
import '_harness.dart';

// Fixed, boundary-hunting fakes (never network). imageUrl null → deterministic
// placeholder; one long name pins the maxLines:2 ellipsis in the hero.
const _detail = ServiceDetail(
  id: 3,
  slug: 've-sinh-nha',
  name: 'Vệ sinh sofa – nệm – rèm cửa cao cấp định kỳ theo tháng',
  category: 'home-cleaning',
  subcategory: 'sofa',
  basePriceVnd: 480000,
  durationMinutes: 120,
  description:
      'Đội ngũ đã qua KYC, dụng cụ chuẩn, bảo hiểm trọn gói.\nĐặt lịch linh hoạt, đổi lịch miễn phí.',
);

const _related = <ServiceSummary>[
  ServiceSummary(
      id: 11, name: 'Tổng vệ sinh', category: 'home-cleaning', basePriceVnd: 350000, durationMinutes: 90),
  ServiceSummary(
      id: 12, name: 'Vệ sinh máy lạnh', category: 'ac', basePriceVnd: 250000, durationMinutes: 60),
  ServiceSummary(id: 13, name: 'Giặt thảm', category: 'home-cleaning', basePriceVnd: 150000),
];

/// Category slugs on service rows resolve to these display names (as the real
/// catalogue tree does) - the card/detail never prints the raw slug.
const _tree = <CatalogCategory>[
  CatalogCategory(slug: 'home-cleaning', nameVi: 'Vệ sinh nhà', nameEn: 'Home cleaning', subcategories: [
    CatalogSubcategory(slug: 'sofa', nameVi: 'Sofa & nệm', nameEn: 'Sofa & mattress'),
  ]),
  CatalogCategory(slug: 'ac', nameVi: 'Điện lạnh', nameEn: 'Air conditioning'),
];

/// A reviews controller with fixed data + a non-null cursor → the "load more"
/// affordance renders in the golden.
class _FakeReviews extends ReviewsController {
  @override
  Future<ReviewsState> build(int id) async => const ReviewsState(
        reviews: [
          Review(
              id: 90,
              rating: 5,
              comment: 'Rất sạch sẽ, đúng giờ. Sẽ đặt lại!',
              displayName: 'Ngọc A.',
              createdAt: '2026-01-10'),
          Review(
              id: 89,
              rating: 4,
              comment: null,
              displayName: 'Minh T.',
              createdAt: '2026-01-02'),
        ],
        aggregate: ReviewAggregate(count: 12, average: 4.5),
        nextCursor: 88,
      );
}

Future<void> pumpServiceDetail(
  WidgetTester tester, {
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
      // Guest — proves the sticky CTA is visible without a session.
      authControllerProvider.overrideWith(() => FakeAuthController(Fakes.signedOut)),
      serviceDetailProvider.overrideWith((ref, id) => Future.value(_detail)),
      relatedServicesProvider.overrideWith((ref, id) => Future.value(_related)),
      reviewsControllerProvider.overrideWith(_FakeReviews.new),
      catalogTreeProvider.overrideWith((ref) => Future.value(_tree)),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ServiceDetailScreen(id: 3),
    ),
  ));
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

void main() {
  // light + dark × 2 sizes (compact + medium).
  const devices = [GoldenDevice.se, GoldenDevice.ipadAir];
  for (final d in devices) {
    for (final b in Brightness.values) {
      goldenTest('service_detail data ${d.name} ${b.name}', (t) async {
        await pumpServiceDetail(t, device: d, brightness: b);
        await expectGolden(t, goldenName('service_detail', 'data', d, b));
      });
    }
  }
}
