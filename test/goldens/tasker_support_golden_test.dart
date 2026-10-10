import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/tasker_support/tasker_support_providers.dart';
import 'package:kyco_mobile/features/tasker_support/tasker_support_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

/// Fixed ticket history exercising every `_StatusChip` branch + the null paths
/// (missing subject / category / createdAt). Never random.
const _tickets = <SupportTicket>[
  SupportTicket(
    id: 5012,
    subject: 'Ví chưa cộng tiền sau khi hoàn thành đơn',
    category: 'wallet',
    priority: 'high',
    status: 'open',
    createdAt: '2026-08-20T09:30:00Z',
  ),
  SupportTicket(
    id: 5008,
    subject: 'Ứng dụng báo lỗi khi check-in đơn xa',
    category: 'tech',
    status: 'in_progress',
    createdAt: '2026-08-12T14:05:00Z',
  ),
  SupportTicket(
    id: 4990,
    subject: 'Hỏi về chính sách huỷ đơn',
    category: 'policy',
    status: 'resolved',
    createdAt: '2026-07-30T08:00:00Z',
  ),
  // null subject / category / createdAt + unknown status → fallback branches.
  SupportTicket(id: 4970),
];

Future<void> _pump(
  WidgetTester tester, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  List<SupportTicket>? tickets = _tickets,
  Object? error,
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
      myTicketsProvider.overrideWith((ref) {
        if (error != null) throw error;
        return Future.value(tickets ?? const <SupportTicket>[]);
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TaskerSupportScreen(),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  // Populated history — light, phone + tablet.
  for (final d in [GoldenDevice.iphone16, GoldenDevice.ipadAir]) {
    goldenTest('tasker_support tickets ${d.name}', (t) async {
      await _pump(t, device: d);
      await expectGolden(
          t, goldenName('tasker_support', 'tickets', d, Brightness.light));
    });
  }

  // Dark, populated.
  goldenTest('tasker_support dark 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, brightness: Brightness.dark);
    await expectGolden(t,
        goldenName('tasker_support', 'tickets', GoldenDevice.iphone16, Brightness.dark));
  });

  // Empty history.
  goldenTest('tasker_support empty 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, tickets: const []);
    await expectGolden(t,
        goldenName('tasker_support', 'empty', GoldenDevice.iphone16, Brightness.light));
  });

  // A7 not deployed yet (503) → the history shows an inline error with Retry (never "no tickets").
  goldenTest('tasker_support error 393', (t) async {
    await _pump(t,
        device: GoldenDevice.iphone16,
        error: ApiException('http_503', 'unavailable', status: 503));
    await expectGolden(t,
        goldenName('tasker_support', 'error', GoldenDevice.iphone16, Brightness.light));
  });

  // English locale (title only; body copy is inlined VN until ARB lands).
  goldenTest('tasker_support en 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, locale: const Locale('en'));
    await expectGolden(
        t,
        goldenName('tasker_support', 'tickets', GoldenDevice.iphone16, Brightness.light,
            locale: const Locale('en')));
  });
}
