// ZaloPay rail on mobile: URL allow-list (M-1), server method list + labels +
// sandbox badge (M-2), expiry countdown / fresh key / error copy (M-3).
// No live calls; the app never sends or computes an amount.
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
import 'package:kyco_mobile/features/auth/auth_controller.dart' show authUserIdProvider;
import 'package:kyco_mobile/features/bookings/booking_detail_screen.dart';
import 'package:kyco_mobile/features/bookings/payment_flow.dart';
import 'package:kyco_mobile/features/home/home_providers.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore;

final _vi = lookupAppLocalizations(const Locale('vi'));
final _en = lookupAppLocalizations(const Locale('en'));

class _Api extends KycoApi {
  _Api() : super(KycoApiClient(tokens: InMemoryTokenStore()), InMemoryTokenStore());
  final initiates = <String>[];
  Object? initiateFailure;
  Object? methodsFailure;
  PaymentMethodsInfo methods = PaymentMethodsInfo.fallback;
  PaymentInitiateResult result = const PaymentInitiateResult(
      kind: 'ok', bookingId: 5, method: 'zalopay', payUrl: 'https://qcgateway.zalopay.vn/openinapp?order=abc');

  @override
  Future<PaymentMethodsInfo> paymentMethods() async {
    if (methodsFailure != null) throw methodsFailure!;
    return methods;
  }

  @override
  Future<PaymentInitiateResult> initiatePayment(int bookingId, {required String idempotencyKey}) async {
    initiates.add(idempotencyKey);
    if (initiateFailure != null) throw initiateFailure!;
    return result;
  }

  @override
  Future<PaymentStatusResult> paymentStatus(int bookingId) async =>
      const PaymentStatusResult(status: 'pending', paid: false, failed: false);
}

BookingDetail _booking(String status, String method, {Map<String, dynamic>? actions}) => BookingDetail.fromPage({
      'booking': {
        'id': 5,
        'status': status,
        'totalVnd': 510000,
        'paymentMethod': method,
        'scheduledAt': '2026-01-17T12:00:00Z',
      },
      'service': {'id': 1, 'name': 'Don dep'},
      'ctvHasCheckedIn': false,
      'actions': ?actions,
      'hasReview': false,
    });

class _H {
  _H(this.booking, {_Api? api}) : api = api ?? _Api() {
    ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), now: () => now, settleWindow: Duration.zero);
  }
  final _Api api;
  BookingDetail booking;
  late final IdempotencyLedger ledger;
  DateTime now = DateTime.utc(2026, 10, 14, 10);
  final launched = <Uri>[];
  int detailLoads = 0;
  Locale locale = const Locale('vi');

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        kycoApiProvider.overrideWithValue(api),
        idempotencyLedgerProvider.overrideWithValue(ledger),
        authUserIdProvider.overrideWithValue(7),
        payClockProvider.overrideWithValue(() => now),
        bookingDetailProvider.overrideWith((ref, id) {
          detailLoads++;
          return Future.value(booking);
        }),
        externalLauncherProvider.overrideWithValue((u) async {
          launched.add(u);
          return true;
        }),
        paymentPollSleepProvider.overrideWithValue((_) async {}),
      ],
      child: MaterialApp(
        theme: buildTheme(lightColorScheme),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BookingDetailScreen(id: 5),
      ),
    ));
    await _settle(t);
  }
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await _settle(t);
  await t.tap(f);
  await t.pump();
}

ApiException _err(String code, int status) => ApiException(code, 'x', status: status);

String _iso(DateTime d) => d.toUtc().toIso8601String();

void main() {
  group('isOpenablePayUrl / isOpenableDeeplink', () {
    test('accepts gateway hosts (zalopay, momo, vnpay)', () {
      for (final u in [
        'https://qcgateway.zalopay.vn/openinapp?order=abc',
        'https://sbgateway.zalopay.vn/openinapp?order=abc',
        'https://openapi.zalopay.vn/x',
        'https://sb-openapi.zalopay.vn/x',
        'https://zalopay.vn/x',
        'https://test-payment.momo.vn/x',
        'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html',
        'https://QCGATEWAY.ZaloPay.vn/x',
      ]) {
        expect(PayFlowController.isOpenablePayUrl(u), isTrue, reason: u);
      }
    });

    test('rejects look-alikes, wrong schemes, userinfo, ports, empty host', () {
      for (final u in [
        'http://qcgateway.zalopay.vn/x',
        'javascript:alert(1)',
        'data:text/html,<script>1</script>',
        'https://zalopay.vn.evil.com/x',
        'https://evilzalopay.vn/x',
        'https://zalopay.vn@evil.com/x',
        'https://evil.com@zalopay.vn/x',
        'https://user:pw@qcgateway.zalopay.vn/x',
        'https://qcgateway.zalopay.vn:8443/x',
        'https://zalopay.vn.evil.com:443@evil.com/',
        'https://zalopay.vn./x',
        'https:///x',
        'https://',
        'zalopay://pay?order=1',
        '',
      ]) {
        expect(PayFlowController.isOpenablePayUrl(u), isFalse, reason: u);
      }
      expect(PayFlowController.isOpenablePayUrl(null), isFalse);
    });

    test('deeplink: https zalopay/momo hosts and the momo scheme only', () {
      expect(PayFlowController.isOpenableDeeplink('https://qcgateway.zalopay.vn/openinapp?order=abc'), isTrue);
      expect(PayFlowController.isOpenableDeeplink('https://zalopay.vn/x'), isTrue);
      expect(PayFlowController.isOpenableDeeplink('momo://app?x=1'), isTrue);
      expect(PayFlowController.isOpenableDeeplink('zalopay://pay?order=1'), isFalse); // scheme unconfirmed
      expect(PayFlowController.isOpenableDeeplink('zalopayapp://x'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('http://qcgateway.zalopay.vn/x'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('https://zalopay.vn.evil.com/x'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('https://evilzalopay.vn/x'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('https://zalopay.vn@evil.com/x'), isFalse);
      expect(PayFlowController.isOpenableDeeplink('javascript:alert(1)'), isFalse);
      expect(PayFlowController.isOpenableDeeplink(null), isFalse);
    });
  });

  group('models', () {
    test('payment methods: with / without zalopay, with / without methodInfo', () {
      final a = PaymentMethodsInfo.fromJson({
        'methods': ['cash', 'momo', 'zalopay'],
        'methodInfo': [
          {'method': 'zalopay', 'label': 'ZaloPay', 'sandbox': true},
          {'method': 'momo', 'label': 'MoMo', 'sandbox': false},
        ],
      });
      expect(a.methods, ['cash', 'momo', 'zalopay']);
      expect(a.isSandbox('zalopay'), isTrue);
      expect(a.isSandbox('momo'), isFalse);
      final b = PaymentMethodsInfo.fromJson({'methods': ['momo', 'vnpay']});
      expect(b.methods, ['momo', 'vnpay']);
      expect(b.sandbox, isEmpty);
      expect(PaymentMethodsInfo.fromJson({}).methods, isEmpty);
      expect(PaymentMethodsInfo.fromJson({'methods': 'x', 'methodInfo': 3}).methods, isEmpty);
      expect(PaymentMethodsInfo.fallback.methods, isNot(contains('zalopay')));
    });

    test('initiate result: all fields, nulls, no sandbox', () {
      final full = PaymentInitiateResult.fromJson({
        'kind': 'ok',
        'bookingId': 5,
        'method': 'zalopay',
        'payUrl': 'https://qcgateway.zalopay.vn/openinapp?order=abc',
        'deeplink': 'https://qcgateway.zalopay.vn/x',
        'qrCodeUrl': '00020101021226',
        'providerTxId': 'tx1',
        'expiresAt': '2026-10-14T10:15:00.000Z',
        'sandbox': true,
      });
      expect(full.qrCodeUrl, '00020101021226');
      expect(full.sandbox, isTrue);
      expect(full.expiry, DateTime.utc(2026, 10, 14, 10, 15));
      final nulls = PaymentInitiateResult.fromJson({
        'kind': 'ok',
        'bookingId': 5,
        'deeplink': null,
        'qrCodeUrl': null,
        'expiresAt': null,
      });
      expect(nulls.qrCodeUrl, isNull);
      expect(nulls.expiry, isNull);
      expect(nulls.sandbox, isNull);
      final old = PaymentInitiateResult.fromJson({'kind': 'ok', 'bookingId': 5, 'payUrl': 'https://momo.vn/x'});
      expect(old.expiresAt, isNull);
      expect(old.sandbox, isNull);
    });
  });

  group('labels', () {
    test('pay button: zalopay, known rails, generic for unknown (never VNPay)', () {
      expect(payActionLabel(_vi, 'zalopay'), 'Thanh toán ZaloPay');
      expect(payActionLabel(_en, 'zalopay'), 'Pay with ZaloPay');
      expect(payActionLabel(_vi, 'momo'), _vi.moneyPayAction('MoMo'));
      expect(payActionLabel(_vi, 'something'), 'Thanh toán');
      expect(payActionLabel(_en, null), 'Pay');
      expect(payActionLabel(_en, 'something'), isNot(contains('VNPay')));
      expect(paymentMethodLabel(_vi, 'zalopay'), 'ZaloPay');
    });
  });

  group('confirm-completion method picker', () {
    Future<_H> open(WidgetTester t, {void Function(_Api)? setup}) async {
      final h = _H(_booking('AWAITING_CUSTOMER_CONFIRMATION', 'cash'));
      setup?.call(h.api);
      await h.pump(t);
      await _tap(t, _key('booking-confirm-cta'));
      await _settle(t);
      return h;
    }

    testWidgets('zalopay is shown only when the server lists it', (t) async {
      await open(t, setup: (a) => a.methods = const PaymentMethodsInfo(methods: ['cash', 'momo', 'zalopay']));
      expect(_key('confirm-method-zalopay'), findsOneWidget);
      expect(_key('confirm-method-cash'), findsOneWidget);
      expect(_key('confirm-method-vnpay'), findsNothing); // exactly the server list
      expect(find.text('ZaloPay'), findsOneWidget);
    });

    testWidgets('not listed -> no zalopay; cash only when listed', (t) async {
      await open(t, setup: (a) => a.methods = const PaymentMethodsInfo(methods: ['momo', 'vnpay']));
      expect(_key('confirm-method-zalopay'), findsNothing);
      expect(_key('confirm-method-cash'), findsNothing);
      expect(_key('confirm-method-momo'), findsOneWidget);
    });

    testWidgets('load error -> legacy list without zalopay', (t) async {
      await open(t, setup: (a) => a.methodsFailure = _err('INTERNAL', 500));
      expect(_key('confirm-method-zalopay'), findsNothing);
      for (final m in ['cash', 'momo', 'vnpay']) {
        expect(_key('confirm-method-$m'), findsOneWidget, reason: m);
      }
    });

    testWidgets('SANDBOX badge from methodInfo', (t) async {
      await open(t,
          setup: (a) => a.methods = const PaymentMethodsInfo(methods: ['cash', 'zalopay'], sandbox: {'zalopay'}));
      expect(_key('sandbox-badge'), findsOneWidget);
      expect(find.text('SANDBOX'), findsOneWidget);
    });
  });

  group('pay panel', () {
    testWidgets('zalopay pay button label (vi / en); no badge when the server says live', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      await h.pump(t);
      expect(find.descendant(of: _key('pay-cta'), matching: find.text('Thanh toán ZaloPay')), findsOneWidget);
      expect(_key('sandbox-badge'), findsNothing);
      final e = _H(_booking('AWAITING_PAYMENT', 'zalopay'))..locale = const Locale('en');
      await e.pump(t);
      expect(find.text('Pay with ZaloPay'), findsOneWidget);
    });

    testWidgets('unknown rail with canPay -> generic label', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'newpay', actions: {'canPay': true}));
      await h.pump(t);
      expect(find.descendant(of: _key('pay-cta'), matching: find.text('Thanh toán')), findsOneWidget);
    });

    testWidgets('SANDBOX badge from methodInfo and from the initiate result', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      h.api.methods = const PaymentMethodsInfo(methods: ['zalopay'], sandbox: {'zalopay'});
      await h.pump(t);
      expect(_key('sandbox-badge'), findsOneWidget);

      final h2 = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      h2.api.result = PaymentInitiateResult(
          kind: 'ok',
          bookingId: 5,
          payUrl: 'https://sbgateway.zalopay.vn/openinapp?order=a',
          sandbox: true,
          expiresAt: _iso(h2.now.add(const Duration(minutes: 15))));
      await h2.pump(t);
      expect(_key('sandbox-badge'), findsNothing);
      await _tap(t, _key('pay-cta'));
      await _settle(t);
      expect(_key('sandbox-badge'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('ZaloPay payUrl opens externally -> awaiting (browser return is not success)', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      await h.pump(t);
      await _tap(t, _key('pay-cta'));
      await _settle(t);
      expect(h.launched.single.host, 'qcgateway.zalopay.vn');
      expect(find.text(_vi.moneyPayConfirming), findsOneWidget);
      expect(find.text(_vi.moneyPayPaid), findsNothing);
    });

    testWidgets('evil payUrl and non-https zalopay deeplink: deeplink ignored, evil url refused', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      h.api.result = const PaymentInitiateResult(
          kind: 'ok', bookingId: 5, deeplink: 'zalopay://pay?x=1', payUrl: 'https://qcgateway.zalopay.vn/o?order=1');
      await h.pump(t);
      await _tap(t, _key('pay-cta'));
      await _settle(t);
      expect(h.launched.map((u) => u.scheme), ['https']); // fell back to payUrl
      final e = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      e.api.result = const PaymentInitiateResult(kind: 'ok', bookingId: 5, payUrl: 'https://zalopay.vn.evil.com/x');
      await e.pump(t);
      await _tap(t, _key('pay-cta'));
      await _settle(t);
      expect(e.launched, isEmpty);
      expect(find.text(_vi.moneyPayOpenFailed), findsOneWidget);
    });

    testWidgets('409 PAYMENT_NOT_ALLOWED_IN_STATUS -> calm copy and the booking page is refreshed', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      h.api.initiateFailure = _err('PAYMENT_NOT_ALLOWED_IN_STATUS', 409);
      await h.pump(t);
      final before = h.detailLoads;
      await _tap(t, _key('pay-cta'));
      await _settle(t);
      expect(find.text(_vi.moneyErrPaymentNotAllowed), findsOneWidget);
      expect(h.detailLoads, greaterThan(before));
    });

    testWidgets('502 PAYMENT_GATEWAY_UNAVAILABLE -> calm copy; retry reuses the same key', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      h.api.initiateFailure = _err('PAYMENT_GATEWAY_UNAVAILABLE', 502);
      await h.pump(t);
      await _tap(t, _key('pay-cta'));
      await _settle(t);
      expect(find.text(_vi.moneyErrGatewayUnavailable), findsOneWidget);
      h.api.initiateFailure = null;
      await _tap(t, _key('pay-retry'));
      await _settle(t);
      expect(h.api.initiates, hasLength(2));
      expect(h.api.initiates[1], h.api.initiates[0]);
    });

    testWidgets('countdown reaches 0 -> "Tạo lại thanh toán"; the next tap uses a new key', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      h.api.result = PaymentInitiateResult(
          kind: 'ok',
          bookingId: 5,
          payUrl: 'https://qcgateway.zalopay.vn/o?order=1',
          expiresAt: _iso(h.now.add(const Duration(seconds: 90))));
      await h.pump(t);
      await _tap(t, _key('pay-cta'));
      await _settle(t);
      expect(find.text(_vi.moneyPayExpiresIn('01:30')), findsOneWidget);
      h.now = h.now.add(const Duration(seconds: 30));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(_vi.moneyPayExpiresIn('01:00')), findsOneWidget);
      expect(_key('pay-recreate'), findsNothing);

      h.now = h.now.add(const Duration(seconds: 61));
      await t.pump(const Duration(seconds: 1));
      await _settle(t);
      expect(find.text(_vi.moneyPayRecreate), findsOneWidget);
      expect(find.text(_vi.moneyPayPaid), findsNothing);

      final first = h.api.initiates.single;
      await _tap(t, _key('pay-recreate'));
      await _settle(t);
      expect(h.api.initiates, hasLength(2));
      expect(h.api.initiates[1], isNot(first));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('ledger + clock: same key before expiresAt, a fresh key after it', (t) async {
      final h = _H(_booking('AWAITING_PAYMENT', 'zalopay'));
      h.api.result = PaymentInitiateResult(
          kind: 'ok',
          bookingId: 5,
          payUrl: 'https://qcgateway.zalopay.vn/o?order=1',
          expiresAt: _iso(h.now.add(const Duration(minutes: 15))));
      await h.pump(t);
      await _tap(t, _key('pay-cta'));
      await _settle(t);

      // a pending key left from an earlier attempt, still inside the intent's life
      final pending = await h.ledger.keyFor('pay-initiate:5');
      await _tap(t, _key('pay-again'));
      await _settle(t);
      expect(h.api.initiates.last, pending);

      // again a pending key, but now the intent has expired -> forgotten first
      final stale = await h.ledger.keyFor('pay-initiate:5');
      h.now = h.now.add(const Duration(minutes: 16));
      await _tap(t, _key('pay-again'));
      await _settle(t);
      expect(h.api.initiates.last, isNot(stale));
      await t.pumpWidget(const SizedBox());
    });
  });

  group('poll deadline', () {
    test('stops at expiresAt even with schedule left; without a deadline the schedule runs', () async {
      var clock = DateTime.utc(2026, 10, 14, 10);
      var reads = 0;
      Future<PaymentStatusResult> fetch() async {
        reads++;
        return const PaymentStatusResult(status: 'pending', paid: false, failed: false);
      }

      final out = await pollPaymentStatus(fetch,
          deadline: clock.add(const Duration(seconds: 7)),
          now: () => clock,
          sleep: (d) async => clock = clock.add(d));
      expect(out, PaymentPollOutcome.timeout);
      expect(reads, lessThan(kPaymentPollDelays.length + 1));

      reads = 0;
      await pollPaymentStatus(fetch, sleep: (_) async {});
      expect(reads, kPaymentPollDelays.length + 1);
    });
  });
}
