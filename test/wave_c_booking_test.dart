// Wave C - UX-M09 live tracking, UX-M11 chat thread, UX-M13 customer SOS,
// UX-M17 tasker profile link on booking detail.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/bookings/booking_detail_screen.dart';
import 'package:kyco_mobile/features/bookings/customer_sos.dart';
import 'package:kyco_mobile/features/bookings/tracking_card.dart';
import 'package:kyco_mobile/features/messages/message_thread_screen.dart';
import 'package:kyco_mobile/features/tasker_job_detail/native_capture.dart';

import 'wave_c_support.dart';

Map<String, dynamic> _page({String status = 'EN_ROUTE', List<Map<String, dynamic>> messages = const []}) => {
      'booking': {
        'id': 5, 'status': status, 'totalVnd': 480000, 'paymentMethod': 'cash',
        'createdAt': '2026-01-15T12:00:00Z', 'scheduledAt': '2026-01-17T12:00:00Z',
        'addressLine': '45 Lê Lợi', 'district': 'Quận 1',
      },
      'service': {'id': 1, 'name': 'Vệ sinh nhà'},
      'job': {'id': 77, 'status': 'active', 'taskerId': 4},
      'tasker': {'id': 4, 'name': 'Nguyễn Thị Lan'},
      'messages': messages,
      'hasReview': false,
    };

Map<String, dynamic> _loc({double? lat = 10.78, double? lng = 106.7, int? dist = 2400, int? eta = 9, int age = 10}) => {
      'position': lat == null
          ? null
          : {
              'lat': lat, 'lng': lng, 'accuracy': 12, 'heading': 90, 'speed': 5.5,
              'recordedAt': '2026-01-17T03:30:00Z', 'ageSec': age,
            },
      'distanceM': dist,
      'etaMin': eta,
    };

void main() {
  group('JobTracking.fromJson', () {
    test('full, null position and junk', () {
      final t = JobTracking.fromJson(_loc());
      expect(t.hasPosition, isTrue);
      expect(t.distanceM, 2400);
      expect(t.etaMin, 9);
      expect(JobTracking.fromJson(_loc(lat: null, dist: null, eta: null)).hasPosition, isFalse);
      expect(JobTracking.fromJson({'position': 'x'}).hasPosition, isFalse);
    });
    test('trackable statuses', () {
      for (final s in ['EN_ROUTE', 'ARRIVED', 'CHECKED_IN', 'ACTIVE']) {
        expect(isTrackable(s), isTrue, reason: s);
      }
      for (final s in ['PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED']) {
        expect(isTrackable(s), isFalse, reason: s);
      }
    });
  });

  group('UX-M09 TrackingCard', () {
    testWidgets('shows VN time, distance + ETA text from server fields, static position', (t) async {
      useTallView(t, w: 400);
      final sem = t.ensureSemantics();
      final b = Backend()..on('GET /jobs/77/location', (_) => Backend.ok(_loc()));
      final h = await harness(backend: b);
      await t.pumpWidget(appWith(h, const Scaffold(body: TrackingCard(jobId: 77))));
      await t.pumpAndSettle();
      expect(find.text(vi.trackUpdatedAt('10:30')), findsOneWidget, reason: '03:30Z = 10:30 VN');
      expect(find.text(vi.trackDistanceKm('2.4')), findsOneWidget);
      expect(find.text(vi.trackEta(9)), findsOneWidget);
      expect(find.text(vi.trackCoords('10.78000', '106.70000')), findsOneWidget);
      expect(find.text(vi.trackStale), findsNothing);
      expect(find.bySemanticsLabel(vi.trackOpenMapLabel), findsOneWidget, reason: 'accessible label');
      sem.dispose();
    });

    testWidgets('under 1 km is metres; stale position is flagged', (t) async {
      useTallView(t, w: 400);
      final b = Backend()..on('GET /jobs/77/location', (_) => Backend.ok(_loc(dist: 640, age: 300)));
      final h = await harness(backend: b);
      await t.pumpWidget(appWith(h, const Scaffold(body: TrackingCard(jobId: 77))));
      await t.pumpAndSettle();
      expect(find.text(vi.trackDistanceM(640)), findsOneWidget);
      expect(find.text(vi.trackStale), findsOneWidget);
    });

    testWidgets('no position yet (200 position:null) -> friendly empty state', (t) async {
      final b = Backend()..on('GET /jobs/77/location', (_) => Backend.ok(_loc(lat: null, dist: null, eta: null)));
      final h = await harness(backend: b);
      await t.pumpWidget(appWith(h, const Scaffold(body: TrackingCard(jobId: 77))));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('tracking-empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('tracking-open-map')), findsNothing);
    });

    for (final code in [404, 403]) {
      testWidgets('HTTP $code -> same friendly empty state, no error banner', (t) async {
        final b = Backend()..on('GET /jobs/77/location', (_) => Backend.err(code, code == 404 ? 'NOT_FOUND' : 'FORBIDDEN'));
        final h = await harness(backend: b);
        await t.pumpWidget(appWith(h, const Scaffold(body: TrackingCard(jobId: 77))));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('tracking-empty')), findsOneWidget);
        expect(find.byKey(const ValueKey('tracking-error')), findsNothing);
      });
    }

    testWidgets('server error -> retry copy', (t) async {
      final b = Backend()..on('GET /jobs/77/location', (_) => Backend.err(500, 'INTERNAL'));
      final h = await harness(backend: b);
      await t.pumpWidget(appWith(h, const Scaffold(body: TrackingCard(jobId: 77))));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('tracking-error')), findsOneWidget);
    });

    testWidgets('Open map launches a maps https URL with the server coordinates', (t) async {
      useTallView(t, w: 400);
      final opened = <Uri>[];
      final b = Backend()..on('GET /jobs/77/location', (_) => Backend.ok(_loc()));
      final h = await harness(backend: b, opener: (u) async {
        opened.add(u);
        return true;
      });
      await t.pumpWidget(appWith(h, const Scaffold(body: TrackingCard(jobId: 77))));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('tracking-open-map')));
      await t.pump();
      expect(opened, hasLength(1));
      expect(opened.single.scheme, 'https');
      expect(opened.single.queryParameters['query'], '10.78,106.7');
    });

    testWidgets('polls on the interval while mounted; stops after dispose', (t) async {
      final b = Backend()..on('GET /jobs/77/location', (_) => Backend.ok(_loc()));
      final h = await harness(backend: b);
      await t.pumpWidget(appWith(h, const Scaffold(body: TrackingCard(jobId: 77))));
      await t.pumpAndSettle();
      expect(b.calls('GET /jobs/77/location'), hasLength(1));
      await t.pump(kTrackingPollInterval);
      await t.pumpAndSettle();
      expect(b.calls('GET /jobs/77/location'), hasLength(2));
      await t.pump(kTrackingPollInterval);
      await t.pumpAndSettle();
      expect(b.calls('GET /jobs/77/location'), hasLength(3));
      // Leave the screen: no further requests, ever.
      await t.pumpWidget(appWith(h, const Scaffold(body: SizedBox())));
      final n = b.calls('GET /jobs/77/location').length;
      await t.pump(kTrackingPollInterval * 5);
      expect(b.calls('GET /jobs/77/location'), hasLength(n));
    });

    testWidgets('polling pauses while the app is in the background, resumes on return', (t) async {
      final b = Backend()..on('GET /jobs/77/location', (_) => Backend.ok(_loc()));
      final h = await harness(backend: b);
      await t.pumpWidget(appWith(h, const Scaffold(body: TrackingCard(jobId: 77))));
      await t.pumpAndSettle();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(kTrackingPollInterval * 3);
      expect(b.calls('GET /jobs/77/location'), hasLength(1), reason: 'no polling in background');
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pump(const Duration(milliseconds: 100)); // first frame after re-enabling frames
      await t.pumpAndSettle();
      expect(b.calls('GET /jobs/77/location'), hasLength(2), reason: 'catch-up on resume');
    });

    testWidgets('hidden by an inactive shell tab (TickerMode off) -> no request', (t) async {
      final b = Backend()..on('GET /jobs/77/location', (_) => Backend.ok(_loc()));
      final h = await harness(backend: b);
      await t.pumpWidget(appWith(
          h, const Scaffold(body: TickerMode(enabled: false, child: TrackingCard(jobId: 77)))));
      await t.pumpAndSettle();
      final n = b.calls('GET /jobs/77/location').length;
      await t.pump(kTrackingPollInterval * 3);
      expect(b.calls('GET /jobs/77/location'), hasLength(n));
    });
  });

  group('booking detail wiring', () {
    Future<Harness> pumpDetail(WidgetTester t, String status, {Backend? backend}) async {
      useTallView(t, w: 400);
      final b = backend ?? Backend();
      b.on('GET /bookings/5/page', (_) => Backend.ok(_page(status: status)));
      b.on('GET /jobs/77/location', (_) => Backend.ok(_loc()));
      final h = await harness(backend: b);
      await t.pumpWidget(routerWith(h, '/bookings/5', {
        '/bookings/5': (_) => const BookingDetailScreen(id: 5),
        '/taskers/:id': (s) => Scaffold(body: Text('TASKER ${s.pathParameters['id']}')),
        '/messages/:id': (s) => Scaffold(body: Text('CHAT ${s.pathParameters['id']}')),
      }));
      await t.pumpAndSettle();
      return h;
    }

    testWidgets('EN_ROUTE: tracking card + SOS visible', (t) async {
      await pumpDetail(t, 'EN_ROUTE');
      expect(find.byKey(const ValueKey('tracking-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('customer-sos')), findsOneWidget);
    });

    testWidgets('PENDING: neither tracking nor SOS', (t) async {
      await pumpDetail(t, 'PENDING');
      expect(find.byKey(const ValueKey('tracking-card')), findsNothing);
      expect(find.byKey(const ValueKey('customer-sos')), findsNothing);
    });

    testWidgets('UX-M17 tasker row opens /taskers/:id', (t) async {
      await pumpDetail(t, 'CONFIRMED');
      await t.tap(find.byKey(const ValueKey('booking-tasker-row')));
      await t.pumpAndSettle();
      expect(find.text('TASKER 4'), findsOneWidget);
    });

    testWidgets('chat entry opens the booking thread', (t) async {
      await pumpDetail(t, 'CONFIRMED');
      await t.ensureVisible(find.byKey(const ValueKey('booking-chat')));
      await t.tap(find.byKey(const ValueKey('booking-chat')));
      await t.pumpAndSettle();
      expect(find.text('CHAT 5'), findsOneWidget);
    });
  });

  group('UX-M13 customer SOS', () {
    Future<Backend> pumpSos(WidgetTester t, {GpsFix? fix}) async {
      final b = Backend()
        ..on('POST /sos', (_) => Backend.ok({'id': 9, 'deduped': false, 'bookingAttached': true}, status: 201));
      final h = await harness(backend: b, extra: [sosLocatorProvider.overrideWithValue(() async => fix)]);
      await t.pumpWidget(appWith(h, const Scaffold(body: CustomerSosButton(bookingId: 5))));
      await t.pumpAndSettle();
      return b;
    }

    testWidgets('confirm -> POST /sos with bookingId + best-effort GPS', (t) async {
      final b = await pumpSos(t, fix: const GpsFix(lat: 10.5, lon: 106.5, accuracyM: 8));
      await t.tap(find.byKey(const ValueKey('customer-sos')));
      await t.pumpAndSettle();
      expect(find.text(vi.sosCustomerBody), findsOneWidget);
      expect(b.calls('POST /sos'), isEmpty, reason: 'nothing sent before confirming');
      await t.tap(find.byKey(const ValueKey('sos-confirm')));
      await t.pumpAndSettle();
      final body = b.calls('POST /sos').single.data as Map;
      expect(body['bookingId'], 5);
      expect(body['lat'], 10.5);
      expect(body['lng'], 106.5);
      expect(body['accuracyM'], 8);
      expect(find.text(vi.provJdSosSent), findsOneWidget);
    });

    testWidgets('no GPS fix still sends the alert (location-only fields omitted)', (t) async {
      final b = await pumpSos(t);
      await t.tap(find.byKey(const ValueKey('customer-sos')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('sos-confirm')));
      await t.pumpAndSettle();
      final body = b.calls('POST /sos').single.data as Map;
      expect(body['bookingId'], 5);
      expect(body.containsKey('lat'), isFalse);
    });

    testWidgets('cancel in the dialog sends nothing', (t) async {
      final b = await pumpSos(t);
      await t.tap(find.byKey(const ValueKey('customer-sos')));
      await t.pumpAndSettle();
      await t.tap(find.text(vi.cust2Cancel));
      await t.pumpAndSettle();
      expect(b.calls('POST /sos'), isEmpty);
    });
  });

  group('UX-M11 chat thread (GET via /page composite, POST /bookings/{id}/messages)', () {
    Future<Backend> pumpThread(WidgetTester t, List<Map<String, dynamic>> msgs, {Backend? backend}) async {
      useTallView(t, w: 400);
      final b = backend ?? Backend();
      b.on('GET /bookings/5/page', (_) => Backend.ok(_page(messages: msgs)));
      final h = await harness(backend: b);
      await t.pumpWidget(routerWith(h, '/messages/5', {
        '/messages/:id': (_) => const MessageThreadScreen(id: 5),
      }));
      await t.pumpAndSettle();
      return b;
    }

    testWidgets('empty state', (t) async {
      await pumpThread(t, const []);
      expect(find.byKey(const ValueKey('chat-empty')), findsOneWidget);
    });

    testWidgets('renders both sides in order', (t) async {
      await pumpThread(t, [
        {'id': 1, 'fromRole': 'customer', 'body': 'Chào bạn', 'createdAt': '2026-01-17T03:00:00Z'},
        {'id': 2, 'fromRole': 'tasker', 'body': 'Tôi đang đến', 'createdAt': '2026-01-17T03:05:00Z'},
      ]);
      expect(find.text('Chào bạn'), findsOneWidget);
      expect(find.text('Tôi đang đến'), findsOneWidget);
      expect(t.getTopLeft(find.text('Chào bạn')).dy, lessThan(t.getTopLeft(find.text('Tôi đang đến')).dy));
    });

    testWidgets('send posts {body} once even on a double tap (in-flight guard)', (t) async {
      final b = Backend();
      b.on('POST /bookings/5/messages', (_) => Backend.ok({'bookingId': 5, 'fromRole': 'customer'}, status: 201));
      await pumpThread(t, const [], backend: b);
      await t.enterText(find.byKey(const ValueKey('chat-input')), '  Xin chào  ');
      await t.tap(find.byKey(const ValueKey('chat-send')));
      await t.tap(find.byKey(const ValueKey('chat-send')), warnIfMissed: false);
      await t.pumpAndSettle();
      final posts = b.calls('POST /bookings/5/messages').toList();
      expect(posts, hasLength(1));
      expect(posts.single.data, {'body': 'Xin chào'});
      expect((t.widget<TextField>(find.byKey(const ValueKey('chat-input'))).controller!.text), isEmpty);
    });

    testWidgets('empty/whitespace is never sent', (t) async {
      final b = Backend();
      b.on('POST /bookings/5/messages', (_) => Backend.ok({}, status: 201));
      await pumpThread(t, const [], backend: b);
      await t.enterText(find.byKey(const ValueKey('chat-input')), '   ');
      await t.tap(find.byKey(const ValueKey('chat-send')));
      await t.pumpAndSettle();
      expect(b.calls('POST /bookings/5/messages'), isEmpty);
    });

    testWidgets('send failure keeps the text and shows the error', (t) async {
      final b = Backend();
      b.on('POST /bookings/5/messages', (_) => Backend.err(429, 'RATE_LIMIT'));
      await pumpThread(t, const [], backend: b);
      await t.enterText(find.byKey(const ValueKey('chat-input')), 'hello');
      await t.tap(find.byKey(const ValueKey('chat-send')));
      await t.pumpAndSettle();
      expect(find.text(vi.cust2ErrRateLimit), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(const ValueKey('chat-input'))).controller!.text, 'hello');
    });

    testWidgets('polls while visible and stops when the screen is gone', (t) async {
      final b = await pumpThread(t, const []);
      expect(b.calls('GET /bookings/5/page'), hasLength(1));
      await t.pump(kChatPollInterval);
      await t.pumpAndSettle();
      expect(b.calls('GET /bookings/5/page'), hasLength(2));
      await t.pumpWidget(const SizedBox());
      final n = b.calls('GET /bookings/5/page').length;
      await t.pump(kChatPollInterval * 4);
      expect(b.calls('GET /bookings/5/page'), hasLength(n));
    });

    testWidgets('not found booking -> message, no composer crash', (t) async {
      useTallView(t, w: 400);
      final b = Backend()..on('GET /bookings/5/page', (_) => Backend.err(404, 'NOT_FOUND'));
      final h = await harness(backend: b);
      await t.pumpWidget(routerWith(h, '/m', {'/m': (_) => const MessageThreadScreen(id: 5)}));
      await t.pumpAndSettle();
      expect(find.text(vi.bookingNotFound(5)), findsOneWidget);
    });
  });

  test('BookingDetail.fromPage carries jobId + messages', () {
    final d = BookingDetail.fromPage(_page(messages: [
      {'id': 1, 'fromRole': 'customer', 'body': 'a', 'createdAt': null},
      {'id': 'bad'},
    ]));
    expect(d.jobId, 77);
    expect(d.messages, hasLength(1));
    expect(d.messages.single.fromCustomer, isTrue);
    expect(GoRouter, isNotNull);
  });
}
