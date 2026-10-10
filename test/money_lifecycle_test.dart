// Customer money lifecycle (cancel / confirm completion / gateway pay) +
// withdraw error copy. Contract: qa-ws7/out/mobile/MONEY-CONTRACT.md (920563d).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/payment_poll.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/labels.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/ui/error_text.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart' show authUserIdProvider;
import 'package:kyco_mobile/features/bookings/booking_detail_screen.dart';
import 'package:kyco_mobile/features/bookings/booking_money_actions.dart';
import 'package:kyco_mobile/features/bookings/payment_flow.dart';
import 'package:kyco_mobile/features/home/home_providers.dart';
import 'package:kyco_mobile/features/tasker_job_detail/tasker_job_detail_data.dart';
import 'package:kyco_mobile/features/tasker_job_detail/tasker_job_detail_screen.dart' show JobCancelDialog;
import 'package:kyco_mobile/features/tasker_wallet/withdraw_sheet.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore;

final _vi = lookupAppLocalizations(const Locale('vi'));

class _Adapter implements HttpClientAdapter {
  _Adapter(this.data);
  final Object data;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add(o);
    return ResponseBody.fromString(jsonEncode({'ok': true, 'data': data}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

KycoApi _realApi2(HttpClientAdapter a) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1', validateStatus: (_) => true))
    ..httpClientAdapter = a;
  final tokens = InMemoryTokenStore()..save(access: 'a', refresh: 'r');
  return KycoApi(KycoApiClient(tokens: tokens, dio: dio), tokens);
}

KycoApi _realApi(_Adapter a) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1', validateStatus: (_) => true))
    ..httpClientAdapter = a;
  final tokens = InMemoryTokenStore()..save(access: 'a', refresh: 'r');
  return KycoApi(KycoApiClient(tokens: tokens, dio: dio), tokens);
}

ApiException _err(String code, int status, {String message = 'x', Map<String, String>? fields}) =>
    ApiException(code, message, status: status, fields: fields);

/// Scripted api for the widget flows: records calls, fails/succeeds on demand.
class _FakeApi extends KycoApi {
  _FakeApi() : super(KycoApiClient(tokens: InMemoryTokenStore()), InMemoryTokenStore());
  final cancels = <({int id, String code, String? text, String key})>[];
  final confirms = <({int id, String action, String? method, String? note, String key})>[];
  final initiates = <({int id, String key})>[];
  int statusReads = 0;

  Object? cancelFailure;
  Object? confirmFailure;
  Object? initiateFailure;
  Completer<void>? cancelGate;
  PaymentInitiateResult initiateResult =
      const PaymentInitiateResult(kind: 'ok', bookingId: 5, method: 'momo', payUrl: 'https://test-payment.momo.vn/x');
  List<PaymentStatusResult> statusScript = [];

  CancelResult cancelResult = const CancelResult();

  @override
  Future<CancelResult> cancelBooking(int id,
      {required String reasonCode, String? reasonText, required String idempotencyKey}) async {
    cancels.add((id: id, code: reasonCode, text: reasonText, key: idempotencyKey));
    if (cancelGate != null) await cancelGate!.future;
    if (cancelFailure != null) throw cancelFailure!;
    return cancelResult;
  }

  @override
  Future<void> confirmCompletion(int id,
      {required String action, String? paymentMethod, String? note, required String idempotencyKey}) async {
    confirms.add((id: id, action: action, method: paymentMethod, note: note, key: idempotencyKey));
    if (confirmFailure != null) throw confirmFailure!;
  }

  @override
  Future<PaymentInitiateResult> initiatePayment(int bookingId, {required String idempotencyKey}) async {
    initiates.add((id: bookingId, key: idempotencyKey));
    if (initiateFailure != null) throw initiateFailure!;
    return initiateResult;
  }

  @override
  Future<PaymentStatusResult> paymentStatus(int bookingId) async {
    final i = statusReads++;
    return statusScript[i < statusScript.length ? i : statusScript.length - 1];
  }
}

BookingDetail _booking(String status,
        {String method = 'cash',
        bool checkedIn = false,
        String? disputedAt,
        String? resubmittedAt,
        String? payment,
        bool manual = false,
        Object? breakdown,
        Map<String, dynamic>? actions,
        Map<String, dynamic>? cancelPreview,
        List<Map<String, dynamic>>? cancelReasons,
        int id = 5}) =>
    BookingDetail.fromPage({
      'booking': {
        'id': id,
        'status': status,
        'totalVnd': 510000,
        'paymentMethod': method,
        'scheduledAt': '2026-01-17T12:00:00Z',
        'customerDisputedAt': disputedAt,
        'taskerResubmittedAt': resubmittedAt,
        'manualSettlementRequired': manual,
        'surchargeBreakdownJson': breakdown,
      },
      'service': {'id': 1, 'name': 'Don dep'},
      'ctvHasCheckedIn': checkedIn,
      'actions': ?actions,
      'cancelPreview': ?cancelPreview,
      'cancelReasons': ?cancelReasons,
      if (payment != null) 'latestPayment': {'id': 1, 'status': payment},
      'hasReview': false,
    });

class _Harness {
  _Harness({BookingDetail? detail, _FakeApi? api})
      : api = api ?? _FakeApi(),
        current = detail ?? _booking('PENDING');
  final _FakeApi api;
  BookingDetail current;
  final ledger = IdempotencyLedger(store: MemoryPendingKeyStore());
  final launched = <Uri>[];
  bool launchResult = true;
  final show = ValueNotifier<bool>(true);

  Widget app() => ProviderScope(
        key: UniqueKey(),
        overrides: [
          kycoApiProvider.overrideWithValue(api),
          idempotencyLedgerProvider.overrideWithValue(ledger),
          authUserIdProvider.overrideWithValue(7),
          bookingDetailProvider.overrideWith((ref, id) => Future.value(current)),
          externalLauncherProvider.overrideWithValue((u) async {
            launched.add(u);
            return launchResult;
          }),
          paymentPollSleepProvider.overrideWithValue((_) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(lightColorScheme),
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
          valueListenable: show,
          builder: (_, on, _) => on ? BookingDetailScreen(id: current.id) : const Scaffold(),
        ),
        ),
      );

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await _settle(t);
  }
}

/// pumpAndSettle never settles while a progress spinner animates.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tapScroll(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await _settle(t);
  await t.tap(f);
  await t.pump();
}

void main() {
  // ── KycoApi: path, header, body ────────────────────────────────────────────
  group('KycoApi money methods', () {
    test('cancelBooking: POST /bookings/{id}/cancel, Idempotency-Key header, no amount', () async {
      final a = _Adapter({'intent': 'confirm', 'bookingId': 9});
      await _realApi(a).cancelBooking(9, reasonCode: 'plan_changed', reasonText: ' hi ', idempotencyKey: 'key-1234567');
      final r = a.requests.single;
      expect(r.method, 'POST');
      expect(r.path, '/bookings/9/cancel');
      expect(r.headers['Idempotency-Key'], 'key-1234567');
      expect(r.data, {'reasonCode': 'plan_changed', 'reasonText': 'hi'});
    });

    test('cancelBooking omits an empty reasonText', () async {
      final a = _Adapter({});
      await _realApi(a).cancelBooking(9, reasonCode: 'other', reasonText: '  ', idempotencyKey: 'key-1234567');
      expect(a.requests.single.data, {'reasonCode': 'other'});
    });

    test('confirmCompletion confirm: body is {action, paymentMethod} only', () async {
      final a = _Adapter({});
      await _realApi(a).confirmCompletion(4, action: 'confirm', paymentMethod: 'momo', idempotencyKey: 'key-1234567');
      final r = a.requests.single;
      expect(r.path, '/bookings/4/confirm-completion');
      expect(r.headers['Idempotency-Key'], 'key-1234567');
      expect(r.data, {'action': 'confirm', 'paymentMethod': 'momo'});
    });

    test('confirmCompletion dispute: body is {action, note} only (trimmed)', () async {
      final a = _Adapter({});
      await _realApi(a).confirmCompletion(4, action: 'dispute', note: '  khong sach  ', idempotencyKey: 'key-1234567');
      expect(a.requests.single.data, {'action': 'dispute', 'note': 'khong sach'});
    });

    test('initiatePayment: POST /payment/initiate {bookingId} + header; parses the result', () async {
      final a = _Adapter({
        'kind': 'ok', 'bookingId': 4, 'method': 'momo', 'payUrl': 'https://p/x', 'deeplink': 'momo://a',
        'providerTxId': 'T1', 'expiresAt': '2026-01-01T00:00:00Z'
      });
      final r = await _realApi(a).initiatePayment(4, idempotencyKey: 'key-1234567');
      final q = a.requests.single;
      expect(q.path, '/payment/initiate');
      expect(q.headers['Idempotency-Key'], 'key-1234567');
      expect(q.data, {'bookingId': 4});
      expect((r.kind, r.payUrl, r.deeplink, r.providerTxId), ('ok', 'https://p/x', 'momo://a', 'T1'));
    });

    test('paymentStatus: GET /bookings/{id}/payment-status, no body, no key', () async {
      final a = _Adapter({'status': 'pending', 'paid': false, 'failed': false});
      final s = await _realApi(a).paymentStatus(4);
      final q = a.requests.single;
      expect((q.method, q.path), ('GET', '/bookings/4/payment-status'));
      expect(q.headers.containsKey('Idempotency-Key'), isFalse);
      expect(s.serverSaysPaid, isFalse);
    });

    test('no money method ever puts an amount-like key in a body', () async {
      final a = _Adapter({});
      final api = _realApi(a);
      await api.cancelBooking(1, reasonCode: 'other', idempotencyKey: 'key-1234567');
      await api.confirmCompletion(1, action: 'confirm', paymentMethod: 'cash', idempotencyKey: 'key-1234568');
      await api.confirmCompletion(1, action: 'dispute', note: 'ten chars!!', idempotencyKey: 'key-1234569');
      await api.initiatePayment(1, idempotencyKey: 'key-1234560');
      for (final r in a.requests) {
        expect(jsonEncode(r.data).toLowerCase(), isNot(matches(r'amount|total|price|vnd|fee')));
      }
    });
  });

  // ── payment-status poll ────────────────────────────────────────────────────
  group('pollPaymentStatus', () {
    PaymentStatusResult st(String s, {bool paid = false, bool failed = false}) =>
        PaymentStatusResult(status: s, paid: paid, failed: failed);

    test('stops on paid', () async {
      final script = [st('pending'), st('pending'), st('paid', paid: true), st('failed', failed: true)];
      var i = 0;
      final slept = <Duration>[];
      final out = await pollPaymentStatus(() async => script[i++], sleep: (d) async => slept.add(d));
      expect(out, PaymentPollOutcome.paid);
      expect(i, 3);
      expect(slept, [const Duration(seconds: 2), const Duration(seconds: 4)]);
    });

    test('stops on failed', () async {
      var i = 0;
      final out = await pollPaymentStatus(() async => i++ < 1 ? st('pending') : st('failed', failed: true),
          sleep: (_) async {});
      expect(out, PaymentPollOutcome.failed);
      expect(i, 2);
    });

    test('times out (never paid) after the whole backoff schedule', () async {
      var reads = 0;
      final slept = <Duration>[];
      final out = await pollPaymentStatus(() async {
        reads++;
        return st('pending');
      }, sleep: (d) async => slept.add(d));
      expect(out, PaymentPollOutcome.timeout);
      expect(reads, kPaymentPollDelays.length + 1);
      expect(slept, kPaymentPollDelays);
      final total = slept.fold<int>(0, (a, d) => a + d.inSeconds);
      expect(total, inInclusiveRange(100, 140)); // about 2 minutes
      expect(slept.take(3), [const Duration(seconds: 2), const Duration(seconds: 4), const Duration(seconds: 8)]);
    });

    test('unknown / read errors never count as paid', () async {
      var i = 0;
      final out = await pollPaymentStatus(() async {
        i++;
        if (i.isEven) throw _err('network', 0);
        return st('unknown');
      }, sleep: (_) async {});
      expect(out, PaymentPollOutcome.timeout);
    });

    test('a status string "paid" without the paid flag still counts only via held/released', () {
      expect(st('paid').serverSaysPaid, isFalse); // the server flag decides
      expect(st('held').serverSaysPaid, isTrue);
      expect(st('released').serverSaysPaid, isTrue);
      expect(st('refunded').serverSaysFailed, isTrue);
    });

    test('cancelled poll resolves to timeout, not paid', () async {
      final out = await pollPaymentStatus(() async => st('pending'), isCancelled: () => true, sleep: (_) async {});
      expect(out, PaymentPollOutcome.timeout);
    });
  });

  // ── who may do what (table over every contract status) ─────────────────────
  group('button visibility per status', () {
    const cancellable = {'PENDING', 'CONFIRMED', 'EN_ROUTE'};
    test('model: every status', () {
      for (final s in kBookingStatuses) {
        final a = BookingActions.of(_booking(s, method: 'momo'));
        expect(a.canCancel, cancellable.contains(s), reason: 'cancel $s');
        expect(a.canConfirm, s == 'AWAITING_CUSTOMER_CONFIRMATION', reason: 'confirm $s');
        expect(a.canDispute, s == 'AWAITING_CUSTOMER_CONFIRMATION', reason: 'dispute $s');
        expect(a.canPay, s == 'AWAITING_PAYMENT', reason: 'pay $s');
        expect(a.awaitingCashConfirm, s == 'AWAITING_CASH_CONFIRM', reason: 'cash $s');
      }
    });

    test('model: modifiers', () {
      expect(BookingActions.of(_booking('CONFIRMED', checkedIn: true)).canCancel, isFalse);
      expect(BookingActions.of(_booking('AWAITING_PAYMENT', method: 'cash')).canPay, isFalse);
      expect(BookingActions.of(_booking('AWAITING_PAYMENT', method: 'vnpay', payment: 'paid')).canPay, isFalse);
      expect(BookingActions.of(_booking('AWAITING_PAYMENT', method: 'vnpay', payment: 'failed')).canPay, isTrue);
      final waiting = BookingActions.of(_booking('AWAITING_CUSTOMER_CONFIRMATION',
          disputedAt: '2026-01-02T00:00:00Z'));
      expect((waiting.canConfirm, waiting.canDispute, waiting.disputeWaiting), (true, false, true));
      final resubmitted = BookingActions.of(_booking('AWAITING_CUSTOMER_CONFIRMATION',
          disputedAt: '2026-01-02T00:00:00Z', resubmittedAt: '2026-01-03T00:00:00Z'));
      expect((resubmitted.canDispute, resubmitted.disputeWaiting), (true, false));
    });

    for (final s in kBookingStatuses) {
      testWidgets('detail shows only the right buttons: $s', (t) async {
        final h = _Harness(detail: _booking(s, method: 'momo'));
        await h.pump(t);
        expect(_key('booking-cancel-cta'), cancellable.contains(s) ? findsOneWidget : findsNothing);
        expect(_key('booking-confirm-cta'), s == 'AWAITING_CUSTOMER_CONFIRMATION' ? findsOneWidget : findsNothing);
        expect(_key('booking-dispute-cta'), s == 'AWAITING_CUSTOMER_CONFIRMATION' ? findsOneWidget : findsNothing);
        expect(_key('pay-cta'), s == 'AWAITING_PAYMENT' ? findsOneWidget : findsNothing);
      });
    }

    testWidgets('no cancel button once the tasker has checked in; none for a cash AWAITING_PAYMENT pay', (t) async {
      final h = _Harness(detail: _booking('CONFIRMED', checkedIn: true));
      await h.pump(t);
      expect(_key('booking-cancel-cta'), findsNothing);
      final h2 = _Harness(detail: _booking('AWAITING_PAYMENT', method: 'cash'));
      await h2.pump(t);
      expect(_key('pay-cta'), findsNothing);
    });
  });

  // ── new backend fields: present AND absent ─────────────────────────────────
  group('server actions / cancelPreview / quote', () {
    test('actions absent -> status table; present -> server flags win', () {
      final absent = BookingActions.of(_booking('CONFIRMED'));
      expect(absent.canCancel, isTrue);
      // server says no (e.g. 24h lock) even though the status would allow it
      expect(BookingActions.of(_booking('CONFIRMED', actions: {'canCancel': false})).canCancel, isFalse);
      // server says yes where the table says no
      final yes = BookingActions.of(_booking('SETTLED', actions: {'canCancel': true, 'canPay': true}));
      expect((yes.canCancel, yes.canPay), (true, true));
      // partial actions: missing keys fall back to the table
      final partial = BookingActions.of(_booking('AWAITING_CUSTOMER_CONFIRMATION', actions: {'canPay': false}));
      expect((partial.canConfirm, partial.canDispute, partial.canPay), (true, true, false));
      // garbage / empty -> ignored
      expect(BookingActions.of(_booking('CONFIRMED', actions: {'canCancel': 'yes'})).canCancel, isTrue);
    });

    testWidgets('actions drive the buttons', (t) async {
      final h = _Harness(detail: _booking('CONFIRMED', actions: {'canCancel': false}));
      await h.pump(t);
      expect(_key('booking-cancel-cta'), findsNothing);
    });

    test('cancelPreview parsing', () {
      expect(CancelPreview.tryParse(null), isNull);
      expect(CancelPreview.tryParse({}), isNull);
      final p = CancelPreview.tryParse({'feeVnd': 30000, 'refundVnd': 0, 'reason': ' Sau gio hen '})!;
      expect((p.feeVnd, p.refundVnd, p.reason), (30000, 0, 'Sau gio hen'));
    });

    test('cancelPreview.reason: object {code,label} or string', () {
      final o = CancelPreview.tryParse({
        'feeVnd': 0,
        'refundVnd': 480000,
        'reason': {'code': 'FREE_WINDOW', 'label': ' Huy mien phi '}
      })!;
      expect((o.reason, o.reasonCode), ('Huy mien phi', 'FREE_WINDOW'));
      final noLabel = CancelPreview.tryParse({'feeVnd': 1, 'reason': {'code': 'AFTER_START_NO_REFUND'}})!;
      expect((noLabel.reason, noLabel.reasonCode), (null, 'AFTER_START_NO_REFUND'));
      expect(CancelPreview.tryParse({'feeVnd': 1, 'reason': 7})!.reason, isNull);
    });

    test('cancelReasons parsing: present, absent, malformed', () {
      expect(_booking('CONFIRMED').cancelReasons, isEmpty);
      final r = _booking('CONFIRMED', cancelReasons: [
        {'code': 'wrong_time', 'label': 'Sai gio'},
        {'code': 'other', 'label': 'Khac'},
        {'code': 'other', 'label': 'Dup'},
        {'code': 'x'},
        {'label': 'no code'},
      ]).cancelReasons;
      expect([for (final o in r) (o.code, o.label)], [('wrong_time', 'Sai gio'), ('other', 'Khac')]);
      expect(CancelReasonOption.parseList('nope'), isEmpty);
    });

    testWidgets('dialog shows the preview reason label from an object', (t) async {
      final h = _Harness(detail: _booking('CONFIRMED', cancelPreview: {
        'feeVnd': 0,
        'refundVnd': 480000,
        'reason': {'code': 'FREE_WINDOW', 'label': 'Huy mien phi'}
      }));
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      expect(t.widget<Text>(_key('cancel-preview-reason')).data, 'Huy mien phi');
      expect(find.text('FREE_WINDOW'), findsNothing);
    });

    testWidgets('dialog renders server reasons (server labels) when present', (t) async {
      final h = _Harness(detail: _booking('CONFIRMED', cancelReasons: [
        {'code': 'wrong_time', 'label': 'Nhan nham gio'},
        {'code': 'other', 'label': 'Ly do server'},
      ]));
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      await t.tap(_key('cancel-reason'));
      await _settle(t);
      expect(find.text('Nhan nham gio'), findsWidgets);
      expect(find.text('Ly do server'), findsWidgets);
      expect(find.text(_vi.moneyCancelReasonPlanChanged), findsNothing);
      await t.tap(find.text('Nhan nham gio').last);
      await _settle(t);
      await t.tap(_key('cancel-submit'));
      await _settle(t);
      expect(h.api.cancels.single.code, 'wrong_time');
    });

    testWidgets('dialog falls back to the localized customer list when absent', (t) async {
      final h = _Harness();
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      await t.tap(_key('cancel-reason'));
      await _settle(t);
      for (final label in [
        _vi.moneyCancelReasonPlanChanged,
        _vi.moneyCancelReasonWrongTime,
        _vi.moneyCancelReasonPrice,
        _vi.moneyCancelReasonFoundOther,
        _vi.moneyCancelReasonOther,
      ]) {
        expect(find.text(label), findsWidgets);
      }
      for (final code in kCancelReasonCodes) {
        expect(find.text(code), findsNothing, reason: 'raw code shown');
      }
    });

    test('refundStatus labels are localized; unknown -> none shown', () {
      expect(refundStatusLabel(_vi, 'none'), _vi.moneyRefundStatusNone);
      expect(refundStatusLabel(_vi, 'succeeded'), _vi.moneyRefundStatusSucceeded);
      expect(refundStatusLabel(_vi, 'pending'), _vi.moneyRefundStatusPending);
      expect(refundStatusLabel(_vi, 'manual'), _vi.moneyRefundStatusManual);
      expect(refundStatusLabel(_vi, 'weird'), isNull);
      expect(refundStatusLabel(_vi, null), isNull);
      final txt = cancelDoneText(_vi, const CancelResult(refundVnd: 5000, refundStatus: 'pending'));
      expect(txt, contains(_vi.moneyRefundStatusPending));
      expect(txt, isNot(contains('pending')));
      expect(cancelDoneText(_vi, const CancelResult(refundStatus: 'weird')), _vi.moneyCancelDone);
    });

    test('tasker cancel codes are the server enum; note cap 500', () {
      expect(kJobCancelReasonCodes, ['sick', 'address_unreach', 'wrong_scope', 'safety', 'other']);
      expect(kJobCancelNoteMax, 500);
    });

    testWidgets('tasker cancel picker: localized codes, optional text, pops (code, text)', (t) async {
      ({String code, String text})? out;
      await t.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async =>
                out = await showDialog<({String code, String text})>(context: c, builder: (_) => const JobCancelDialog()),
            child: const Text('open'),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await _settle(t);
      expect(t.widget<FilledButton>(_key('job-cancel-submit')).onPressed, isNull);
      await t.tap(_key('job-cancel-reason'));
      await _settle(t);
      for (final label in [
        _vi.moneyCancelReasonSick,
        _vi.moneyCancelReasonAddressUnreach,
        _vi.moneyCancelReasonWrongScope,
        _vi.moneyCancelReasonSafety,
        _vi.moneyCancelReasonOther,
      ]) {
        expect(find.text(label), findsWidgets);
      }
      for (final code in kJobCancelReasonCodes) {
        expect(find.text(code), findsNothing);
      }
      await t.tap(find.text(_vi.moneyCancelReasonSick).last);
      await _settle(t);
      await t.enterText(_key('job-cancel-note'), '  om  ');
      await t.tap(_key('job-cancel-submit'));
      await _settle(t);
      expect(out, (code: 'sick', text: 'om'));
    });

    testWidgets('cancel dialog WITHOUT preview: policy only, no numbers', (t) async {
      final h = _Harness();
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      expect(_key('cancel-preview-fee'), findsNothing);
      expect(_key('cancel-preview-refund'), findsNothing);
    });

    testWidgets('cancel dialog WITH preview: server fee, refund (>0) and reason, verbatim', (t) async {
      final h = _Harness(
          detail: _booking('CONFIRMED',
              cancelPreview: {'feeVnd': 30000, 'refundVnd': 480000, 'reason': 'Huy truoc gio hen'}));
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      expect(find.text('Huy truoc gio hen'), findsOneWidget);
      expect(t.widget<Text>(_key('cancel-preview-fee')).data, _vi.moneyCancelFeeLine('30.000₫'));
      expect(t.widget<Text>(_key('cancel-preview-refund')).data, _vi.moneyCancelRefundLine('480.000₫'));
    });

    testWidgets('preview with refund 0 hides the refund line', (t) async {
      final h = _Harness(detail: _booking('CONFIRMED', cancelPreview: {'feeVnd': 30000, 'refundVnd': 0}));
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      expect(_key('cancel-preview-fee'), findsOneWidget);
      expect(_key('cancel-preview-refund'), findsNothing);
    });

    test('cancel result: fee / refund shown when present, plain text when absent', () {
      expect(cancelDoneText(_vi, const CancelResult()), _vi.moneyCancelDone);
      final txt = cancelDoneText(_vi, const CancelResult(feeVnd: 30000, refundVnd: 0, refundStatus: 'none'));
      expect(txt, contains('30.000₫'));
      expect(txt, isNot(contains(_vi.moneyCancelRefundLine('0₫'))));
      expect(cancelDoneText(_vi, const CancelResult(refundVnd: 5000)), contains('5.000₫'));
      expect(CancelResult.fromJson({'intent': 'confirm', 'bookingId': 1}).feeVnd, isNull);
      expect(CancelResult.fromJson(null).refundVnd, isNull);
    });

    test('cancel reason codes are the server enum; note cap 500', () {
      expect(kCancelReasonCodes,
          ['plan_changed', 'wrong_time', 'price', 'found_other', 'other']);
      expect(kCancelNoteMax, 500);
    });

    test('quoteBooking: POST /bookings/quote, create body WITHOUT idempotency key, no header', () async {
      final a = _Adapter({'totalVnd': 510000, 'breakdown': {'surchargesVnd': 20000}});
      final draft = BookingDraft(
          serviceId: 3, serviceName: 'x', basePriceVnd: 480000, scheduledDate: '2026-02-01',
          scheduledTime: '09:00', wardName: 'Ben Nghe', addressLine: '1 A');
      final q = await _realApi(a).quoteBooking(draft);
      final r = a.requests.single;
      expect((r.method, r.path), ('POST', '/bookings/quote'));
      expect(r.headers.containsKey('Idempotency-Key'), isFalse);
      expect((r.data as Map).containsKey('idempotencyKey'), isFalse);
      expect(jsonEncode(r.data).toLowerCase(), isNot(matches(r'amount|total|price')));
      expect(q!.totalVnd, 510000);
      expect(q.breakdown!.surchargesVnd, 20000);
    });

    test('quote parsing tolerates a missing total (-> null)', () {
      expect(BookingQuote.tryParse({'x': 1}), isNull);
      expect(BookingQuote.tryParse({'totalVnd': 1000})!.breakdown, isNull);
    });

    test('new initiate error codes get friendly copy', () {
      expect(apiErrorText(_vi, _err('PAYMENT_NOT_ALLOWED_IN_STATUS', 409, message: 'raw')),
          _vi.moneyErrPaymentNotAllowed);
      expect(apiErrorText(_vi, _err('PAYMENT_GATEWAY_UNAVAILABLE', 502, message: 'raw')),
          _vi.moneyErrGatewayUnavailable);
    });
  });

  // ── server itemisation ─────────────────────────────────────────────────────
  group('breakdown display', () {
    test('parses the server breakdown verbatim (map or JSON string); no sums', () {
      final m = {
        'surchargesVnd': 20000,
        'surchargeReasons': ['peak'],
        'cancelCompensations': [
          {'kind': 'cancel_compensation', 'label': 'Phi den bu don #3', 'amountVnd': 30000, 'refBookingId': 3}
        ],
        'compensationVnd': 30000,
        'totalVnd': 999999,
      };
      for (final raw in [m, jsonEncode(m)]) {
        final v = PriceBreakdownView.tryParse(raw)!;
        expect(v.surchargesVnd, 20000);
        expect(v.compensations.single.label, 'Phi den bu don #3');
        expect(v.compensations.single.amountVnd, 30000);
        expect(v.surchargeReasons, ['peak']);
      }
      expect(PriceBreakdownView.tryParse(null), isNull);
      expect(PriceBreakdownView.tryParse('not json'), isNull);
      expect(PriceBreakdownView.tryParse({'surchargesVnd': 0}), isNull);
    });

    testWidgets('detail renders the server total and each server line', (t) async {
      final h = _Harness(detail: _booking('CONFIRMED', breakdown: {
        'cancelCompensations': [
          {'label': 'Phi den bu don #3', 'amountVnd': 30000}
        ],
      }));
      await h.pump(t);
      expect(find.textContaining('510.000'), findsOneWidget); // server totalVnd
      expect(_key('booking-breakdown'), findsOneWidget);
      expect(find.text('Phi den bu don #3'), findsOneWidget);
      expect(find.textContaining('30.000'), findsOneWidget);
    });
  });

  // ── cancel ─────────────────────────────────────────────────────────────────
  group('cancel', () {
    testWidgets('dialog states the policy in words and shows no amount', (t) async {
      final h = _Harness();
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      final policy = t.widget<Text>(_key('cancel-policy')).data!;
      expect(policy, _vi.moneyCancelPolicy);
      expect(policy, isNot(matches(r'\d')));
      // submit needs a reason first
      expect(t.widget<FilledButton>(_key('cancel-submit')).onPressed, isNull);
    });

    testWidgets('sends the chosen reason through the ledger; refreshes; double tap = one call', (t) async {
      final h = _Harness();
      h.api.cancelGate = Completer<void>();
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      await t.tap(_key('cancel-reason'));
      await _settle(t);
      await t.tap(find.text(_vi.moneyCancelReasonPlanChanged).last);
      await _settle(t);
      await t.tap(_key('cancel-submit'));
      await t.pump();
      expect(t.widget<FilledButton>(_key('cancel-submit')).onPressed, isNull); // in flight
      await t.tap(_key('cancel-submit'), warnIfMissed: false);
      await t.pump();
      expect(h.api.cancels, hasLength(1));
      h.current = _booking('CANCELLED');
      h.api.cancelGate!.complete();
      await _settle(t);
      expect(h.api.cancels.single.code, 'plan_changed');
      expect(_key('cancel-submit'), findsNothing); // dialog closed
      expect(_key('booking-cancel-cta'), findsNothing); // booking refreshed -> CANCELLED
      // success forgets the key: a later cancel is a new action with a new key
      final fp = 'booking-cancel:5:plan_changed.${IdempotencyLedger.textTag('')}';
      expect(await h.ledger.keyFor(fp), isNot(h.api.cancels.single.key));
    });

    testWidgets('fingerprint booking-cancel:<id>:<reason tag>; 5xx keeps the key', (t) async {
      final h = _Harness();
      h.api.cancelFailure = _err('INTERNAL', 500);
      await h.pump(t);
      await _tapScroll(t, _key('booking-cancel-cta'));
      await _settle(t);
      await t.tap(_key('cancel-reason'));
      await _settle(t);
      await t.tap(find.text(_vi.moneyCancelReasonOther).last);
      await _settle(t);
      await t.enterText(_key('cancel-note'), 'xin loi');
      await t.tap(_key('cancel-submit'));
      await _settle(t);
      expect(find.text(_vi.cust2ErrServer), findsOneWidget);
      final sent = h.api.cancels.single;
      expect(sent.text, 'xin loi');
      expect(await h.ledger.keyFor('booking-cancel:5:other.${IdempotencyLedger.textTag('xin loi')}'), sent.key);
      // retry reuses the same key
      await t.tap(_key('cancel-submit'));
      await _settle(t);
      expect(h.api.cancels.last.key, sent.key);
    });

    test('error copy: daily cap, 24h lock, wrong status', () {
      final cap = _err('CANCEL_RATE_LIMIT_EXCEEDED', 429, fields: {'cancelled_today': '3', 'max_per_day': '3'});
      expect(apiErrorText(_vi, cap), _vi.moneyErrCancelRateLimit);
      expect(apiErrorText(_vi, cap), isNot(_vi.cust2ErrRateLimit));
      expect(apiErrorText(_vi, _err('RATE_LIMIT', 429)), _vi.cust2ErrRateLimit);
      final lock = _err('CONFLICT', 409, message: 'Vui long cho 24h truoc khi huy tiep.');
      expect(apiErrorText(_vi, lock), 'Vui long cho 24h truoc khi huy tiep.');
      expect(apiErrorText(_vi, _err('CONFLICT', 409, message: 'Request failed')), _vi.cust2ErrConflict);
      expect(apiErrorText(_vi, _err('VALIDATION', 422)), _vi.cust2ErrValidation);
      expect(apiErrorText(_vi, _err('IDEMPOTENCY_STALE', 409)), _vi.moneyErrCheckTransaction);
    });
  });

  // ── confirm completion / dispute ───────────────────────────────────────────
  group('confirm completion', () {
    testWidgets('confirm sends {confirm, method} with fingerprint booking-confirm:<id>:confirm:<method>', (t) async {
      final h = _Harness(detail: _booking('AWAITING_CUSTOMER_CONFIRMATION'));
      h.api.confirmFailure = _err('INTERNAL', 500);
      await h.pump(t);
      expect(find.text(_vi.moneyConfirmAction), findsOneWidget);
      await _tapScroll(t, _key('booking-confirm-cta'));
      await _settle(t);
      await t.tap(_key('confirm-method-momo'));
      await _settle(t);
      await t.tap(_key('confirm-submit'));
      await _settle(t);
      final sent = h.api.confirms.single;
      expect((sent.action, sent.method, sent.note), ('confirm', 'momo', null));
      expect(await h.ledger.keyFor('booking-confirm:5:confirm:momo'), sent.key);
    });

    testWidgets('after confirming with a gateway method the Pay action appears', (t) async {
      final h = _Harness(detail: _booking('AWAITING_CUSTOMER_CONFIRMATION'));
      await h.pump(t);
      await _tapScroll(t, _key('booking-confirm-cta'));
      await _settle(t);
      await t.tap(_key('confirm-method-vnpay'));
      await t.tap(_key('confirm-submit'));
      h.current = _booking('AWAITING_PAYMENT', method: 'vnpay');
      await _settle(t);
      expect(_key('pay-cta'), findsOneWidget);
      expect(_key('booking-confirm-cta'), findsNothing);
    });

    testWidgets('dispute: note must be 10..2000 chars (trimmed) before anything is sent', (t) async {
      final h = _Harness(detail: _booking('AWAITING_CUSTOMER_CONFIRMATION'));
      await h.pump(t);
      await _tapScroll(t, _key('booking-dispute-cta'));
      await _settle(t);
      await t.enterText(_key('dispute-note'), '   short   ');
      await t.tap(_key('dispute-submit'));
      await _settle(t);
      expect(find.text(_vi.moneyDisputeTooShort(10)), findsOneWidget);
      expect(h.api.confirms, isEmpty);
      await t.enterText(_key('dispute-note'), 'x' * 2001);
      await t.pump();
      expect(find.text(_vi.moneyDisputeTooLong(2000)), findsOneWidget);
      await t.enterText(_key('dispute-note'), '  Nha van con ban sau khi don  ');
      await t.tap(_key('dispute-submit'));
      await _settle(t);
      final sent = h.api.confirms.single;
      expect((sent.action, sent.method, sent.note), ('dispute', null, 'Nha van con ban sau khi don'));
      expect(sent.key, isNotEmpty);
    });

    test('validateDisputeNote boundaries', () {
      expect(validateDisputeNote(_vi, 'a' * 9), isNotNull);
      expect(validateDisputeNote(_vi, 'a' * 10), isNull);
      expect(validateDisputeNote(_vi, ' ${'a' * 9} '), isNotNull); // trimmed
      expect(validateDisputeNote(_vi, 'a' * 2000), isNull);
      expect(validateDisputeNote(_vi, 'a' * 2001), isNotNull);
    });

    testWidgets('dispute is disabled while waiting for the tasker', (t) async {
      final h = _Harness(detail: _booking('AWAITING_CUSTOMER_CONFIRMATION', disputedAt: '2026-01-02T00:00:00Z'));
      await h.pump(t);
      expect(t.widget<OutlinedButton>(_key('booking-dispute-cta')).onPressed, isNull);
      expect(find.text(_vi.moneyDisputeWaiting), findsOneWidget);
      expect(t.widget<FilledButton>(_key('booking-confirm-cta')).onPressed, isNotNull);
    });
  });

  // ── pay ────────────────────────────────────────────────────────────────────
  group('pay', () {
    PaymentStatusResult st(String s, {bool paid = false, bool failed = false}) =>
        PaymentStatusResult(status: s, paid: paid, failed: failed);

    testWidgets('initiate (ledger pay-initiate:<id>) opens an external URL; resume polls; only the server says paid',
        (t) async {
      final h = _Harness(detail: _booking('AWAITING_PAYMENT', method: 'momo'));
      h.api.statusScript = [st('pending'), st('pending'), st('paid', paid: true)];
      await h.pump(t);
      await _tapScroll(t, _key('pay-cta'));
      await _settle(t);
      expect(h.launched.single.toString(), 'https://test-payment.momo.vn/x');
      expect(h.api.initiates.single.id, 5);
      expect(find.text(_vi.moneyPayConfirming), findsOneWidget);
      expect(h.api.statusReads, 0); // browser return is not evidence: nothing polled yet
      expect(find.text(_vi.moneyPayPaid), findsNothing);

      // success forgot the key
      expect(await h.ledger.keyFor('pay-initiate:5'), isNot(h.api.initiates.single.key));

      // back from the browser
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      h.current = _booking('SETTLED', method: 'momo', payment: 'paid');
      await _settle(t);
      expect(h.api.statusReads, 3);
      expect(find.text(_vi.moneyPayPaid), findsOneWidget);
    });

    testWidgets('state survives a rebuild of the screen', (t) async {
      final h = _Harness(detail: _booking('AWAITING_PAYMENT', method: 'vnpay'));
      h.api.statusScript = [st('pending')];
      await h.pump(t);
      await _tapScroll(t, _key('pay-cta'));
      await _settle(t);
      expect(find.text(_vi.moneyPayConfirming), findsOneWidget);
      h.show.value = false; // unmount the whole detail screen...
      await _settle(t);
      expect(find.text(_vi.moneyPayConfirming), findsNothing);
      h.show.value = true; // ...and rebuild it under the SAME app scope
      await _settle(t);
      expect(find.text(_vi.moneyPayConfirming), findsOneWidget);
    });

    testWidgets('"I have paid" polls; timeout never shows paid and offers a re-check', (t) async {
      final h = _Harness(detail: _booking('AWAITING_PAYMENT', method: 'momo'));
      h.api.statusScript = [st('pending')];
      await h.pump(t);
      await _tapScroll(t, _key('pay-cta'));
      await _settle(t);
      await _tapScroll(t, _key('pay-i-paid'));
      await _settle(t);
      expect(h.api.statusReads, kPaymentPollDelays.length + 1);
      expect(find.text(_vi.moneyPayTimeout), findsOneWidget);
      expect(find.text(_vi.moneyPayPaid), findsNothing);
      expect(_key('pay-i-paid'), findsOneWidget);
    });

    testWidgets('server failed -> failure copy and a retry', (t) async {
      final h = _Harness(detail: _booking('AWAITING_PAYMENT', method: 'momo'));
      h.api.statusScript = [st('failed', failed: true)];
      await h.pump(t);
      await _tapScroll(t, _key('pay-cta'));
      await _settle(t);
      await _tapScroll(t, _key('pay-i-paid'));
      await _settle(t);
      expect(find.text(_vi.moneyPayFailed), findsOneWidget);
      expect(_key('pay-cta'), findsOneWidget);
    });

    testWidgets('initiate 500 -> apiErrorText + retry reuses the SAME key (ledger keeps it on 5xx)', (t) async {
      final h = _Harness(detail: _booking('AWAITING_PAYMENT', method: 'momo'));
      h.api.initiateFailure = _err('INTERNAL', 500);
      await h.pump(t);
      await _tapScroll(t, _key('pay-cta'));
      await _settle(t);
      expect(find.text(_vi.cust2ErrServer), findsOneWidget);
      final k = h.api.initiates.single.key;
      expect(await h.ledger.keyFor('pay-initiate:5'), k);
      h.api.initiateFailure = null;
      await _tapScroll(t, _key('pay-retry'));
      await _settle(t);
      expect(h.api.initiates.last.key, k);
      expect(h.launched, hasLength(1));
    });

    testWidgets('initiate kinds cash / already_paid / no_rail get their own copy and open nothing', (t) async {
      for (final (kind, text) in [
        ('cash', _vi.moneyPayCash),
        ('already_paid', _vi.moneyPayAlready),
        ('no_rail', _vi.moneyPayNoRail),
      ]) {
        final h = _Harness(detail: _booking('AWAITING_PAYMENT', method: 'momo'));
        h.api.initiateResult = PaymentInitiateResult(kind: kind, bookingId: 5);
        await h.pump(t);
        await _tapScroll(t, _key('pay-cta'));
        await _settle(t);
        expect(find.text(text), findsOneWidget, reason: kind);
        expect(h.launched, isEmpty);
      }
    });

    testWidgets('pay button is disabled with a spinner while initiate is in flight', (t) async {
      final h = _Harness(detail: _booking('AWAITING_PAYMENT', method: 'momo'));
      final gate = Completer<void>();
      final api = _GatedPayApi(gate);
      final h2 = _Harness(detail: h.current, api: api);
      await h2.pump(t);
      await _tapScroll(t, _key('pay-cta'));
      expect(t.widget<FilledButton>(_key('pay-cta')).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      await t.tap(_key('pay-cta'), warnIfMissed: false);
      gate.complete();
      await _settle(t);
      expect(api.initiates, hasLength(1));
    });

    test('only https pay URLs and non-code-running deeplinks are opened', () {
      expect(PayFlowController.isOpenablePayUrl('https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?x=1'), isTrue);
      expect(PayFlowController.isOpenablePayUrl('https://test-payment.momo.vn/v2/gateway/pay?t=1'), isTrue);
      expect(PayFlowController.isOpenablePayUrl('https://pay.example/x'), isFalse); // untrusted host → phishing guard
      expect(PayFlowController.isOpenablePayUrl('https://momo.vn.evil.com/x'), isFalse);
      expect(PayFlowController.isOpenablePayUrl('http://pay.example/x'), isFalse);
      expect(PayFlowController.isOpenablePayUrl('javascript:alert(1)'), isFalse);
      expect(PayFlowController.isOpenablePayUrl(null), isFalse);
      expect(PayFlowController.isOpenableDeeplink('momo://app?x=1'), isTrue);
      expect(PayFlowController.isOpenableDeeplink('javascript:alert(1)'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('file:///etc/passwd'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('intent://x#Intent;end'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('https://evil.example/momo'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('weirdapp://pay'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('https://payment.momo.vn/x'), isTrue);
    });
  });

  // ── ledger fingerprints are per action ─────────────────────────────────────
  group('ledger', () {
    test('different action/target/reason -> different keys; the same one reuses its key', () async {
      final l = IdempotencyLedger(store: MemoryPendingKeyStore());
      final cancelA = await l.keyFor('booking-cancel:5:other.${IdempotencyLedger.textTag('a')}');
      final cancelB = await l.keyFor('booking-cancel:5:other.${IdempotencyLedger.textTag('b')}');
      final conf = await l.keyFor('booking-confirm:5:confirm:cash');
      final conf2 = await l.keyFor('booking-confirm:5:confirm:momo');
      final disp = await l.keyFor('booking-confirm:5:dispute:${IdempotencyLedger.textTag('x')}');
      final pay5 = await l.keyFor('pay-initiate:5');
      final pay6 = await l.keyFor('pay-initiate:6');
      expect({cancelA, cancelB, conf, conf2, disp, pay5, pay6}, hasLength(7));
      expect(await l.keyFor('pay-initiate:5'), pay5);
    });
  });

  // ── withdraw copy (UX-M22): drive the real flow ────────────────────────────
  group('runWithdrawFlow messages', () {
    Future<String?> run(WidgetTester t, {Object? stepUpFailure, Object? payoutFailure}) async {
      final api = _realApi2(_WithdrawAdapter(stepUpFailure as ApiException?, payoutFailure as ApiException?));
      String? msg;
      await t.pumpWidget(ProviderScope(
        overrides: [
          kycoApiProvider.overrideWithValue(api),
          idempotencyLedgerProvider.overrideWithValue(IdempotencyLedger(store: MemoryPendingKeyStore())),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (ctx, ref, _) => TextButton(
              onPressed: () async => msg = await runWithdrawFlow(ctx, ref, balanceVnd: 500000),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('go'));
      await _settle(t);
      await t.tap(find.text(_vi.provWalletContinue));
      await _settle(t);
      return msg;
    }

    testWidgets('422 with fields.amount_vnd -> friendly localized copy, never the raw field', (t) async {
      final m = await run(t,
          payoutFailure: _err('VALIDATION', 422,
              message: 'Insufficient balance', fields: {'amount_vnd': 'insufficient_balance 12345'}));
      expect(m, _vi.provWalletWithdrawInvalidAmount);
    });

    testWidgets('network / 5xx / plain 403 / stale key -> localized copy, never e.message', (t) async {
      expect(await run(t, payoutFailure: _err('network', 0, message: 'DioException [connection error]')),
          _vi.cust2ErrNetwork);
      expect(await run(t, payoutFailure: _err('INTERNAL', 500, message: 'boom')), _vi.cust2ErrServer);
      expect(await run(t, payoutFailure: _err('FORBIDDEN', 403, message: 'Forbidden raw')), _vi.cust2ErrForbidden);
      expect(await run(t, payoutFailure: _err('IDEMPOTENCY_STALE', 409, message: 'raw stale')),
          _vi.moneyErrCheckTransaction);
    });

    testWidgets('existing mappings unchanged: 409 -> pending, STEP_UP_REQUIRED -> step-up, 503 -> maintenance',
        (t) async {
      expect(await run(t, payoutFailure: _err('CONFLICT', 409)), _vi.provWalletWithdrawPending);
      expect(await run(t, payoutFailure: _err('STEP_UP_REQUIRED', 403)), _vi.provWalletWithdrawStepUp);
      expect(await run(t, payoutFailure: _err('MAINTENANCE', 503)), _vi.provWalletMaintenance);
    });

    testWidgets('step-up status failure -> localized copy', (t) async {
      expect(await run(t, stepUpFailure: _err('network', 0, message: 'DioException x')), _vi.cust2ErrNetwork);
    });
  });

  // ── withdraw copy (UX-M22) ─────────────────────────────────────────────────
  group('withdraw error copy', () {
    test('no raw server text / field value reaches the user', () {
      final raw = _err('VALIDATION', 422,
          message: 'Insufficient balance: 12345', fields: {'amount_vnd': 'insufficient_balance'});
      // the sheet maps a 422 with fields.amount_vnd to the friendly string
      expect(_vi.provWalletWithdrawInvalidAmount, isNot(contains('insufficient')));
      expect(apiErrorText(_vi, _err('network', 0, message: 'DioException [connection error]')), _vi.cust2ErrNetwork);
      expect(apiErrorText(_vi, _err('INTERNAL', 500, message: 'boom')), _vi.cust2ErrServer);
      expect(apiErrorText(_vi, _err('FORBIDDEN', 403, message: 'Forbidden')), _vi.cust2ErrForbidden);
      expect(apiErrorText(_vi, raw), _vi.cust2ErrValidation);
    });
  });
}

class _GatedPayApi extends _FakeApi {
  _GatedPayApi(this.gate);
  final Completer<void> gate;
  @override
  Future<PaymentInitiateResult> initiatePayment(int bookingId, {required String idempotencyKey}) async {
    initiates.add((id: bookingId, key: idempotencyKey));
    await gate.future;
    return initiateResult;
  }
}

/// HTTP-level script for the withdraw flow (tasker routes are extension
/// methods, so they are faked at the adapter, not by overriding).
class _WithdrawAdapter implements HttpClientAdapter {
  _WithdrawAdapter(this.stepUp, this.payout);
  final ApiException? stepUp;
  final ApiException? payout;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final ApiException? e = o.path.endsWith('/auth/step-up') ? stepUp : payout;
    if (e != null && e.isNetwork) {
      throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
    }
    final body = e == null
        ? {'ok': true, 'data': {'fresh': true, 'hasUsablePassword': true}}
        : {'ok': false, 'code': e.code, 'message': e.message, if (e.fields != null) 'fields': e.fields};
    return ResponseBody.fromString(jsonEncode(body), e?.status ?? 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}
