import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/notifications/notifications_providers.dart';
import 'package:kyco_mobile/features/notifications/notifications_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

/// Fixed, boundary-hunting notifications: a long unread title (ellipsis canary),
/// a read item with a body + timestamp, a body-less/timestamp-less item, and
/// `hasMore` so the load-more footer renders. createdAt at noon UTC → TZ-safe.
NotificationsData _fakeData() => NotificationsData(
      items: const [
        NotificationItem(
          id: 5001,
          type: 'booking',
          title: 'Đơn đặt lịch của bạn đã được xác nhận bởi đối tác gần bạn',
          body: 'Đối tác sẽ đến đúng giờ đã hẹn.',
          createdAt: '2026-01-15T12:00:00Z',
          read: false,
        ),
        NotificationItem(
          id: 5000,
          type: 'promo',
          title: 'Giảm 20% cho lần đặt tiếp theo',
          body: 'Áp dụng đến hết tháng.',
          createdAt: '2026-01-10T12:00:00Z',
          read: true,
        ),
        NotificationItem(
          id: 4999,
          title: 'Chào mừng đến với Kyco',
          read: true,
        ),
      ],
      unread: 1,
      nextCursor: 'opaque-cursor-token',
      hasMore: true,
    );

/// Fixed-state controller for goldens (never hits the API). Mirrors the
/// FakeAuthController pattern.
class _FakeNotificationsController extends NotificationsController {
  _FakeNotificationsController(this._fixed);
  final NotificationsData _fixed;
  @override
  Future<NotificationsData> build() async => _fixed;
  @override
  Future<void> loadMore() async {}
  @override
  Future<bool> markAllRead() async => true;
}

/// Local pump for the authed feed: overrides the notifications controller with
/// fixed data so no network is touched. Mirrors the shared harness setup.
Future<void> pumpAuthedNotifications(
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
      authControllerProvider.overrideWith(() => FakeAuthController(Fakes.signedIn)),
      notificationsControllerProvider
          .overrideWith(() => _FakeNotificationsController(_fakeData())),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(
          brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const NotificationsScreen(),
    ),
  ));
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

void main() {
  // Anon shell (sign-in prompt) — reuses the shared harness; no API touched.
  for (final (d, b) in [
    (GoldenDevice.iphone16, Brightness.light),
    (GoldenDevice.se, Brightness.dark),
  ]) {
    goldenTest('notifications anon ${d.name} ${b.name}', (t) async {
      await pumpGoldenScreen(t,
          screen: const NotificationsScreen(),
          device: d,
          brightness: b,
          auth: Fakes.signedOut);
      await expectGolden(t, goldenName('notifications', 'anon', d, b));
    });
  }

  // Authed feed (unread badge + list + load-more footer).
  for (final (d, b) in [
    (GoldenDevice.iphone16, Brightness.light),
    (GoldenDevice.se, Brightness.dark),
  ]) {
    goldenTest('notifications authed ${d.name} ${b.name}', (t) async {
      await pumpAuthedNotifications(t, device: d, brightness: b);
      await expectGolden(t, goldenName('notifications', 'authed', d, b));
    });
  }
}
