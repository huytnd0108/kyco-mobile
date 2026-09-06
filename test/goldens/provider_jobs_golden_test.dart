import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/provider_jobs/provider_jobs_providers.dart';
import 'package:kyco_mobile/features/provider_jobs/provider_jobs_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

/// A signed-in PROVIDER (CTV) — the jobs surface lives under the `/p` shell.
const _providerAuth = AuthState(
  status: AuthStatus.signedIn,
  user: AuthUser(id: 42, role: 'provider', name: 'Trần Thị Mỹ Hạnh'),
);

/// Fixed, boundary-hunting assigned jobs: one row per status branch + a
/// long-name ellipsis canary + a null-money/null-address row. `hasMore` so the
/// load-more footer renders. Money is the server `totalVnd` (never computed).
AssignedJobsData _fakeAssigned() => const AssignedJobsData(
      items: [
        ProviderJob(
          jobId: 9001,
          jobStatus: 'active',
          serviceName: 'Vệ sinh máy lạnh treo tường 2 chiều công suất lớn định kỳ',
          scheduledAt: '2026-09-06 08:00',
          addressLine: '12 Nguyễn Huệ',
          ward: 'Bến Nghé',
          district: 'Quận 1',
          totalVnd: 480000,
          confirmationCode: 'KC-9001',
        ),
        ProviderJob(
          jobId: 9002,
          jobStatus: 'pending',
          serviceName: 'Tổng vệ sinh',
          scheduledAt: '2026-09-07 13:30',
          addressLine: '88 Lê Lợi',
          district: 'Quận 3',
          totalVnd: 2400000,
          confirmationCode: 'KC-9002',
        ),
        ProviderJob(
          jobId: 9003,
          jobStatus: 'closed',
          serviceName: 'Giặt thảm',
          scheduledAt: '2026-08-30 09:00',
          district: 'Bình Thạnh',
          totalVnd: 350000,
        ),
        ProviderJob(jobId: 9004, jobStatus: 'cancelled'),
      ],
      nextCursor: 'opaque-cursor',
      hasMore: true,
    );

PoolView _fakePool({bool canClaim = true, String? banReason}) => PoolView(
      canClaim: canClaim,
      banReason: banReason,
      assigned: const [
        PoolJob(
          jobId: 8001,
          jobStatus: 'pending',
          serviceName: 'Vệ sinh nhà theo giờ',
          scheduledAt: '2026-09-06 15:00',
          addressLine: '5 Pasteur',
          district: 'Quận 1',
          totalVnd: 600000,
          confirmationCode: 'KC-8001',
        ),
      ],
      pool: const [
        PoolJob(
          jobId: 8100,
          serviceName: 'Vệ sinh sofa – nệm – rèm cửa cao cấp',
          scheduledAt: '2026-09-06 18:00',
          durationMinutes: 120,
          addressLine: '20 Điện Biên Phủ',
          ward: 'Đa Kao',
          district: 'Quận 1',
          totalVnd: 900000,
          notes: 'Nhà có nuôi mèo, mang theo dụng cụ hút lông.',
        ),
        PoolJob(
          jobId: 8101,
          serviceName: 'Vệ sinh máy lạnh',
          scheduledAt: '2026-09-07 09:00',
          durationMinutes: 60,
          addressLine: '77 Cách Mạng Tháng 8',
          district: 'Quận 10',
          totalVnd: 350000,
        ),
      ],
    );

/// Fixed-state assigned controller for goldens (never hits the API).
class _FakeAssignedController extends AssignedJobsController {
  _FakeAssignedController(this._fixed);
  final AssignedJobsData _fixed;
  @override
  Future<AssignedJobsData> build() async => _fixed;
  @override
  Future<void> loadMore() async {}
}

Future<void> _pump(
  WidgetTester tester, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
  AuthState auth = _providerAuth,
  AssignedJobsData? assigned,
  PoolView? pool,
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
      assignedJobsControllerProvider
          .overrideWith(() => _FakeAssignedController(assigned ?? _fakeAssigned())),
      poolProvider.overrideWith((ref) => Future.value(pool ?? _fakePool())),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProviderJobsScreen(),
    ),
  ));
  await tester.pump(); // loading frame
  await tester.pump(); // data frame
}

/// Switches to the "Available" tab (index 1) and settles.
Future<void> _openAvailable(WidgetTester tester) async {
  await tester.tap(find.byType(Tab).last);
  await tester.pumpAndSettle();
}

void main() {
  // Assigned tab — light + dark.
  for (final (d, b) in [
    (GoldenDevice.iphone16, Brightness.light),
    (GoldenDevice.se, Brightness.dark),
  ]) {
    goldenTest('provider_jobs assigned ${d.name} ${b.name}', (t) async {
      await _pump(t, device: d, brightness: b);
      await expectGolden(t, goldenName('provider_jobs', 'assigned', d, b));
    });
  }

  // Available (pool) tab — claimable, light + dark.
  for (final (d, b) in [
    (GoldenDevice.iphone16, Brightness.light),
    (GoldenDevice.se, Brightness.dark),
  ]) {
    goldenTest('provider_jobs available ${d.name} ${b.name}', (t) async {
      await _pump(t, device: d, brightness: b);
      await _openAvailable(t);
      await expectGolden(t, goldenName('provider_jobs', 'available', d, b));
    });
  }

  // Available (pool) tab — ban gate closed (claim disabled + banner).
  goldenTest('provider_jobs available_banned 393 light', (t) async {
    await _pump(t,
        device: GoldenDevice.iphone16,
        pool: _fakePool(canClaim: false, banReason: 'Bạn đã bị tạm khóa nhận đơn đến hết ngày 10/09.'));
    await _openAvailable(t);
    await expectGolden(t,
        goldenName('provider_jobs', 'available_banned', GoldenDevice.iphone16, Brightness.light));
  });
}
