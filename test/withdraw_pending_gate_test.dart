// One-pending-payout rule (backend ff6198c3; human-approved "duyệt" 2026-10-11):
// wallet gate fields, 409 PAYOUT_PENDING_EXISTS copy + refresh, 422 `amountVnd`.
// The idempotency ledger, fingerprint and amount handling are NOT changed here;
// these tests pin that they stay as they were.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/tasker_wallet/tasker_wallet_screen.dart';
import 'package:kyco_mobile/features/tasker_wallet/withdraw_sheet.dart';

import 'wave_c_support.dart';

const _pendingMsg = 'Bạn đang có một yêu cầu rút tiền chờ xử lý. Vui lòng chờ duyệt trước khi tạo yêu cầu mới.';
const _blockedLabel = 'Bạn đang có yêu cầu rút tiền chờ duyệt.';

Map<String, dynamic> _wallet({bool? can, int? pendingId, bool reason = true}) => {
      'balanceVnd': 500000,
      'currency': 'VND',
      'lifetimeEarningVnd': 0,
      'lifetimeFeeVnd': 0,
      'jobCount': 0,
      'monthEarningVnd': 0,
      if (can != null) 'pendingPayoutRequestId': pendingId,
      'canRequestPayout': ?can,
      if (can == false && reason)
        'payoutBlockedReason': {'code': 'PAYOUT_PENDING_EXISTS', 'label': _blockedLabel},
    };

class _SpyLedger extends IdempotencyLedger {
  _SpyLedger() : super(store: MemoryPendingKeyStore());
  final fingerprints = <String>[];
  @override
  Future<T> run<T>(String fingerprint, Future<T> Function(String key) call) {
    fingerprints.add(fingerprint);
    return super.run(fingerprint, call);
  }
}

class _Rig {
  _Rig(this.h, this.ledger);
  final Harness h;
  final _SpyLedger ledger;
  int walletGets() => h.backend.calls('GET /tasker/wallet').length;
  int requestGets() => h.backend.calls('GET /tasker/payout-requests').length;
  int txnGets() => h.backend.calls('GET /tasker/wallet/transactions').length;
}

Future<_Rig> _pump(
  WidgetTester t, {
  required Map<String, dynamic> Function() wallet,
  ({int status, Object? body}) Function()? payout,
  List<Map<String, dynamic>> requests = const [],
}) async {
  useTallView(t);
  final b = Backend()
    ..on('GET /tasker/wallet', (_) => Backend.ok(wallet()))
    ..on('GET /tasker/wallet/transactions', (_) => Backend.ok(const []))
    ..on('GET /tasker/payouts', (_) => Backend.ok(const []))
    ..on('GET /tasker/payout-requests', (_) => Backend.ok(requests))
    ..on('GET /auth/step-up', (_) => Backend.ok({'fresh': true, 'hasUsablePassword': true}))
    ..on('POST /tasker/payouts', (_) => payout!());
  final ledger = _SpyLedger();
  final h = await harness(backend: b, extra: [idempotencyLedgerProvider.overrideWithValue(ledger)]);
  await t.pumpWidget(appWith(h, const TaskerWalletScreen()));
  await t.pumpAndSettle();
  return _Rig(h, ledger);
}

Future<void> _withdraw(WidgetTester t, String amount) async {
  await t.tap(find.text(vi.provWalletWithdrawAction));
  await t.pumpAndSettle();
  await t.enterText(find.byType(TextField), amount);
  await t.tap(find.text(vi.provWalletContinue));
  await t.pumpAndSettle();
}

({int status, Object? body}) _envelope(int status, String code, String message,
        {Map<String, dynamic>? fields, Map<String, dynamic>? details}) =>
    (
      status: status,
      body: {
        'ok': false,
        'code': code,
        'message': message,
        'retryable': false,
        'fields': ?fields,
        'details': ?details,
      }
    );

FilledButton _button(WidgetTester t) =>
    t.widget<FilledButton>(find.ancestor(of: find.text(vi.provWalletWithdrawAction), matching: find.byWidgetPredicate((w) => w is FilledButton)));

void main() {
  group('model parsing', () {
    test('ApiException.fromEnvelope keeps details + retryable', () {
      final e = ApiException.fromEnvelope({
        'ok': false,
        'code': 'PAYOUT_PENDING_EXISTS',
        'message': _pendingMsg,
        'retryable': false,
        'details': {'pendingRequestId': 91},
      }, 409);
      expect(e.details, {'pendingRequestId': 91});
      expect(e.retryable, isFalse);
      expect(e.message, _pendingMsg);
    });

    test('ApiException tolerates absent / malformed details + retryable', () {
      final a = ApiException.fromEnvelope({'code': 'CONFLICT', 'message': 'm'}, 409);
      expect(a.details, isNull);
      expect(a.retryable, isNull);
      final b = ApiException.fromEnvelope({'code': 'X', 'details': 'nope', 'retryable': 'yes', 'fields': null}, 409);
      expect(b.details, isNull);
      expect(b.retryable, isNull);
      // existing constructor shape still compiles and works
      final c = ApiException('c', 'm', status: 400, fields: const {'a': 'b'});
      expect(c.details, isNull);
      expect(c.fields, {'a': 'b'});
    });

    test('WalletSummary parses the gate fields', () {
      final s = WalletSummary.fromJson(_wallet(can: false, pendingId: 91));
      expect(s.canRequestPayout, isFalse);
      expect(s.pendingPayoutRequestId, 91);
      expect(s.payoutBlockedReason?.code, 'PAYOUT_PENDING_EXISTS');
      expect(s.payoutBlockedReason?.label, _blockedLabel);
    });

    test('WalletSummary: unblocked shape and absent fields default to allowed', () {
      final unblocked = WalletSummary.fromJson({
        ..._wallet(),
        'pendingPayoutRequestId': null,
        'canRequestPayout': true,
        'payoutBlockedReason': null,
      });
      expect(unblocked.canRequestPayout, isTrue);
      expect(unblocked.pendingPayoutRequestId, isNull);
      expect(unblocked.payoutBlockedReason, isNull);
      final old = WalletSummary.fromJson(_wallet());
      expect(old.canRequestPayout, isTrue);
      expect(old.pendingPayoutRequestId, isNull);
      expect(old.payoutBlockedReason, isNull);
      expect(const WalletSummary().canRequestPayout, isTrue);
    });
  });

  group('wallet screen gate', () {
    testWidgets('blocked: button disabled, reason + link shown, sheet never opens, link highlights the request',
        (t) async {
      await _pump(t,
          wallet: () => _wallet(can: false, pendingId: 91),
          requests: [
            {'id': 91, 'amountVnd': 150000, 'status': 'pending', 'bank': {'masked': 'VCB ••••1234'}},
            {'id': 90, 'amountVnd': 200000, 'status': 'paid', 'bank': {'masked': 'TCB ••••9999'}},
          ]);
      expect(_button(t).onPressed, isNull);
      expect(find.text(_blockedLabel), findsOneWidget);
      expect(find.text(vi.provWalletViewPendingRequest), findsOneWidget);
      await t.tap(find.text(vi.provWalletWithdrawAction), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.byType(WithdrawSheet), findsNothing);

      bool highlighted(String masked) => find
          .ancestor(
              of: find.text(masked),
              matching: find.byWidgetPredicate((w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).border != null))
          .evaluate()
          .isNotEmpty;
      expect(highlighted('VCB ••••1234'), isFalse);
      await t.tap(find.text(vi.provWalletViewPendingRequest));
      await t.pumpAndSettle();
      expect(highlighted('VCB ••••1234'), isTrue);
      expect(highlighted('TCB ••••9999'), isFalse);
    });

    testWidgets('blocked without a label falls back to localized copy', (t) async {
      await _pump(t, wallet: () => _wallet(can: false, pendingId: 91, reason: false));
      expect(_button(t).onPressed, isNull);
      expect(find.text(vi.provWalletPayoutBlockedFallback), findsOneWidget);
    });

    testWidgets('not blocked: button enabled', (t) async {
      await _pump(t, wallet: () => _wallet(can: true));
      expect(_button(t).onPressed, isNotNull);
      expect(find.text(vi.provWalletViewPendingRequest), findsNothing);
      await t.tap(find.text(vi.provWalletWithdrawAction));
      await t.pumpAndSettle();
      expect(find.byType(WithdrawSheet), findsOneWidget);
      // Dismiss so the flow finishes (it holds a process-wide in-flight latch).
      await t.tapAt(const Offset(5, 5));
      await t.pumpAndSettle();
      expect(find.byType(WithdrawSheet), findsNothing);
    });

    testWidgets('older backend (fields absent): button enabled as before', (t) async {
      await _pump(t, wallet: () => _wallet());
      expect(_button(t).onPressed, isNotNull);
      expect(find.text(vi.provWalletViewPendingRequest), findsNothing);
    });
  });

  group('withdraw flow errors', () {
    testWidgets('409 PAYOUT_PENDING_EXISTS: server message shown, wallet/requests/txns refetched, gate appears',
        (t) async {
      var blocked = false;
      final rig = await _pump(t,
          wallet: () => blocked ? _wallet(can: false, pendingId: 91) : _wallet(can: true),
          requests: [
            {'id': 91, 'amountVnd': 150000, 'status': 'pending'}
          ],
          payout: () {
            blocked = true; // the server now has the pending request
            return _envelope(409, 'PAYOUT_PENDING_EXISTS', _pendingMsg, details: {'pendingRequestId': 91});
          });
      final before = (rig.walletGets(), rig.requestGets(), rig.txnGets());
      await _withdraw(t, '150000');
      expect(find.text(_pendingMsg), findsOneWidget); // snackbar: SERVER message verbatim
      expect(find.text(vi.provWalletWithdrawPending), findsNothing);
      expect(rig.walletGets(), before.$1 + 1);
      expect(rig.requestGets(), before.$2 + 1);
      expect(rig.txnGets(), before.$3 + 1);
      expect(_button(t).onPressed, isNull); // gate now visible
      expect(find.text(_blockedLabel), findsOneWidget);
    });

    testWidgets('409 PAYOUT_PENDING_EXISTS with an empty message falls back to the ARB copy', (t) async {
      final rig = await _pump(t,
          wallet: () => _wallet(can: true), payout: () => _envelope(409, 'PAYOUT_PENDING_EXISTS', ''));
      final w = rig.walletGets();
      await _withdraw(t, '150000');
      expect(find.text(vi.provWalletWithdrawPendingExists), findsOneWidget);
      expect(rig.walletGets(), w + 1);
    });

    testWidgets('generic 409 CONFLICT: "being processed" copy AND a refresh', (t) async {
      final rig = await _pump(t,
          wallet: () => _wallet(can: true), payout: () => _envelope(409, 'CONFLICT', 'raw conflict'));
      final before = (rig.walletGets(), rig.requestGets(), rig.txnGets());
      await _withdraw(t, '150000');
      expect(find.text(vi.provWalletWithdrawPending), findsOneWidget);
      expect(find.text('raw conflict'), findsNothing);
      expect(rig.walletGets(), before.$1 + 1);
      expect(rig.requestGets(), before.$2 + 1);
      expect(rig.txnGets(), before.$3 + 1);
    });

    testWidgets('422 fields.amountVnd -> friendly copy, never the raw field', (t) async {
      await _pump(t,
          wallet: () => _wallet(can: true),
          payout: () => _envelope(422, 'VALIDATION', 'Insufficient', fields: {'amountVnd': 'insufficient_balance 12345'}));
      await _withdraw(t, '150000');
      expect(find.text(vi.provWalletWithdrawInvalidAmount), findsOneWidget);
      expect(find.textContaining('12345'), findsNothing);
    });

    testWidgets('422 fields.amount_vnd (older server) still maps to the friendly copy', (t) async {
      await _pump(t,
          wallet: () => _wallet(can: true),
          payout: () => _envelope(422, 'VALIDATION', 'Insufficient', fields: {'amount_vnd': 'insufficient_balance'}));
      await _withdraw(t, '150000');
      expect(find.text(vi.provWalletWithdrawInvalidAmount), findsOneWidget);
    });

    testWidgets('ledger unchanged: fingerprint payout:<amount>, typed amount sent as-is, key header present',
        (t) async {
      final rig = await _pump(t,
          wallet: () => _wallet(can: true), payout: () => _envelope(409, 'CONFLICT', 'x'));
      await _withdraw(t, '150000');
      expect(rig.ledger.fingerprints, ['payout:150000']);
      final post = rig.h.backend.calls('POST /tasker/payouts').single;
      expect(post.data, {'amountVnd': 150000});
      expect(post.headers['Idempotency-Key'], isA<String>());
    });
  });
}
