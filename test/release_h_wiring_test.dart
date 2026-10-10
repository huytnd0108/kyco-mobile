// Backend release-h (kyco d69b0328) wiring: every new DTO field is optional, so
// each model parses BOTH shapes and each surface renders both. Fixtures in
// test/fixtures/release_h are written from the DTO code (authenticated routes
// cannot be captured anonymously); the d69b0328 file:line of each builder:
//   notifications  lib/notifications/render.ts:16 (NotificationData), :62-80 (enrich)
//   actions        lib/bookings/action-guards.ts:58-98, lib/bookings/page-read.ts:229-232
//   application    lib/onboarding/application-read.ts:12,35 (+ profile/read.ts:61, app/api/v1/kyc/route.ts:11)
//   bonuses        lib/bonus/labels.ts:43-60, lib/tasker/bonuses-read.ts:19,93
//   pool block     lib/tasker/block-reason.ts:5,15, app/api/v1/tasker/jobs/pool/route.ts:32,76
//   conflictJobs   lib/availability/write.ts:43,58
//   comp. labels   lib/cancel/pending-comp.ts:110-143, app/api/v1/bookings/quote/route.ts:58
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/become_tasker/become_tasker_screen.dart';
import 'package:kyco_mobile/features/bookings/booking_detail_screen.dart';
import 'package:kyco_mobile/features/home/home_providers.dart' show bookingDetailProvider;
import 'package:kyco_mobile/features/bookings/booking_money_actions.dart';
import 'package:kyco_mobile/features/notifications/notifications_providers.dart';
import 'package:kyco_mobile/features/notifications/notifications_screen.dart';
import 'package:kyco_mobile/features/tasker_availability/tasker_availability_screen.dart';
import 'package:kyco_mobile/features/tasker_growth/tasker_bonuses_screen.dart';
import 'package:kyco_mobile/features/tasker_growth/tasker_growth_providers.dart';
import 'package:kyco_mobile/features/tasker_jobs/tasker_jobs_providers.dart';
import 'package:kyco_mobile/features/tasker_jobs/tasker_jobs_screen.dart';

import 'wave_c_support.dart';

dynamic _fx(String name) => jsonDecode(File('test/fixtures/release_h/$name').readAsStringSync());
Map<String, dynamic> _map(String name, [String? key]) {
  final j = _fx(name) as Map<String, dynamic>;
  return key == null ? j : j[key] as Map<String, dynamic>;
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  // ── 1. notifications ──────────────────────────────────────────────────────
  group('notifications', () {
    final rows = (_fx('notifications.json') as List).cast<Map<String, dynamic>>();
    final old = (_fx('notifications_old.json') as List).cast<Map<String, dynamic>>();

    test('data parses both ids, service, ISO time and total; null / absent data -> null', () {
      final a = NotificationItem.fromJson(rows[0]);
      expect(a.data!.bookingId, 5);
      expect(a.data!.jobId, isNull);
      expect(a.data!.serviceName, 'Vệ sinh nhà theo giờ');
      expect(a.data!.scheduledAt, '2026-10-12T02:00:00.000Z');
      expect(a.data!.totalVnd, 300000);
      final j = NotificationItem.fromJson(rows[1]);
      expect((j.data!.jobId, j.data!.bookingId, j.data!.totalVnd), (118, 77, null));
      expect(NotificationItem.fromJson(rows[2]).data, isNull);
      expect(NotificationItem.fromJson(old[0]).data, isNull);
      expect(NotificationData.tryParse(<String, dynamic>{}), isNull);
      expect(NotificationData.tryParse('junk'), isNull);
    });

    test('tap target: structured data first (job, then booking), then the link', () {
      expect(inAppRouteForNotification(NotificationItem.fromJson(rows[0])), '/bookings/5');
      expect(inAppRouteForNotification(NotificationItem.fromJson(rows[1])), '/p/jobs/118');
      // data wins even when the link points somewhere else
      final other = NotificationItem.fromJson({...rows[0], 'link': '/vi/subscriptions'});
      expect(inAppRouteForNotification(other), '/bookings/5');
      // no data -> the link, as before
      expect(inAppRouteForNotification(NotificationItem.fromJson(old[0])), '/bookings/5');
      expect(inAppRouteForNotification(NotificationItem.fromJson(rows[2])), isNull);
    });

    Future<Harness> pumpList(WidgetTester t, List<Map<String, dynamic>> items) async {
      useTallView(t, w: 800, h: 1400);
      final b = Backend();
      b.on('GET /notifications', (_) => (status: 200, body: {'ok': true, 'data': items, 'meta': {'unread': 2}}));
      b.on('POST /notifications/9003/read', (_) => Backend.ok({}));
      b.on('POST /notifications/9002/read', (_) => Backend.ok({}));
      final h = await harness(backend: b);
      await t.pumpWidget(routerWith(h, '/notifications', {
        '/notifications': (_) => const NotificationsScreen(),
        '/bookings/:id': (s) => Scaffold(body: Text('BOOKING ${s.pathParameters['id']}')),
        '/p/jobs/:id': (s) => Scaffold(body: Text('JOB ${s.pathParameters['id']}')),
      }));
      await _settle(t);
      return h;
    }

    testWidgets('new shape: service, VN time and total shown from data; tap opens by id', (t) async {
      await pumpList(t, rows);
      // 02:00Z = 09:00 in Vietnam, whatever the device zone.
      expect(find.textContaining('Vệ sinh nhà theo giờ · '), findsNWidgets(2));
      expect(find.textContaining('09:00'), findsWidgets);
      expect(find.textContaining('300.000₫'), findsOneWidget);
      // the tasker row never carries a total
      expect(find.textContaining('300.000₫'), findsOneWidget);
      await t.tap(find.text(rows[0]['title'] as String));
      await _settle(t);
      expect(find.text('BOOKING 5'), findsOneWidget);
    });

    testWidgets('tasker row opens the job by data.jobId', (t) async {
      await pumpList(t, rows);
      await t.tap(find.text(rows[1]['title'] as String));
      await _settle(t);
      expect(find.text('JOB 118'), findsOneWidget);
    });

    testWidgets('old shape (no data): title/body as sent, no detail line, link navigation unchanged', (t) async {
      await pumpList(t, old);
      expect(find.text(old[0]['title'] as String), findsOneWidget);
      expect(find.textContaining(' · '), findsNothing);
      await t.tap(find.text(old[0]['title'] as String));
      await _settle(t);
      expect(find.text('BOOKING 5'), findsOneWidget);
    });
  });

  // ── 2. booking action blocked reasons ─────────────────────────────────────
  group('booking actions', () {
    final a = _map('page_actions.json');

    test('every <x>BlockedReason{code,label} parses to its label; legacy string and absent still work', () {
      final s = ServerActions.tryParse(a['cancel'])!;
      expect(s.cancelBlockedReason, 'Cộng tác viên đã đến nơi nên không thể huỷ.');
      expect(s.confirmBlockedReason, startsWith('Cộng tác viên chưa báo'));
      expect(s.payBlockedReason, startsWith('Đơn chưa tới bước thanh toán'));
      expect(s.disputeBlockedReason, startsWith('Cộng tác viên chưa báo'));
      expect(ServerActions.tryParse({'canCancel': false, 'cancelBlockedReason': 'legacy text'})!.cancelBlockedReason,
          'legacy text');
      final none = ServerActions.tryParse({'canCancel': false})!;
      expect((none.cancelBlockedReason, none.confirmBlockedReason, none.payBlockedReason, none.disputeBlockedReason),
          (null, null, null, null));
      expect(ServerActions.tryParse({'canCancel': true, 'cancelBlockedReason': {'code': 'X'}})!.cancelBlockedReason, isNull);
    });

    BookingDetail booking(String status, Map<String, dynamic> actions, {String method = 'momo'}) =>
        BookingDetail.fromPage({
          'booking': {'id': 5, 'status': status, 'totalVnd': 510000, 'paymentMethod': method, 'scheduledAt': '2026-10-12T02:00:00Z'},
          'service': {'id': 1, 'name': 'Don dep'},
          'actions': actions,
          'hasReview': false,
        });

    Future<void> pumpSection(WidgetTester t, BookingDetail b) async {
      useTallView(t, w: 420, h: 1200);
      final h = await harness();
      await t.pumpWidget(appWith(h, Scaffold(body: SingleChildScrollView(child: BookingMoneySection(b)))));
      await _settle(t);
    }

    testWidgets('confirm + pay + dispute reasons show their server label (deduplicated)', (t) async {
      await pumpSection(t, booking('CONFIRMED', a['cancel'] as Map<String, dynamic>));
      // confirm and dispute share one sentence -> shown once
      expect(find.text('Cộng tác viên chưa báo hoàn thành nên chưa thể xác nhận.'), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-confirm-blocked')), findsOneWidget);
      expect(find.byKey(const ValueKey('booking-dispute-blocked')), findsNothing);
      expect(find.byKey(const ValueKey('booking-pay-blocked')), findsOneWidget);
      expect(find.textContaining('Đơn chưa tới bước thanh toán'), findsOneWidget);
      // cancel keeps its own (existing) block, now with the {code,label} label
      expect(find.text('Cộng tác viên đã đến nơi nên không thể huỷ.'), findsOneWidget);
    });

    testWidgets('dispute reason sits under the disabled dispute button', (t) async {
      await pumpSection(t, booking('AWAITING_CUSTOMER_CONFIRMATION', a['dispute_waiting'] as Map<String, dynamic>));
      final btn = t.widget<OutlinedButton>(find.byKey(const ValueKey('booking-dispute-cta')));
      expect(btn.onPressed, isNull);
      expect(find.byKey(const ValueKey('booking-dispute-blocked')), findsOneWidget);
      expect(find.textContaining('Chưa hoàn thành'), findsOneWidget);
      expect(find.text(vi.moneyDisputeWaiting), findsNothing); // the server label replaces the generic copy
    });

    testWidgets('finished bookings stay quiet', (t) async {
      await pumpSection(t, booking('SETTLED', a['pay_cash'] as Map<String, dynamic>, method: 'cash'));
      expect(find.byKey(const ValueKey('booking-confirm-blocked')), findsNothing);
      expect(find.byKey(const ValueKey('booking-pay-blocked')), findsNothing);
    });

    testWidgets('old backend (flags only): no reason widgets, behaviour unchanged', (t) async {
      await pumpSection(t, booking('CONFIRMED', {'canCancel': true, 'canConfirm': false, 'canPay': false, 'canDispute': false}));
      expect(find.byKey(const ValueKey('booking-confirm-blocked')), findsNothing);
      expect(find.byKey(const ValueKey('booking-pay-blocked')), findsNothing);
      expect(find.byKey(const ValueKey('booking-cancel-cta')), findsOneWidget);
    });
  });

  // ── 7. localized compensation labels ──────────────────────────────────────
  group('compensation labels', () {
    test('the quote and page breakdown keep the server label as sent (localized by the server)', () {
      final q = BookingQuote.tryParse(_map('quote_breakdown.json'))!;
      expect(q.breakdown!.compensations.single.label, 'Cancellation compensation fee, booking #41');
      expect(q.breakdown!.compensations.single.amountVnd, 30000);
    });

    testWidgets('booking detail lists the localized label line', (t) async {
      useTallView(t, w: 420, h: 1600);
      final detail = BookingDetail.fromPage({
        'booking': {
          'id': 5, 'status': 'CONFIRMED', 'totalVnd': 540000, 'paymentMethod': 'cash', 'scheduledAt': '2026-10-12T02:00:00Z',
          'surchargeBreakdownJson': _map('quote_breakdown.json', 'breakdown'),
        },
        'service': {'id': 1, 'name': 'Don dep'},
        'hasReview': false,
      });
      final h = await harness(extra: [bookingDetailProvider.overrideWith((ref, id) => Future.value(detail))]);
      await t.pumpWidget(appWith(h, const BookingDetailScreen(id: 5), locale: const Locale('en')));
      await _settle(t);
      expect(find.text('Cancellation compensation fee, booking #41'), findsOneWidget);
    });
  });

  // ── 3. pending_tasker application ─────────────────────────────────────────
  group('application', () {
    test('GET /kyc body and /me application parse; absent -> null', () {
      final r = TaskerApplication.fromKycBody(_fx('kyc_rejected.json'))!;
      expect(r.status, 'rejected');
      expect(r.statusLabel, startsWith('Hồ sơ cần bổ sung'));
      expect(r.reviewedAt, '2026-10-09T08:30:00.000Z');
      expect(r.rejectionReason, 'Ảnh CCCD mặt trước bị mờ');
      expect(r.documents.map((d) => (d.docKind, d.status)),
          [('cccd_front', 'rejected'), ('cccd_back', 'approved'), ('selfie', 'pending')]);
      expect(r.documents.first.reason, 'Ảnh CCCD mặt trước bị mờ');
      final p = TaskerApplication.fromKycBody(_fx('kyc_pending.json'))!;
      expect((p.reviewedAt, p.rejectionReason), (null, null));
      expect(AuthUser.fromJson({'id': 3, 'role': 'pending_tasker', 'application': _map('kyc_pending.json', 'application')}).application!.status, 'pending');
      expect(AuthUser.fromJson({'id': 3, 'role': 'pending_tasker'}).application, isNull);
      expect(AuthUser.fromJson({'id': 3, 'role': 'customer', 'application': null}).application, isNull);
      expect(TaskerApplication.fromKycBody({'application': null}), isNull);
    });

    Future<void> pumpReview(WidgetTester t, {Object? kyc, int kycStatus = 200, TaskerApplication? meApplication}) async {
      useTallView(t, w: 420, h: 1800);
      final b = Backend();
      if (kyc != null) b.on('GET /kyc', (_) => (status: kycStatus, body: {'ok': true, 'data': kyc}));
      final auth = AuthState(
          status: AuthStatus.signedIn,
          user: AuthUser(id: 9, role: 'pending_tasker', application: meApplication));
      final h = await harness(backend: b, auth: auth);
      await t.pumpWidget(appWith(h, const BecomeTaskerScreen()));
      await _settle(t);
    }

    testWidgets('rejected: status label, dates, reason, per-document status, re-upload only for the rejected doc', (t) async {
      await pumpReview(t, kyc: _fx('kyc_rejected.json'));
      expect(find.text('Hồ sơ cần bổ sung'), findsOneWidget); // title switches for a rejected application
      expect(find.byKey(const ValueKey('tasker-app-status')), findsOneWidget);
      expect(find.textContaining('Hồ sơ cần bổ sung. Vui lòng xem lý do'), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-app-submitted')), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-app-reviewed')), findsOneWidget);
      expect(find.textContaining('15:30'), findsOneWidget); // 08:30Z reviewed -> VN time
      expect(find.byKey(const ValueKey('tasker-app-rejection')), findsOneWidget);
      expect(find.text(vi.taskerAppDocRejected), findsOneWidget);
      expect(find.text(vi.taskerAppDocApproved), findsOneWidget);
      expect(find.text(vi.taskerAppDocPending), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-app-reupload-cccd_front')), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-app-reupload-cccd_back')), findsNothing);
      await t.ensureVisible(find.byKey(const ValueKey('tasker-app-reupload-cccd_front')));
      await t.tap(find.byKey(const ValueKey('tasker-app-reupload-cccd_front')));
      await _settle(t);
      expect(find.text(vi.provTaskerCaptureDocsTitle), findsOneWidget); // opens the capture form
    });

    testWidgets('pending: label + submitted date, no reason, no re-upload CTA per doc', (t) async {
      await pumpReview(t, kyc: _fx('kyc_pending.json'));
      expect(find.text(vi.taskerReviewTitle), findsOneWidget);
      expect(find.text('Hồ sơ đã được gửi và đang chờ Kyco xét duyệt.'), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-app-submitted')), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-app-reviewed')), findsNothing);
      expect(find.byKey(const ValueKey('tasker-app-rejection')), findsNothing);
      expect(find.text(vi.taskerAppDocPending), findsNWidgets(3));
      expect(find.byKey(const ValueKey('tasker-app-reupload-cccd_front')), findsNothing);
    });

    testWidgets('GET /kyc missing (older backend): falls back to the /me application', (t) async {
      await pumpReview(t, meApplication: TaskerApplication.fromKycBody(_fx('kyc_pending.json')));
      expect(find.text('Hồ sơ đã được gửi và đang chờ Kyco xét duyệt.'), findsOneWidget);
    });

    testWidgets('neither source: the static review screen as before', (t) async {
      await pumpReview(t);
      expect(find.text(vi.taskerReviewIntro), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-app-details')), findsNothing);
    });
  });

  // ── 5. bonuses ────────────────────────────────────────────────────────────
  group('bonuses', () {
    test('kindLabel and progress parse; weekly = weekly_jobs + punctuality, monthly = the other three', () {
      final b = TaskerBonuses.fromJson(_map('bonuses.json'));
      expect(b.weekly.map((x) => x.kind), ['weekly_jobs', 'punctuality']);
      expect(b.monthly.map((x) => x.kind), ['monthly_revenue', 'rating', 'referral']);
      expect(b.weekly.first.kindLabel, 'Thưởng tuần (số đơn)');
      final p = b.weekly.first.progress!;
      expect((p.code, p.current, p.target), ('NEED_JOBS', 4, 10));
      expect(p.fraction, closeTo(0.4, 1e-9));
      expect(b.weekly.last.progress!.fraction, 1.0); // current > target clamps
      expect(b.monthly[1].progress, isNull);
    });

    test('an older backend that repeats all five kinds in both lists shows no duplicate cards', () {
      final b = TaskerBonuses.fromJson(_map('bonuses_old.json'));
      expect(b.weekly.map((x) => x.kind), ['weekly_jobs', 'punctuality']);
      expect(b.monthly.map((x) => x.kind), ['monthly_revenue', 'rating', 'referral']);
      expect(b.weekly.first.kindLabel, isNull);
      expect(b.weekly.first.progress, isNull);
    });

    test('progress with no positive target has no bar; malformed progress is ignored', () {
      expect(BonusProgress.tryParse({'code': 'NO_JOBS', 'current': 0, 'target': 0, 'label': 'x'})!.hasBar, isFalse);
      expect(BonusProgress.tryParse({'code': 'X', 'current': 'a', 'target': 1}), isNull);
    });

    Future<void> pumpBonuses(WidgetTester t, String fixture) async {
      useTallView(t, w: 420, h: 2200);
      final data = TaskerBonuses.fromJson(_map(fixture));
      final h = await harness(
          auth: signedInAs('tasker'), extra: [bonusesProvider.overrideWith((ref) => Future.value(data))]);
      await t.pumpWidget(appWith(h, const TaskerBonusesScreen()));
      await _settle(t);
    }

    testWidgets('new shape: server title, localized label, progress bar at current/target', (t) async {
      await pumpBonuses(t, 'bonuses.json');
      expect(find.text('Thưởng tuần (số đơn)'), findsOneWidget);
      expect(find.text('Cần 10 đơn trong tuần, bạn đã hoàn thành 4.'), findsOneWidget);
      expect(find.text('Cần 10 job, mới 4'), findsNothing); // raw vi reason replaced
      final bar = t.widget<LinearProgressIndicator>(find.byKey(const ValueKey('bonus-progress-weekly_jobs')));
      expect(bar.value, closeTo(0.4, 1e-9));
      expect(find.byKey(const ValueKey('bonus-progress-rating')), findsNothing);
      // 2 weekly + 3 monthly cards, each kind once
      expect(find.text('Thưởng giới thiệu'), findsOneWidget);
      expect(find.text('Thưởng chuyên cần'), findsOneWidget);
    });

    testWidgets('old shape: app labels, raw reason, no bars, no duplicates', (t) async {
      await pumpBonuses(t, 'bonuses_old.json');
      expect(find.text('Cần 10 job, mới 4'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(vi.provBonusKindReferral), findsOneWidget);
      expect(find.text(vi.provBonusKindWeeklyJobs), findsOneWidget);
    });
  });

  // ── 6. pool block ─────────────────────────────────────────────────────────
  group('pool block', () {
    test('block{code,label,blockedUntil} parses; absent -> null', () {
      final v = PoolView.fromJson(_map('pool_blocked.json'));
      expect((v.block!.code, v.block!.blockedUntil), ('SUSPENDED', '2026-10-14T05:00:00.000Z'));
      expect(v.block!.label, startsWith('Tài khoản tạm ngưng'));
      expect(PoolView.fromJson(_map('pool_auto_old.json')).block, isNull);
      expect(TaskerBlock.tryParse({'code': 'X'}), isNull);
    });

    Future<void> pumpPool(WidgetTester t, String fixture) async {
      useTallView(t, w: 420, h: 1400);
      final view = PoolView.fromJson(_map(fixture));
      final h = await harness(auth: signedInAs('tasker'), extra: [
        poolProvider.overrideWith((ref) => Future.value(view)),
        assignedJobsControllerProvider.overrideWith(() => _EmptyAssigned()),
      ]);
      await t.pumpWidget(appWith(h, const TaskerJobsScreen()));
      await _settle(t);
      await t.tap(find.byType(Tab).last);
      await _settle(t);
    }

    testWidgets('suspended: label and blockedUntil in VN time', (t) async {
      await pumpPool(t, 'pool_blocked.json');
      expect(find.text('Tài khoản tạm ngưng nhận đơn đến 14/10/2026.'), findsOneWidget);
      final until = find.byKey(const ValueKey('pool-block-until'));
      expect(until, findsOneWidget);
      expect(t.widget<Text>(until).data, contains('12:00')); // 05:00Z -> 12:00 VN
      expect(t.widget<Text>(until).data, contains('14/10/2026'));
    });

    testWidgets('old backend: raw "Auto: ..." text is not shown, generic copy instead; no until line', (t) async {
      await pumpPool(t, 'pool_auto_old.json');
      expect(find.textContaining('Auto:'), findsNothing);
      expect(find.text(vi.provClaimGateBody), findsOneWidget);
      expect(find.byKey(const ValueKey('pool-block-until')), findsNothing);
    });
  });

  // ── 8. availability conflicts ─────────────────────────────────────────────
  group('availability conflictJobs', () {
    test('parse both shapes; conflictIds falls back to conflictJobs', () {
      final r = SaveAvailabilityResult.fromJson(_map('availability_conflict.json'));
      expect(r.conflicts, [118, 999]);
      expect(r.conflictJobs.single.serviceName, 'Vệ sinh nhà theo giờ');
      expect(r.conflictJobs.single.bookingId, 77);
      final old = SaveAvailabilityResult.fromJson({'saved': false, 'conflicts': [118]});
      expect(old.conflictJobs, isEmpty);
      final only = SaveAvailabilityResult.fromJson({'saved': false, 'conflictJobs': (_map('availability_conflict.json')['conflictJobs'])});
      expect(only.conflictIds, [118]);
    });

    Future<Backend> pumpAvail(WidgetTester t, Map<String, dynamic> putResponse, {bool knownJob = false}) async {
      useTallView(t, w: 420, h: 2000);
      final b = Backend();
      b.on('GET /tasker/availability', (_) => Backend.ok({'weekly': {'1': [{'start': 480, 'end': 720}]}, 'dates': <Object>[]}));
      b.on('GET /tasker/jobs', (_) => Backend.ok(knownJob
          ? [{'jobId': 118, 'jobStatus': 'active', 'serviceName': 'Tên cũ từ danh sách', 'scheduledAt': '2026-10-12T02:00:00Z'}]
          : <Object>[]));
      b.on('PUT /tasker/availability/weekly', (_) => Backend.ok(putResponse));
      final h = await harness(backend: b, auth: signedInAs('tasker'));
      await t.pumpWidget(appWith(h, const TaskerAvailabilityScreen()));
      await t.pumpAndSettle();
      final c = ProviderScope.containerOf(t.element(find.byType(TaskerAvailabilityScreen)));
      c.listen(assignedJobsControllerProvider, (_, _) {});
      await t.pumpAndSettle();
      await t.tap(find.text(vi.provAvailWeekdayShort1));
      await t.pumpAndSettle();
      await t.tap(find.text(vi.provAvailAddSlot));
      await t.pumpAndSettle();
      await t.tap(find.text(vi.provAvailSave));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      return b;
    }

    testWidgets('new shape: the dialog uses conflictJobs (name + VN time), the unknown id stays bare', (t) async {
      await pumpAvail(t, _map('availability_conflict.json'));
      expect(find.text(vi.provAvailConflictTitle), findsOneWidget);
      expect(find.textContaining('Vệ sinh nhà theo giờ (12/10'), findsOneWidget);
      expect(find.textContaining('09:00'), findsOneWidget);
      expect(find.textContaining('#999'), findsOneWidget);
      expect(find.textContaining('#118'), findsNothing);
    });

    testWidgets('conflictJobs win over the assigned list; old shape falls back to the list lookup', (t) async {
      await pumpAvail(t, _map('availability_conflict.json'), knownJob: true);
      expect(find.textContaining('Vệ sinh nhà theo giờ (12/10'), findsOneWidget);
      expect(find.textContaining('Tên cũ từ danh sách'), findsNothing);
    });

    testWidgets('old backend: no conflictJobs -> assigned-list lookup, then bare id', (t) async {
      await pumpAvail(t, {'saved': false, 'conflicts': [118, 999]}, knownJob: true);
      expect(find.textContaining('Tên cũ từ danh sách (12/10'), findsOneWidget);
      expect(find.textContaining('#999'), findsOneWidget);
    });
  });
}

class _EmptyAssigned extends AssignedJobsController {
  @override
  Future<AssignedJobsData> build() async => const AssignedJobsData(items: []);
  @override
  Future<void> loadMore() async {}
}
