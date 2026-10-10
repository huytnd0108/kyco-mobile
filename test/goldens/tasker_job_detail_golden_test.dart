import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/tasker_job_detail/tasker_job_detail_data.dart';
import 'package:kyco_mobile/features/tasker_job_detail/tasker_job_detail_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fakes.dart';
import '_harness.dart';

// Fixed, boundary-hunting job-detail payloads (never random; no real GPS/camera
// — goldens only render the hub, they never tap a native action).

/// pending → the confirm / decline / cancel branch + payment panel.
TaskerJobDetail _pending() => TaskerJobDetail.fromJson({
      'job': {'id': 501, 'status': 'pending', 'bookingId': 9001},
      'booking': {
        'id': 9001,
        'status': 'CONFIRMED',
        'totalVnd': 480000,
        'paymentMethod': 'cash',
        'confirmationCode': 'KYC-501',
        'scheduledAt': '2026-09-07T09:00:00Z',
        'addressLine': '12 Nguyễn Huệ',
        'ward': 'Bến Nghé',
        'district': 'Quận 1',
        'notes': 'Bấm chuông căn hộ 4B',
      },
      'service': {'name': 'Vệ sinh nhà theo giờ', 'durationMinutes': 180},
      'customer': {'name': 'Ngọc Anh', 'email': 'ngocanh@example.com'},
      'hasCheckedIn': false,
      'hasCheckedOut': false,
      'thread': const [],
    });

/// on-site → active, checked in: photos card, face-verify, check-out, SOS,
/// live-share, chat. The heaviest lifecycle surface.
TaskerJobDetail _onSite() => TaskerJobDetail.fromJson({
      'job': {
        'id': 502,
        'status': 'active',
        'bookingId': 9002,
        'earningsVnd': 384000,
        'beforePhotos': [
          {'mediaId': 1},
          {'mediaId': 2},
        ],
        'midPhotos': const [],
        'afterPhotos': const [],
      },
      'booking': {
        'id': 9002,
        'status': 'ACTIVE',
        'totalVnd': 480000,
        'paymentMethod': 'cash',
        'confirmationCode': 'KYC-502',
        'scheduledAt': '2026-09-06T14:00:00Z',
        'addressLine': '88 Lê Lợi',
        'ward': 'Bến Thành',
        'district': 'Quận 1',
      },
      'service': {'name': 'Tổng vệ sinh', 'durationMinutes': 240},
      'customer': {'name': 'Minh Khôi', 'email': 'khoi@example.com'},
      'hasCheckedIn': true,
      'hasCheckedOut': false,
      'thread': const [
        {'id': 1, 'fromRole': 'customer', 'body': 'Anh tới chưa ạ?', 'createdAt': '2026-09-06T13:50:00Z'},
        {'id': 2, 'fromRole': 'tasker', 'body': 'Tôi đang trên đường, 10 phút nữa tới.', 'createdAt': '2026-09-06T13:52:00Z'},
      ],
    });

/// awaiting-cash → the 20% commission cash-received branch + settled sibling.
TaskerJobDetail _awaitingCash() => TaskerJobDetail.fromJson({
      'job': {'id': 503, 'status': 'closed', 'bookingId': 9003, 'earningsVnd': 384000},
      'booking': {
        'id': 9003,
        'status': 'AWAITING_CASH_CONFIRM',
        'totalVnd': 480000,
        'paymentMethod': 'cash',
        'confirmationCode': 'KYC-503',
        'scheduledAt': '2026-09-05T10:00:00Z',
        'addressLine': '5 Đồng Khởi',
        'ward': 'Bến Nghé',
        'district': 'Quận 1',
      },
      'service': {'name': 'Vệ sinh máy lạnh', 'durationMinutes': 90},
      'customer': {'name': 'Thu Hà', 'email': 'thuha@example.com'},
      'hasCheckedIn': true,
      'hasCheckedOut': true,
      'thread': const [],
    });

Future<void> _pump(
  WidgetTester tester, {
  required GoldenDevice device,
  required TaskerJobDetail detail,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('vi'),
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
      taskerJobDetailProvider.overrideWith((ref, id) {
        if (error != null) throw error;
        return Future.value(detail);
      }),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(brightness == Brightness.dark ? darkColorScheme : lightColorScheme),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TaskerJobDetailScreen(id: 999),
    ),
  ));
  await tester.pump(); // FutureProvider loading frame
  await tester.pump(); // data frame
}

void main() {
  // pending — confirm / decline / cancel, light + dark.
  goldenTest('tasker_job_detail pending light 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, detail: _pending());
    await expectGolden(t, goldenName('tasker_job_detail', 'pending', GoldenDevice.iphone16, Brightness.light));
  });
  goldenTest('tasker_job_detail pending dark 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, detail: _pending(), brightness: Brightness.dark);
    await expectGolden(t, goldenName('tasker_job_detail', 'pending', GoldenDevice.iphone16, Brightness.dark));
  });

  // on-site — heaviest surface (photos / face / check-out / SOS / live-share / chat).
  goldenTest('tasker_job_detail onsite light 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, detail: _onSite());
    await expectGolden(t, goldenName('tasker_job_detail', 'onsite', GoldenDevice.iphone16, Brightness.light));
  });
  goldenTest('tasker_job_detail onsite dark 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, detail: _onSite(), brightness: Brightness.dark);
    await expectGolden(t, goldenName('tasker_job_detail', 'onsite', GoldenDevice.iphone16, Brightness.dark));
  });

  // awaiting-cash — the 20% commission cash-received branch.
  goldenTest('tasker_job_detail cash light 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, detail: _awaitingCash());
    await expectGolden(t, goldenName('tasker_job_detail', 'cash', GoldenDevice.iphone16, Brightness.light));
  });

  // English, on-site.
  goldenTest('tasker_job_detail onsite en 393', (t) async {
    await _pump(t, device: GoldenDevice.iphone16, detail: _onSite(), locale: const Locale('en'));
    await expectGolden(t,
        goldenName('tasker_job_detail', 'onsite', GoldenDevice.iphone16, Brightness.light, locale: const Locale('en')));
  });

  // Loading + error states (A8 dark-launch: 503 until the route deploys).
  goldenTest('tasker_job_detail error 393', (t) async {
    await _pump(t,
        device: GoldenDevice.iphone16,
        detail: _pending(),
        error: ApiException('MAINTENANCE', 'service unavailable', status: 503));
    await expectGolden(t, goldenName('tasker_job_detail', 'error', GoldenDevice.iphone16, Brightness.light));
  });
}
