// Wave C - UX-M14 saved-address prefill, UX-M15 media: resolution, UX-M18 invite
// share, UX-M19 manage-on-web link, maps URL helper.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/config.dart';
import 'package:kyco_mobile/core/launch.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/ui/media_image.dart';
import 'package:kyco_mobile/features/account/account_providers.dart';
import 'package:kyco_mobile/features/account/invite_screen.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/checkout/address_fields.dart';
import 'package:kyco_mobile/features/checkout/checkout_providers.dart';
import 'package:kyco_mobile/features/checkout/draft_store.dart';
import 'package:kyco_mobile/features/subscriptions/subscriptions_screen.dart';

import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'wave_c_support.dart';

final appLocalizationsDelegates = AppLocalizations.localizationsDelegates;
final appSupportedLocales = AppLocalizations.supportedLocales;

const _wards = [
  ActiveWard(code: 26734, name: 'Phường Bến Nghé', provinceCode: 79),
  ActiveWard(code: 26737, name: 'Phường Bến Thành', provinceCode: 79),
];

const _saved = [
  SavedAddress(id: 1, label: 'Nhà', line: '12 Nguyễn Huệ', district: 'Phường Bến Nghé', ward: 'Khu phố 3', city: 'TP.HCM', isDefault: true),
  SavedAddress(id: 2, label: 'Công ty', line: '99 Xa lạ', district: 'Phường Không Tồn Tại', ward: '', city: 'TP.HCM'),
];

Future<ProviderContainer> _pumpAddress(WidgetTester t, Harness h) async {
  useTallView(t, w: 400);
  await t.pumpWidget(ProviderScope(
    overrides: [
      ...h.overrides,
      checkoutWardsProvider.overrideWith((ref) async => _wards),
      neighborhoodsProvider.overrideWith((ref, code) async => const [
            Neighborhood(id: 1, name: 'Khu phố 3'),
            Neighborhood(id: 2, name: 'Khu phố 4'),
          ]),
      addressesProvider.overrideWith((ref) async => _saved),
    ],
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      locale: const Locale('vi'),
      home: const Scaffold(body: SingleChildScrollView(child: CheckoutAddressFields(serviceId: 1))),
    ),
  ));
  final c = ProviderScope.containerOf(t.element(find.byType(CheckoutAddressFields)));
  c.read(draftControllerProvider(1).notifier).ensureSeeded(
      const ServiceDetail(id: 1, name: 'Vệ sinh', basePriceVnd: 100000));
  await t.pumpAndSettle();
  return c;
}

void main() {
  group('UX-M14 saved address picker', () {
    testWidgets('picking a saved address prefills street, ward and neighborhood', (t) async {
      final h = await harness();
      final c = await _pumpAddress(t, h);
      await t.tap(find.byKey(const ValueKey('checkout-use-saved')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('saved-address-1')));
      await t.pumpAndSettle();
      final d = c.read(draftControllerProvider(1))!;
      expect(d.addressLine, '12 Nguyễn Huệ');
      expect(d.wardCode, 26734);
      expect(d.wardName, 'Phường Bến Nghé');
      expect(d.neighborhood, 'Khu phố 3');
      expect(find.widgetWithText(TextField, '12 Nguyễn Huệ'), findsOneWidget, reason: 'street text field updated');
      expect(find.text('Phường Bến Nghé'), findsWidgets, reason: 'ward dropdown shows the match');
      expect(find.text('Khu phố 3'), findsWidgets);
    });

    testWidgets('an unmatched ward still applies the street and leaves the ward to the user', (t) async {
      final h = await harness();
      final c = await _pumpAddress(t, h);
      await t.tap(find.byKey(const ValueKey('checkout-use-saved')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('saved-address-2')));
      await t.pumpAndSettle();
      final d = c.read(draftControllerProvider(1))!;
      expect(d.addressLine, '99 Xa lạ');
      expect(d.wardCode, isNull);
      expect(d.wardName, isNull);
    });

    testWidgets('signed out: no picker and no /addresses call', (t) async {
      final b = Backend();
      final h = await harness(backend: b, auth: const AuthState(status: AuthStatus.signedOut));
      useTallView(t, w: 400);
      await t.pumpWidget(ProviderScope(
        overrides: [...h.overrides, checkoutWardsProvider.overrideWith((ref) async => _wards)],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          locale: const Locale('vi'),
          home: const Scaffold(body: SingleChildScrollView(child: CheckoutAddressFields(serviceId: 1))),
        ),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('checkout-use-saved')), findsNothing);
      expect(b.calls('GET /addresses'), isEmpty);
    });
  });

  group('UX-M15 media: image references', () {
    test('mediaIdOf', () {
      expect(mediaIdOf('media:42'), 42);
      expect(mediaIdOf('media: 7 '), 7);
      expect(mediaIdOf('https://x/y.png'), isNull);
      expect(mediaIdOf('media:abc'), isNull);
      expect(mediaIdOf(null), isNull);
    });

    Future<List<String?>> resolve(WidgetTester t, Harness h, String? url) async {
      final seen = <String?>[];
      await t.pumpWidget(appWith(
          h,
          ResolvedImageUrl(
            url: url,
            builder: (_, resolved, _) {
              seen.add(resolved);
              return const SizedBox();
            },
          )));
      await t.pumpAndSettle();
      return seen;
    }

    testWidgets('signed in: media:7 resolves through GET /media/7 to the signed URL', (t) async {
      final b = Backend()
        ..on('GET /media/7',
            (_) => Backend.ok({'mediaId': 7, 'readUrl': 'https://cdn.example/7.png?sig=1', 'expiresInSeconds': 600}));
      final h = await harness(backend: b);
      final seen = await resolve(t, h, 'media:7');
      expect(seen.last, 'https://cdn.example/7.png?sig=1');
      expect(b.calls('GET /media/7'), hasLength(1));
      // Dispose the keep-alive timer before the test ends.
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 700));
    });

    testWidgets('signed out + 200: anonymous read shows the image URL, no Authorization header', (t) async {
      final b = Backend()
        ..on('GET /media/7',
            (_) => Backend.ok({'mediaId': 7, 'readUrl': 'https://cdn.example/7.png?sig=2', 'expiresInSeconds': 600}));
      final h = await harness(backend: b, auth: const AuthState(status: AuthStatus.signedOut));
      final seen = await resolve(t, h, 'media:7');
      expect(seen.last, 'https://cdn.example/7.png?sig=2');
      final calls = b.calls('GET /media/7').toList();
      expect(calls, hasLength(1));
      // A token is stored in the harness; it must still not be sent.
      expect(calls.single.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 700));
    });

    testWidgets('signed out + 401: placeholder (null) is kept', (t) async {
      final b = Backend()..on('GET /media/7', (_) => Backend.err(401, 'UNAUTHORIZED'));
      final h = await harness(backend: b, auth: const AuthState(status: AuthStatus.signedOut));
      final seen = await resolve(t, h, 'media:7');
      expect(seen.last, isNull);
    });

    testWidgets('signed in: the read is authenticated (Bearer header)', (t) async {
      final b = Backend()
        ..on('GET /media/7',
            (_) => Backend.ok({'mediaId': 7, 'readUrl': 'https://cdn.example/7.png?sig=3', 'expiresInSeconds': 600}));
      final h = await harness(backend: b);
      await resolve(t, h, 'media:7');
      expect(b.calls('GET /media/7').single.headers['authorization'], 'Bearer a');
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 700));
    });

    testWidgets('a failing resolve keeps the placeholder', (t) async {
      final b = Backend()..on('GET /media/7', (_) => Backend.err(404, 'NOT_FOUND'));
      final h = await harness(backend: b);
      final seen = await resolve(t, h, 'media:7');
      expect(seen.last, isNull);
    });

    testWidgets('plain https passes through untouched, no API call', (t) async {
      final b = Backend();
      final h = await harness(backend: b);
      final seen = await resolve(t, h, 'https://img.example/a.png');
      expect(seen.last, 'https://img.example/a.png');
      expect(b.log, isEmpty);
    });
  });

  group('UX-M18 invite share / UX-M19 manage on web', () {
    testWidgets('Share hands the code + invite URL to the share sheet', (t) async {
      useTallView(t, w: 400);
      final shared = <String>[];
      final b = Backend()
        ..on('POST /invites/code', (_) => Backend.ok({'code': 'ABC123'}))
        ..on('GET /invites/stats', (_) => Backend.ok({'pending': 1, 'signedUp': 2}));
      final h = await harness(backend: b, sharer: (text) async => shared.add(text));
      await t.pumpWidget(appWith(h, const InviteScreen()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('invite-share')));
      await t.pump();
      expect(shared, hasLength(1));
      expect(shared.single, contains('ABC123'));
      expect(shared.single, contains('${AppConfig.webBase}/r/ABC123'));
    });

    testWidgets('pull-to-refresh awaits the reloads', (t) async {
      useTallView(t, w: 400);
      final b = Backend()
        ..on('POST /invites/code', (_) => Backend.ok({'code': 'ABC123'}))
        ..on('GET /invites/stats', (_) => Backend.ok({'pending': 1, 'signedUp': 2}));
      final h = await harness(backend: b);
      await t.pumpWidget(appWith(h, const InviteScreen()));
      await t.pumpAndSettle();
      await t.drag(find.byType(ListView), const Offset(0, 1200)); // > 25% of the tall viewport arms the indicator
      await t.pumpAndSettle();
      expect(b.calls('GET /invites/stats'), hasLength(2));
      expect(b.calls('POST /invites/code'), hasLength(2));
    });

    testWidgets('Manage on web opens the website subscriptions page', (t) async {
      useTallView(t, w: 400);
      final opened = <Uri>[];
      final b = Backend()
        ..on('GET /plans', (_) => Backend.ok([]))
        ..on('GET /subscriptions', (_) => Backend.ok([]));
      final h = await harness(backend: b, opener: (u) async {
        opened.add(u);
        return true;
      });
      await t.pumpWidget(appWith(h, const SubscriptionsScreen()));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('manage-on-web')));
      await t.tap(find.byKey(const ValueKey('manage-on-web')));
      await t.pump();
      expect(opened.single.toString(), '${AppConfig.webBase}/subscriptions');
    });

    test('webBase is the origin of the API base', () {
      expect(AppConfig.webBase, isNot(contains('/api')));
      expect(Uri.parse(AppConfig.webBase).host, Uri.parse(AppConfig.apiBase).host);
    });
  });

  test('mapsUri builds an https maps search link with the coordinates', () {
    final u = mapsUri(10.5, 106.25);
    expect(u.scheme, 'https');
    expect(u.queryParameters['query'], '10.5,106.25');
  });
}
