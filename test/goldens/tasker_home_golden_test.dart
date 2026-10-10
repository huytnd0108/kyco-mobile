import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/tasker_home/tasker_home_providers.dart';
import 'package:kyco_mobile/features/tasker_home/tasker_home_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

/// A signed-in TASKER (role 'tasker') — the shell gate is satisfied so the
/// dashboard renders. Name is a full VN name so the greeting shows the given
/// (last) name only.
const _taskerUser = AuthUser(id: 7, role: 'tasker', name: 'Trần Minh Khoa');
const _taskerSignedIn = AuthState(status: AuthStatus.signedIn, user: _taskerUser);

/// Fixed, boundary-hunting workspace payload. The two jobs are pinned to a
/// far-future date (year 2099) so they are ALWAYS "upcoming" and the "today"
/// bucket is always empty — the today/upcoming split is wall-clock-based, so
/// this keeps the golden deterministic on any run date. UTC times → the rendered
/// date is timezone-independent too. KPI tones cover good / warn / bad.
TaskerWorkspace _fakeWorkspace() => TaskerWorkspace.fromJson(const {
      'dashboard': {
        'kpi': {
          'acceptance': {'rate': 0.92, 'tone': 'good', 'raw': {'claimed': 23, 'offered': 25}},
          'completion': {'rate': 0.88, 'tone': 'warn', 'raw': {'closed': 44, 'cancelled': 6}},
          'rating': {'value': 4.82, 'tone': 'good', 'raw': {'reviewsCount': 51}},
          'punctuality': {'rate': 0.79, 'tone': 'bad', 'raw': {'onTime': 30, 'total': 38}},
        },
        'jobs': {'active': 2, 'total': 34},
        'earnings': {'lifetimeVnd': 128400000, 'monthVnd': 9650000, 'balanceVnd': 2480000},
      },
      'jobs': {
        'items': [
          {
            'jobId': 9001,
            'jobStatus': 'pending',
            'bookingId': 5501,
            'scheduledAt': '2099-06-15T09:00:00Z',
            'addressLine': '12 Nguyễn Huệ',
            'ward': 'Bến Nghé',
            'district': 'Quận 1',
            'totalVnd': 480000,
            'confirmationCode': 'KYC-8842',
            'serviceName': 'Vệ sinh nhà theo giờ',
            'durationMinutes': 120,
          },
          {
            'jobId': 9002,
            'jobStatus': 'active',
            'bookingId': 5502,
            'scheduledAt': '2099-06-16T14:30:00Z',
            'addressLine': '89 Lê Lợi',
            'ward': 'Phường 3',
            'district': 'Quận Gò Vấp',
            'totalVnd': 12345678,
            'serviceName': 'Vệ sinh máy lạnh treo tường 2 chiều công suất lớn',
            'durationMinutes': 90,
          },
        ],
        'nextCursor': null,
        'hasMore': false,
      },
      'goals': [],
    });

/// Local pump for the tasker dashboard: overrides the auth controller with a
/// tasker-role session and the workspace future with fixed data — no network.
Future<void> pumpTaskerHome(
  WidgetTester tester, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  AuthState auth = _taskerSignedIn,
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
      authControllerProvider.overrideWith(() => FakeAuthController(auth)),
      taskerWorkspaceProvider.overrideWith((ref) async => _fakeWorkspace()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(
          brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TaskerHomeScreen(),
    ),
  ));
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

void main() {
  // Guest / not-a-tasker session → sign-in-required fallback (no network).
  for (final (d, b) in [
    (GoldenDevice.iphone16, Brightness.light),
    (GoldenDevice.se, Brightness.dark),
  ]) {
    goldenTest('tasker_home guest ${d.name} ${b.name}', (t) async {
      await pumpTaskerHome(t, device: d, brightness: b, auth: Fakes.signedOut);
      await expectGolden(t, goldenName('tasker_home', 'guest', d, b));
    });
  }

  // Tasker signed in → the full dashboard (KPI row + earnings + counters +
  // today/upcoming). light + dark × 2 sizes (compact SE + medium iPad mini).
  for (final d in [GoldenDevice.se, GoldenDevice.ipadMini]) {
    for (final b in [Brightness.light, Brightness.dark]) {
      goldenTest('tasker_home dashboard ${d.name} ${b.name}', (t) async {
        await pumpTaskerHome(t, device: d, brightness: b);
        await expectGolden(t, goldenName('tasker_home', 'dashboard', d, b));
      });
    }
  }
}
