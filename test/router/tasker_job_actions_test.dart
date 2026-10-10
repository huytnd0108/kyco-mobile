// OCD-033 / OCD-035 / OCD-066: tasker job screen actions, driven through the
// REAL router + scripted /api/v1 (GPS faked via locationServiceProvider).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/labels.dart';
import 'package:kyco_mobile/core/locale_controller.dart';
import 'package:kyco_mobile/features/tasker_job_detail/native_capture.dart';
import 'package:kyco_mobile/features/tasker_job_detail/tasker_job_detail_data.dart';

import '../wave_c_support.dart';

class _FakeGps extends LocationService {
  const _FakeGps();
  @override
  Future<GpsResult> currentPosition() async =>
      const GpsResult.ok(GpsFix(lat: 10.78, lon: 106.7, accuracyM: 10));
}

Map<String, dynamic> _detail({
  String job = 'active',
  String booking = 'CONFIRMED',
  bool checkedIn = false,
}) =>
    {
      'job': {'id': 5, 'status': job, 'bookingId': 90},
      'booking': {
        'id': 90, 'status': booking, 'totalVnd': 480000, 'paymentMethod': 'cash',
        'scheduledAt': '2026-10-10T09:00:00Z', 'addressLine': '45 Lê Lợi', 'district': 'Quận 1',
      },
      'service': {'name': 'Vệ sinh nhà', 'durationMinutes': 120},
      'customer': {'name': 'Ngọc Anh'},
      'hasCheckedIn': checkedIn,
      'hasCheckedOut': false,
      'thread': <Object>[],
    };

Future<(ProviderContainer, GoRouter, Backend)> _pump(WidgetTester t, Backend b) async {
  useTallView(t, w: 420, h: 2600);
  final h = await harness(
    backend: b,
    auth: signedInAs('tasker'),
    extra: [
      locationServiceProvider.overrideWithValue(const _FakeGps()),
      idempotencyLedgerProvider
          .overrideWithValue(IdempotencyLedger(store: MemoryPendingKeyStore())),
    ],
  );
  final c = ProviderContainer(overrides: h.overrides);
  addTearDown(c.dispose);
  await c.read(localeControllerProvider.notifier).set(const Locale('vi'));
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KycoApp()));
  await t.pumpAndSettle();
  final router = c.read(routerProvider);
  router.go('/p/jobs');
  await t.pumpAndSettle();
  unawaited(router.push<Object?>('/p/jobs/5'));
  await t.pumpAndSettle();
  return (c, router, b);
}

void main() {
  testWidgets('OCD-033: after start-tracking the banner and the start button follow the server state',
      (t) async {
    var booking = 'CONFIRMED';
    final b = Backend()
      ..on('GET /tasker/jobs/5', (_) => Backend.ok(_detail(booking: booking)))
      ..on('POST /tasker/jobs/5/start-tracking', (_) {
        booking = 'EN_ROUTE';
        return Backend.ok({'status': 'EN_ROUTE'}, status: 201);
      });
    await _pump(t, b);
    expect(find.text(vi.provJdPhaseEnRoute), findsOneWidget);
    expect(find.text(vi.provJdStartTracking), findsOneWidget);

    await t.tap(find.text(vi.provJdStartTracking));
    await t.pumpAndSettle();

    expect(b.calls('POST /tasker/jobs/5/start-tracking'), hasLength(1));
    expect(find.text(vi.provJdPhaseTravelling), findsOneWidget);
    expect(find.text(vi.provJdPhaseEnRoute), findsNothing);
    expect(find.text(vi.provJdStartTracking), findsNothing, reason: 'a second tap would 409');
    expect(find.text(vi.provJdTravellingNote), findsOneWidget);
    expect(find.text(vi.provJdCheckIn), findsOneWidget);
  });

  testWidgets('OCD-035: a 409 on check-out shows next to the action, not only in a snackbar', (t) async {
    final b = Backend()
      ..on('GET /tasker/jobs/5', (_) => Backend.ok(_detail(booking: 'ACTIVE', checkedIn: true)))
      ..on('POST /tasker/jobs/5/check-out',
          (_) => Backend.err(409, 'CHECKOUT_TOO_EARLY', 'Chưa thể kết thúc ca trước 23:12 10/10'));
    await _pump(t, b);
    expect(find.byKey(const ValueKey('job-action-error')), findsNothing);

    await t.tap(find.text(vi.provJdCheckOut));
    await t.pumpAndSettle();

    expect(b.calls('POST /tasker/jobs/5/check-out'), hasLength(1));
    final banner = find.byKey(const ValueKey('job-action-error'));
    expect(banner, findsOneWidget);
    // Inside the viewport, right above the lifecycle buttons.
    final box = t.getRect(banner);
    expect(box.top, greaterThanOrEqualTo(0));
    expect(box.bottom, lessThan(t.getRect(find.text(vi.provJdCheckOut)).top));
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('OCD-066: after a tasker cancel the user lands on the jobs list with a success message',
      (t) async {
    var cancelled = false;
    final b = Backend()
      ..on('GET /tasker/jobs/5', (_) => cancelled
          ? Backend.err(404, 'NOT_FOUND')
          : Backend.ok(_detail(job: 'pending')))
      ..on('POST /tasker/jobs/5/cancel', (_) {
        cancelled = true;
        return Backend.ok({'ok': true});
      });
    final (_, router, _) = await _pump(t, b);

    await t.tap(find.byIcon(Icons.cancel_outlined));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('job-cancel-reason')));
    await t.pumpAndSettle();
    await t.tap(find.text(cancelReasonLabel(vi, kJobCancelReasonCodes.first)).last);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('job-cancel-submit')));
    // The jobs list polls / shows spinners, so settle by time, not by idle.
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }

    expect(b.calls('POST /tasker/jobs/5/cancel'), hasLength(1));
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/p/jobs');
    expect(find.text(vi.provJdCancelled), findsOneWidget);
    expect(find.text(vi.provJdNotFound), findsNothing);
    expect(b.calls('GET /tasker/jobs/5'), hasLength(1), reason: 'no re-fetch of the gone job');
  });

  testWidgets('OCD-036: a too-short complaint is blocked INSIDE the dialog (it stays open, text kept)',
      (t) async {
    final b = Backend()
      ..on('GET /tasker/jobs/5', (_) => Backend.ok(_detail(booking: 'ACTIVE', checkedIn: true)))
      ..on('POST /tasker/jobs/5/complaint', (_) => Backend.ok({'ok': true}));
    await _pump(t, b);
    await t.tap(find.text(vi.provJdReportProblem));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField).last, 'Quá ngắn');
    await t.pump();
    expect(find.byKey(const ValueKey('reason-min-hint')), findsOneWidget);
    expect(t.widget<FilledButton>(find.byKey(const ValueKey('reason-confirm'))).onPressed, isNull);
    expect(find.text('Quá ngắn'), findsOneWidget, reason: 'typed text is kept');
    expect(b.calls('POST /tasker/jobs/5/complaint'), isEmpty);

    await t.enterText(find.byType(TextField).last, 'Khách không có nhà khi tôi tới, đã gọi nhiều lần.');
    await t.pump();
    expect(find.byKey(const ValueKey('reason-min-hint')), findsNothing);
    await t.tap(find.byKey(const ValueKey('reason-confirm')));
    await t.pumpAndSettle();
    expect(b.calls('POST /tasker/jobs/5/complaint'), hasLength(1));
    await t.pump(const Duration(seconds: 6));
  });
}
