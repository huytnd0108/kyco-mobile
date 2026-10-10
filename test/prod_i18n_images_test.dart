// Bilingual (VI/EN) + real-image regression tests built from REAL production
// payloads captured read-only from https://kyco.vn/api/v1 (test/fixtures/prod_*,
// signed URL query strings redacted, no PII).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/token_store.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/locale_controller.dart';
import 'package:kyco_mobile/core/localized.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/core/ui/category_tile.dart';
import 'package:kyco_mobile/core/ui/media_image.dart';
import 'package:kyco_mobile/core/ui/service_card.dart';
import 'package:kyco_mobile/features/home/home_providers.dart';
import 'package:kyco_mobile/features/services/services_providers.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore;

Map<String, dynamic> _fx(String name) =>
    (jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>)['data']
        as Map<String, dynamic>;

List<dynamic> _fxList(String name) =>
    (jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>)['data']
        as List<dynamic>;

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add(o);
    final lang = o.headers['accept-language'];
    final file = o.path == '/home'
        ? 'test/fixtures/prod_home.${lang == 'en' ? 'en' : 'vi'}.json'
        : 'test/fixtures/prod_catalog_tree.json';
    return ResponseBody.fromString(File(file).readAsStringSync(), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('prod payload models', () {
    test('home categories: EN shows nameEn, VI shows nameVi, subtitle never mixes', () {
      final home = HomeComposite.fromJson(_fx('prod_home.en.json'));
      final c = home.categories.firstWhere((c) => c.slug == 'home-cleaning');
      expect(c.nameVi, 'Dọn nhà theo giờ');
      expect(c.nameEn, 'Home cleaning');
      expect(c.displayName('en'), 'Home cleaning');
      expect(c.displayName('vi'), 'Dọn nhà theo giờ');
      // prod `subtitle` is Vietnamese only: shown in vi, hidden in en (backend gap).
      expect(c.displaySubtitle('vi'), 'Linh hoạt, theo giờ');
      expect(c.displaySubtitle('en'), isNull);
      expect(c.imageUrl, startsWith('https://storage.googleapis.com/'));
      expect(home.categories.firstWhere((c) => c.slug == 'ac-cleaning').imageUrl, isNull);
    });

    test('home services follow Accept-Language server-side; media: and null urls survive', () {
      final en = HomeComposite.fromJson(_fx('prod_home.en.json'));
      final vi = HomeComposite.fromJson(_fx('prod_home.vi.json'));
      expect(en.services.firstWhere((s) => s.id == 73).name, 'Home Cleaning · 2 Hours');
      expect(vi.services.firstWhere((s) => s.id == 73).name, 'Dọn nhà 2 giờ');
      expect(en.services.firstWhere((s) => s.id == 61).imageUrl, startsWith('https://www.doforms.com/'));
      expect(en.services.firstWhere((s) => s.id == 73).imageUrl, 'media:23');
      expect(en.services.firstWhere((s) => s.id == 78).imageUrl, isNull);
    });

    test('service detail parses localized name/description', () {
      final en = ServiceDetail.fromJson(_fx('prod_service_detail_62.en.json'));
      final vi = ServiceDetail.fromJson(_fx('prod_service_detail_62.vi.json'));
      expect(en.name, 'Townhouse Cleaning · 3 Hours');
      expect(en.description, startsWith('Hourly cleaning'));
      expect(vi.name, 'Dọn dẹp nhà phố 3 giờ');
      expect(en.category, 'hourly'); // a SLUG, not a label
    });

    test('catalog tree: service/category names pick by locale; slugs resolve to labels', () {
      final tree = _fxList('prod_catalog_tree.json')
          .cast<Map<String, dynamic>>()
          .map(CatalogCategory.fromJson)
          .toList();
      final home = tree.firstWhere((c) => c.slug == 'home-cleaning');
      expect(home.looseServices.first.displayName('en'), 'Home Cleaning · 2 Hours');
      expect(home.looseServices.first.displayName('vi'), 'Dọn nhà 2 giờ');
      final labels = CatalogLabels(tree);
      expect(labels.category('hourly', 'en'), 'Hourly cleaning');
      expect(labels.category('hourly', 'vi'), 'Vệ sinh theo giờ');
      expect(labels.category('nope', 'en'), isNull); // never a raw slug
      expect(labels.subcategory('hourly', 'general', 'en'), 'General');
      expect(labels.subcategory('hourly', 'general', 'vi'), 'Dọn dẹp thông thường');
    });

    test('pickLocalized falls back to the other side when one is empty', () {
      expect(pickLocalized('en', vi: 'Xin chào', en: ''), 'Xin chào');
      expect(pickLocalized('vi', vi: null, en: 'Hello'), 'Hello');
      expect(pickLocalized('en', vi: ' ', en: null), isNull);
    });

    test('resolveImageUrl: absolute any host, protocol-relative, web-relative, rest null', () {
      expect(resolveImageUrl('https://www.doforms.com/a.jpg'), 'https://www.doforms.com/a.jpg');
      expect(resolveImageUrl('http://x.test/a.jpg'), 'http://x.test/a.jpg');
      expect(resolveImageUrl('//cdn.test/a.jpg'), 'https://cdn.test/a.jpg');
      expect(resolveImageUrl('/images/a.jpg'), 'https://kyco.vn/images/a.jpg');
      expect(resolveImageUrl('media:23'), isNull);
      expect(resolveImageUrl('  '), isNull);
      expect(resolveImageUrl(null), isNull);
      expect(mediaIdOf('media:23'), 23);
    });
  });

  group('locale switch refetch', () {
    test('changing language refetches home with the new Accept-Language', () async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final adapter = _Adapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1', validateStatus: (_) => true))
        ..httpClientAdapter = adapter;
      final c = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore() as TokenStore),
        apiDioProvider.overrideWithValue(dio),
      ]);
      addTearDown(c.dispose);
      await c.read(localeControllerProvider.notifier).set(const Locale('vi'));
      final sub = c.listen(homeProvider, (_, _) {});
      addTearDown(sub.close);
      var home = await c.read(homeProvider.future);
      expect(adapter.requests.last.headers['accept-language'], 'vi');
      expect(home.services.firstWhere((s) => s.id == 73).name, 'Dọn nhà 2 giờ');

      await c.read(localeControllerProvider.notifier).set(const Locale('en'));
      home = await c.read(homeProvider.future);
      expect(adapter.requests.last.headers['accept-language'], 'en');
      expect(home.services.firstWhere((s) => s.id == 73).name, 'Home Cleaning · 2 Hours');
      expect(adapter.requests.where((r) => r.path == '/home').length, 2);
    });
  });

  group('widgets', () {
    Future<void> pump(WidgetTester t, Widget child, {required Locale locale, List<Override> overrides = const []}) async {
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore() as TokenStore),
          ...overrides,
        ],
        child: MaterialApp(
          theme: buildTheme(lightColorScheme),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ));
      await t.pump();
    }

    final cats = HomeComposite.fromJson(_fx('prod_home.en.json')).categories;
    final withImage = cats.firstWhere((c) => c.slug == 'home-cleaning');
    final noImage = cats.firstWhere((c) => c.slug == 'ac-cleaning');

    testWidgets('CategoryTile en: nameEn over an https Image.network; no Vietnamese subtitle', (t) async {
      await pump(t, SizedBox(width: 200, height: 160, child: CategoryTile(withImage)), locale: const Locale('en'));
      expect(find.text('Home cleaning'), findsOneWidget);
      expect(find.text('Dọn nhà theo giờ'), findsNothing);
      expect(find.text('Linh hoạt, theo giờ'), findsNothing);
      final img = t.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      expect((img.image as NetworkImage).url, withImage.imageUrl);
    });

    testWidgets('CategoryTile vi: nameVi + subtitle', (t) async {
      await pump(t, SizedBox(width: 200, height: 160, child: CategoryTile(withImage)), locale: const Locale('vi'));
      expect(find.text('Dọn nhà theo giờ'), findsOneWidget);
      expect(find.text('Linh hoạt, theo giờ'), findsOneWidget);
      expect(find.text('Home cleaning'), findsNothing);
    });

    testWidgets('CategoryTile with null image: branded placeholder AND the name', (t) async {
      await pump(t, SizedBox(width: 200, height: 160, child: CategoryTile(noImage)), locale: const Locale('en'));
      expect(find.byType(Image), findsNothing);
      expect(find.text('AC cleaning'), findsOneWidget);
      expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
    });

    testWidgets('ServiceCard: https url -> Image.network; null -> placeholder; pill localized (no slug)', (t) async {
      final svcs = HomeComposite.fromJson(_fx('prod_home.en.json')).services;
      final tree = _fxList('prod_catalog_tree.json')
          .cast<Map<String, dynamic>>()
          .map(CatalogCategory.fromJson)
          .toList();
      final ov = [catalogTreeProvider.overrideWith((ref) => Future.value(tree))];
      final https = svcs.firstWhere((s) => s.id == 61); // category slug "deep"
      await pump(t, SizedBox(width: 220, height: 330, child: ServiceCard(https)),
          locale: const Locale('en'), overrides: ov);
      await t.pump();
      expect(find.text('Deep Cleaning · 2-Bedroom Apartment'), findsOneWidget);
      expect(find.text('Deep cleaning'), findsOneWidget); // localized category pill
      expect(find.text('deep'), findsNothing); // raw slug never shown
      expect((t.widget<Image>(find.byType(Image)).image as NetworkImage).url, https.imageUrl);

      final none = svcs.firstWhere((s) => s.id == 78);
      await pump(t, SizedBox(width: 220, height: 330, child: ServiceCard(none)),
          locale: const Locale('en'), overrides: ov);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.cleaning_services), findsOneWidget);
      expect(find.text(none.name), findsOneWidget);
    });
  });
}
