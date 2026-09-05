import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/services/services_providers.dart';
import 'package:kyco_mobile/features/services/services_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';

import '_harness.dart';

/// Fixed-state feed for goldens — never hits the network; `build` returns the
/// injected page verbatim (loadMore is never exercised in a static golden).
class _FixedFeed extends ServicesFeedController {
  _FixedFeed(this._fixed);
  final ServicesFeed _fixed;
  @override
  Future<ServicesFeed> build(ServicesFilter arg) async => _fixed;
}

List<CatalogCategory> _cats() => const [
      CatalogCategory(slug: 'cleaning', nameVi: 'Vệ sinh', nameEn: 'Cleaning', subcategories: [
        CatalogSubcategory(slug: 'hourly', nameVi: 'Theo giờ', nameEn: 'Hourly'),
        CatalogSubcategory(slug: 'deep', nameVi: 'Tổng vệ sinh', nameEn: 'Deep clean'),
        CatalogSubcategory(slug: 'ac', nameVi: 'Máy lạnh', nameEn: 'Air-con'),
      ]),
      CatalogCategory(slug: 'laundry', nameVi: 'Giặt sofa – nệm', nameEn: 'Laundry'),
      CatalogCategory(slug: 'repair', nameVi: 'Sửa chữa', nameEn: 'Repair'),
    ];

// imageUrl null → deterministic placeholder (no network). One very long name
// pins the maxLines:2 ellipsis; null duration + a big price exercise the footer.
ServicesFeed _feed() => const ServicesFeed(
      items: [
        ServiceSummary(id: 1, name: 'Vệ sinh nhà theo giờ', category: 'Vệ sinh', basePriceVnd: 120000, durationMinutes: 120),
        ServiceSummary(id: 2, name: 'Vệ sinh sofa – nệm – rèm cửa cao cấp định kỳ trọn gói', category: 'Vệ sinh', basePriceVnd: 990000),
        ServiceSummary(id: 3, name: 'Vệ sinh máy lạnh treo tường', category: 'Vệ sinh', basePriceVnd: 250000),
        ServiceSummary(id: 4, name: 'Tổng vệ sinh', category: 'Vệ sinh', basePriceVnd: 1200000),
        ServiceSummary(id: 5, name: 'Giặt thảm', category: 'Giặt', basePriceVnd: 350000, durationMinutes: 60),
      ],
      hasMore: true,
    );

Future<void> pumpServices(
  WidgetTester t, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  ServicesScreen screen = const ServicesScreen(),
  List<CatalogCategory>? cats,
  ServicesFeed? feed,
}) async {
  t.view.physicalSize = device.size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);

  await t.pumpWidget(ProviderScope(
    overrides: [
      catalogTreeProvider.overrideWith((ref) => Future.value(cats ?? _cats())),
      servicesFeedProvider.overrideWith(() => _FixedFeed(feed ?? _feed())),
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
  await t.pump(); // FutureProvider loading frame
  await t.pump(); // data frame
}

void main() {
  // Data grid — light, 2 sizes (compact phone + expanded 3-col tablet).
  for (final d in [GoldenDevice.iphone16, GoldenDevice.pro13]) {
    goldenTest('services data ${d.name}', (t) async {
      await pumpServices(t, device: d);
      await expectGolden(t, goldenName('services', 'data', d, Brightness.light));
    });
  }

  // Data grid — dark, same 2 sizes.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.pro13]) {
    goldenTest('services dark ${d.name}', (t) async {
      await pumpServices(t, device: d, brightness: Brightness.dark);
      await expectGolden(t, goldenName('services', 'data', d, Brightness.dark));
    });
  }

  // Filtered: a category is active → the subcategory chip row renders too.
  goldenTest('services filtered 393', (t) async {
    await pumpServices(t, device: GoldenDevice.iphone16, screen: const ServicesScreen(category: 'cleaning'));
    await expectGolden(t, goldenName('services', 'filtered', GoldenDevice.iphone16, Brightness.light));
  });

  // Empty results → dashed EmptyState + "View all" reset.
  goldenTest('services empty 393', (t) async {
    await pumpServices(t, device: GoldenDevice.iphone16, feed: const ServicesFeed(items: []));
    await expectGolden(t, goldenName('services', 'empty', GoldenDevice.iphone16, Brightness.light));
  });
}
