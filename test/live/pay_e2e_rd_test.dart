// PAY-E2E-rd: the customer payment chain end to end against the lab on
// release-d (96a4b8d8), using the REAL KycoApi, the app's IdempotencyLedger,
// pollPaymentStatus and the PayFlowController (riverpod container, launcher
// overridden). QA only; lab only (127.0.0.1:4142).
//
// Settlement is a REAL signed VNPay IPN (HMAC-SHA512) POSTed/GET to an
// ephemeral second app instance on :4144 that has only VNPAY_TMN_CODE /
// VNPAY_HASH_SECRET added (the :4142 lab env is untouched, VNPAY_PROVIDER=stub
// has no IPN secret). Both instances share the same DB and code.
//
//   flutter test test/live/pay_e2e_rd_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 \
//     --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/payment_poll.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/format.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart' show authUserIdProvider;
import 'package:kyco_mobile/features/bookings/payment_flow.dart';

import 'live_support_rd.dart';

String get _resultPath => '$kQaRoot/out/mobile/PAY-E2E-rd.result.json';
String get _callsPath => '$kQaRoot/out/mobile/contract-calls-pay-rd.jsonl';
const int _ipnPort = 4144;

final List<Map<String, dynamic>> _steps = [];
String _case = '';

void _step(String id, String name, bool ok, {int? http, Map<String, dynamic>? detail}) {
  _steps.add({'id': id, 'name': name, 'ok': ok, 'http': http, ...?detail});
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $id $name  http=$http ${detail == null ? '' : jsonEncode(detail)}');
}

List<List<String>> _rows(String q) =>
    sql(q).split('\n').where((l) => l.isNotEmpty).map((l) => l.split('|')).toList();

Map<String, dynamic> _ledger(int bookingId) {
  final wt = _rows('select wt.id, w.owner_type, w.owner_id, wt.type, wt.amount_vnd::bigint, wt.reason, wt.balance_after_vnd::bigint, coalesce(wt.related_payment_id::text,\'\') '
      'from wallet_transactions wt join wallets w on w.id=wt.wallet_id where wt.related_booking_id=$bookingId order by wt.id');
  return {
    'walletTransactions': [
      for (final r in wt)
        {'id': int.parse(r[0]), 'wallet': '${r[1]}:${r[2]}', 'type': r[3], 'amountVnd': int.parse(r[4]), 'reason': r[5], 'balanceAfterVnd': int.parse(r[6]), 'paymentId': r[7]}
    ],
    'taskerPayouts': _rows('select id, tasker_id, amount_vnd::bigint, platform_fee_vnd::bigint, status from tasker_payouts where booking_id=$bookingId')
        .map((r) => {'id': int.parse(r[0]), 'taskerId': int.parse(r[1]), 'amountVnd': int.parse(r[2]), 'platformFeeVnd': int.parse(r[3]), 'status': r[4]})
        .toList(),
    'payments': _rows('select id, method, status, amount_vnd::bigint, provider_tx_id, coalesce(paid_at::text,\'\'), coalesce(settled_at::text,\'\') from payments where booking_id=$bookingId order by id')
        .map((r) => {'id': int.parse(r[0]), 'method': r[1], 'status': r[2], 'amountVnd': int.parse(r[3]), 'providerTxId': r[4], 'paidAt': r[5], 'settledAt': r[6]})
        .toList(),
    'paymentEvents': _rows('select pe.id, pe.event_kind from payment_events pe join payments p on p.id=pe.payment_id where p.booking_id=$bookingId order by pe.id')
        .map((r) => {'id': int.parse(r[0]), 'kind': r[1]})
        .toList(),
  };
}

Future<Map<String, dynamic>> _sendIpn(String txn, int amountVnd, {String rc = '00'}) async {
  final r = await Process.run('node', ['$kQaRoot/scripts/pay-ipn-rd.mjs', txn, '$amountVnd', '$_ipnPort', rc]);
  if (r.exitCode != 0) return {'error': '${r.stderr}'};
  return jsonDecode((r.stdout as String).trim()) as Map<String, dynamic>;
}

void main() {
  group('PAY-E2E-rd', skip: kLive ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    late LiveClient cust;
    late IdempotencyLedger ledger;
    int? svc;
    final snap = <String, dynamic>{};
    final created = <int>[];
    var startedAt = '';

    setUpAll(() async {
      guardLab();
      shiftCancelQuota();
      Directory('$kQaRoot/out/mobile').createSync(recursive: true);
      final f = File(_callsPath);
      if (f.existsSync()) f.deleteSync();
      startedAt = DateTime.now().toUtc().toIso8601String();
      // lab data snapshot (restored in tearDownAll)
      snap['wallets'] = _rows('select id, owner_type, owner_id, balance_vnd::bigint from wallets order by id');
      snap['maxWt'] = sqlInt('select coalesce(max(id),0) from wallet_transactions');
      snap['maxWallet'] = sqlInt('select coalesce(max(id),0) from wallets');
      // the IPN instance must be up
      final h = await HttpClient().getUrl(Uri.parse('http://127.0.0.1:$_ipnPort/api/health')).then((r) => r.close());
      expect(h.statusCode, 200, reason: 'ephemeral IPN instance :$_ipnPort must be running');
      cust = await loginClient(kCustEmail, kCustPw, jsonlPath: _callsPath, caseName: () => _case);
      ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 1);
      final page = await cust.api.services();
      svc = page.items.first.id;
    });

    tearDownAll(() {
      // restore wallets / ledger rows written by this run
      final maxWt = snap['maxWt'] as int;
      final maxWallet = snap['maxWallet'] as int;
      sql('delete from wallet_transactions where id > $maxWt');
      for (final r in snap['wallets'] as List<List<String>>) {
        sql('update wallets set balance_vnd=${r[3]} where id=${r[0]}');
      }
      sql('delete from wallets where id > $maxWallet');
      if (created.isNotEmpty) {
        sql('delete from tasker_payouts where booking_id in (${created.join(',')})');
        sql("update jobs set status='closed' where booking_id in (${created.join(',')}) and status in ('pending','open')");
      }
      final after = _rows('select id, owner_type, owner_id, balance_vnd::bigint from wallets order by id');
      final restored = jsonEncode(after) == jsonEncode(snap['wallets']);
      _steps.add({'id': 'RESTORE', 'name': 'wallets/wallet_transactions/tasker_payouts restored', 'ok': restored, 'http': null});
      final failed = _steps.where((s) => s['ok'] != true).length;
      writeJson(_resultPath, {
        'pkg': 'PAY-E2E-rd',
        'startedAt': startedAt,
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'labSha': '96a4b8d8',
        'mobile': 'kmob-wt/replay (uncommitted waves)',
        'status': failed == 0 ? 'PASS' : 'FAIL',
        'counts': {'pass': _steps.length - failed, 'fail': failed},
        'settlement': 'REAL signed VNPay IPN (HMAC-SHA512) to the real /api/payment/vnpay/ipn route on an ephemeral instance :$_ipnPort '
            '(only VNPAY_TMN_CODE/VNPAY_HASH_SECRET added to its env; :4142 untouched). No payment row was written directly.',
        'bookingsCreated': created,
        'steps': _steps,
      });
      stdout.writeln('PAY-E2E-rd: ${_steps.length - failed}/${_steps.length} -> $_resultPath');
    });

    test('chain: quote -> create -> confirm -> initiate -> IPN -> paid -> ledger -> replay', () async {
      final api = cust.api;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      BookingDraft draft(String note) => BookingDraft(
            serviceId: svc!, serviceName: 'PAY-E2E', basePriceVnd: 0,
            scheduledDate: ymd(tomorrow), scheduledTime: randomTime(), wardName: 'Quận 1',
            neighborhood: 'Bến Nghé', addressLine: '12 Lê Lợi', notes: note);

      // 1. quote == create
      _case = 'quoteBooking';
      final d = draft('PAY-E2E');
      final q = await api.quoteBooking(d);
      _step('1a', 'quoteBooking returns a total', q != null, http: cust.rec.calls.last.status, detail: {'quoteTotalVnd': q?.totalVnd});
      _case = 'createBooking';
      final c = await api.createBooking(d);
      created.add(c.bookingId);
      final B = c.bookingId;
      _step('1b', 'quote total == create totalVnd', q?.totalVnd == c.totalVnd, http: cust.rec.calls.last.status,
          detail: {'quote': q?.totalVnd, 'create': c.totalVnd, 'bookingId': B, 'kind': c.kind});
      expect(q?.totalVnd, c.totalVnd);
      final total = c.totalVnd!;

      // 2. drive to AWAITING_CUSTOMER_CONFIRMATION (lab SQL, like the tasker complete)
      final job = sqlInt('select id from jobs where booking_id=$B order by id desc limit 1');
      sql("update jobs set tasker_id=1, status='closed', started_at=now()-interval '2 hours', finished_at=now() where id=$job");
      sql("update bookings set status='AWAITING_CUSTOMER_CONFIRMATION', completed_at=now() where id=$B");
      _case = 'bookingDetail';
      var det = await api.bookingDetail(B);
      _step('2', 'booking at AWAITING_CUSTOMER_CONFIRMATION, /page actions.canConfirm', det.status == 'AWAITING_CUSTOMER_CONFIRMATION' && det.serverActions?.canConfirm == true,
          http: cust.rec.calls.last.status, detail: {'status': det.status, 'canConfirm': det.serverActions?.canConfirm, 'canPay': det.serverActions?.canPay, 'method': 'lab SQL (jobs closed + bookings status), tasker net API path covered by flows.mjs'});

      // 2b. initiate in a wrong status. A CASH booking answers 200 kind:'cash' in any status (the cash early-return precedes the
      // status guard); the 409 contract applies to a gateway-method booking, so make the fixture vnpay first (lab SQL).
      _case = 'initiate-cash-any-status';
      PaymentInitiateResult? cashAns;
      try {
        cashAns = await api.initiatePayment(B, idempotencyKey: uuidV4());
      } on ApiException catch (_) {}
      _step('2a', 'initiate on a CASH booking outside AWAITING_PAYMENT -> 200 kind cash (observation: not 409)', cashAns?.kind == 'cash',
          http: cust.rec.calls.last.status, detail: {'kind': cashAns?.kind, 'note': 'final contract text says 409 for any non-AWAITING_PAYMENT status; cash rail returns informational kind=cash first. No money effect.'});
      sql("update bookings set payment_method='vnpay' where id=$B");
      _case = 'initiate-wrong-status';
      ApiException? wrong;
      try {
        await api.initiatePayment(B, idempotencyKey: uuidV4());
      } on ApiException catch (e) {
        wrong = e;
      }
      _step('2b', 'initiate (vnpay) at AWAITING_CUSTOMER_CONFIRMATION -> 409 PAYMENT_NOT_ALLOWED_IN_STATUS',
          wrong?.status == 409 && wrong?.code == 'PAYMENT_NOT_ALLOWED_IN_STATUS', http: wrong?.status, detail: {'code': wrong?.code, 'fields': wrong?.fields});

      // 3. confirmCompletion confirm + vnpay through the ledger
      _case = 'confirmCompletion';
      await ledger.run('confirm:$B:vnpay', (key) => api.confirmCompletion(B, action: 'confirm', paymentMethod: 'vnpay', idempotencyKey: key));
      final st3 = sql('select status from bookings where id=$B');
      det = await api.bookingDetail(B);
      _step('3', 'confirmCompletion(confirm, vnpay) -> AWAITING_PAYMENT, canPay', st3 == 'AWAITING_PAYMENT' && det.serverActions?.canPay == true,
          http: cust.rec.calls.last.status, detail: {'dbStatus': st3, 'pageStatus': det.status, 'canPay': det.serverActions?.canPay, 'canConfirm': det.serverActions?.canConfirm, 'canCancel': det.serverActions?.canCancel});
      expect(st3, 'AWAITING_PAYMENT');

      // 4. initiate through the app's PayFlowController (ledger + api), then raw key replay + P6
      final launched = <Uri>[];
      final container = ProviderContainer(overrides: [
        kycoApiProvider.overrideWithValue(api),
        idempotencyLedgerProvider.overrideWithValue(ledger),
        authUserIdProvider.overrideWithValue(1),
        externalLauncherProvider.overrideWithValue((u) async {
          launched.add(u);
          return true;
        }),
        paymentPollDelaysProvider.overrideWithValue(const [Duration(milliseconds: 300), Duration(milliseconds: 300), Duration(milliseconds: 300)]),
        paymentPollSleepProvider.overrideWithValue((d) => Future<void>.delayed(d)),
      ]);
      addTearDown(container.dispose);
      container.listen(payFlowProvider(B), (_, _) {}, fireImmediately: true);
      _case = 'initiatePayment';
      await container.read(payFlowProvider(B).notifier).pay();
      final phase1 = container.read(payFlowProvider(B)).phase;
      final payRows = _rows("select id, provider_tx_id, amount_vnd::bigint, method, status, coalesce(pay_url,'') from payments where booking_id=$B and status='pending' order by id");
      final txn1 = payRows.isEmpty ? '' : payRows.last[1];
      final init1 = (cust.rec.calls.where((x) => x.path.endsWith('/payment/initiate')).last);
      final body1 = init1.respBody is Map ? (init1.respBody as Map)['data'] as Map? : null;
      _step('4a', 'initiatePayment via PayFlow -> kind ok + payUrl', body1?['kind'] == 'ok' && (body1?['payUrl'] as String?) != null,
          http: init1.status, detail: {'kind': body1?['kind'], 'payUrl': body1?['payUrl'], 'providerTxId': body1?['providerTxId'], 'payFlowPhase': phase1.name,
            'launcherCalled': launched.length, 'note': 'lab payUrl is http (stub): PayFlow.isOpenablePayUrl requires https, so phase openFailed is the by-design outcome here'});
      // same key replay
      final k = uuidV4();
      final r1 = await api.initiatePayment(B, idempotencyKey: k);
      final r2 = await api.initiatePayment(B, idempotencyKey: k);
      final replayHdr = cust.rec.calls.where((x) => x.path.endsWith('/payment/initiate')).last.replayed;
      _step('4b', 'initiate retry, same key -> same txn + idempotent-replayed', r1.providerTxId == r2.providerTxId && replayHdr == 'true',
          http: cust.rec.calls.last.status, detail: {'txn1': mask(r1.providerTxId), 'txn2': mask(r2.providerTxId), 'replayedHeader': replayHdr});
      // new key (P6)
      final r3 = await api.initiatePayment(B, idempotencyKey: uuidV4());
      final pending = sqlInt("select count(*) from payments where booking_id=$B and status='pending' and provider_tx_id is not null and provider_tx_id not like 'kyco-%'");
      _step('4c', 'initiate with a NEW key -> same intent (P6), one pending payment', r3.providerTxId == r1.providerTxId && pending == 1,
          http: cust.rec.calls.last.status, detail: {'sameTxn': r3.providerTxId == r1.providerTxId, 'pendingPaymentsWithTxn': pending, 'pendingPaymentsAll': sqlInt("select count(*) from payments where booking_id=$B and status='pending'"), 'note': 'the extra pending row is the server placeholder kyco-post-confirm-<booking>-<ts> (no payUrl, not payable); only one payable intent exists', 'txn': r1.providerTxId});
      final txn = r1.providerTxId ?? txn1;
      expect(txn, isNotEmpty);

      // 5. status pending, then SETTLE by a real signed IPN
      _case = 'paymentStatus';
      final s0 = await api.paymentStatus(B);
      _step('5a', 'paymentStatus before IPN is not paid', !s0.serverSaysPaid, http: cust.rec.calls.last.status, detail: {'status': s0.status, 'paid': s0.paid});
      final payAmt = sqlInt("select amount_vnd::bigint from payments where booking_id=$B and provider_tx_id='$txn'");
      final payMethod = sql("select method from payments where booking_id=$B and provider_tx_id='$txn'");
      final before = _ledger(B);
      final ipn = await _sendIpn(txn, payAmt);
      final ipnBody = ipn['body'] is String ? jsonDecode(ipn['body'] as String) as Map<String, dynamic> : <String, dynamic>{};
      _step('5b', 'signed VNPay IPN accepted by /api/payment/vnpay/ipn (RspCode 00)', ipn['status'] == 200 && ipnBody['RspCode'] == '00',
          http: ipn['status'] as int?, detail: {'ipnResponse': ipnBody, 'txn': txn, 'amountVnd': payAmt, 'paymentMethodColumn': payMethod, 'ipnInstance': ':$_ipnPort', 'ledgerRowsBefore': (before['walletTransactions'] as List).length});

      // 6. the app poll sees paid, booking settled
      final outcome = await pollPaymentStatus(() => api.paymentStatus(B), delays: const [Duration(milliseconds: 500), Duration(milliseconds: 500)]);
      await container.read(payFlowProvider(B).notifier).check();
      final phase2 = container.read(payFlowProvider(B)).phase;
      final st6 = sql('select status from bookings where id=$B');
      det = await api.bookingDetail(B);
      final ps = await api.paymentStatus(B);
      _step('6', 'poll reports paid; PayFlow phase paid; booking SETTLED', outcome == PaymentPollOutcome.paid && phase2 == PayPhase.paid && st6 == 'SETTLED',
          http: cust.rec.calls.last.status, detail: {'pollOutcome': outcome.name, 'payFlowPhase': phase2.name, 'dbStatus': st6, 'pageStatus': det.status, 'paymentStatus': ps.status, 'canPay': det.serverActions?.canPay, 'canCancel': det.serverActions?.canCancel});

      // 7. 80/20 ledger
      final led = _ledger(B);
      final rule = _rows("select id, scope_kind, scope_value, platform_rate_bp from commission_rules where is_active order by scope_kind, id");
      final taskerRule = sqlInt("select count(*) from commission_rules where scope_kind='tasker' and scope_value='1' and is_active");
      final cityId = sql('select coalesce(city_id::text,\'\') from bookings where id=$B');
      final tx = led['walletTransactions'] as List;
      int sumOf(String wallet, String reason) => tx.where((t) => t['wallet'] == wallet && t['reason'] == reason).fold<int>(0, (a, t) => a + (t['amountVnd'] as int) * (t['type'] == 'credit' ? 1 : -1));
      final taskerNet = sumOf('tasker:1', 'tasker_earning');
      final commissionNet = sumOf('kyco_revenue:0', 'commission');
      final sweep = -sumOf('kyco_revenue:0', 'insurance_sweep');
      final insuranceIn = sumOf('kyco_insurance:0', 'insurance_sweep');
      final clearingIn = sumOf('kyco_clearing:0', 'payment_in');
      final clearingOut = -sumOf('kyco_clearing:0', 'settlement');
      // expected, read from the code: resolveCommission() default 2000bp -> fee=round(total*bp/10000), tasker=total-fee;
      // sweep=min(floor(gross*50/10000), floor(fee/2)) moves from revenue to insurance.
      final defaultBp = sqlInt("select platform_rate_bp from commission_rules where scope_kind='default' and is_active limit 1");
      final bp = defaultBp == 0 ? 2000 : defaultBp;
      final expFee = (total * bp / 10000).round();
      final expTasker = total - expFee;
      final expSweep = [(total * 50) ~/ 10000, expFee ~/ 2].reduce((a, b) => a < b ? a : b);
      final ok7 = taskerNet == expTasker && (commissionNet - 0) == expFee && clearingIn == total && clearingOut == total && sweep == expSweep && insuranceIn == expSweep;
      _step('7', '80/20 ledger: tasker net + platform commission + clearing', ok7 && taskerRule == 0,
          detail: {
            'grossTotalVnd': total,
            'resolveCommission': {'rateBp': bp, 'activeRules': rule.map((r) => '${r[1]}:${r[2]}@${r[3]}').toList(), 'taskerOverrideRows': taskerRule, 'cityId': cityId, 'formula': 'fee=round(total*bp/10000); tasker=total-fee'},
            'expected': {'taskerNetVnd': expTasker, 'platformCommissionVnd': expFee, 'insuranceSweepVnd': expSweep, 'revenueAfterSweepVnd': expFee - expSweep},
            'actual': {'taskerEarningVnd': taskerNet, 'kycoRevenueCommissionVnd': commissionNet, 'insuranceSweepOutOfRevenueVnd': sweep, 'insuranceFundInVnd': insuranceIn, 'clearingPaymentInVnd': clearingIn, 'clearingSettlementOutVnd': clearingOut},
            'ledger': led,
          });

      // 8. replay IPN: Redis fast path, then DB claim path (redis key removed)
      final rowsBefore = (led['walletTransactions'] as List).length;
      final rep1 = await _sendIpn(txn, payAmt);
      final rep1b = jsonDecode(rep1['body'] as String) as Map<String, dynamic>;
      final redisKey = 'webhook:vnpay:$txn';
      final del = await Process.run('docker', ['exec', 'kyco-redis', 'redis-cli', 'DEL', redisKey]);
      final rep2 = await _sendIpn(txn, payAmt);
      final rep2b = jsonDecode(rep2['body'] as String) as Map<String, dynamic>;
      final led2 = _ledger(B);
      final sameRows = (led2['walletTransactions'] as List).length == rowsBefore && (led2['taskerPayouts'] as List).length == 1;
      _step('8', 'IPN replay is idempotent: no double ledger', sameRows && sql('select status from bookings where id=$B') == 'SETTLED',
          detail: {'replayRedisPath': rep1b, 'redisDel': '${'${del.stdout}'.trim()}/${'${del.stderr}'.trim()}', 'replayDbClaimPath': rep2b,
            'walletTxRowsBefore': rowsBefore, 'walletTxRowsAfter': (led2['walletTransactions'] as List).length, 'taskerPayoutsRows': (led2['taskerPayouts'] as List).length,
            'paymentEvents': led2['paymentEvents']});

      // 8c. initiate after paid
      _case = 'initiate-after-paid';
      String after = '';
      try {
        final r = await api.initiatePayment(B, idempotencyKey: uuidV4());
        after = 'ok kind=${r.kind}';
      } on ApiException catch (e) {
        after = '${e.status} ${e.code}';
      }
      _step('8c', 'initiate on a SETTLED booking is refused/typed (not a 5xx)', !after.startsWith('5'), detail: {'result': after});
    });

    test('cancel preview == cancel response (2 cases)', timeout: const Timeout(Duration(minutes: 5)), () async {
      final api = cust.api;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      Future<void> one(String label, void Function(int id) prep) async {
        final c = await api.createBooking(BookingDraft(
            serviceId: svc!, serviceName: 'PAY-E2E', basePriceVnd: 0, scheduledDate: ymd(tomorrow), scheduledTime: randomTime(),
            wardName: 'Quận 1', neighborhood: 'Bến Nghé', addressLine: '12 Lê Lợi', notes: 'PAY-E2E cancel $label'));
        created.add(c.bookingId);
        // a booking made right after a customer cancel is cancel-locked 24h (409; preview null, canCancel false) -> lab fixture clears the lock
        sql('update bookings set compensation_lock_until=null where id=${c.bookingId}');
        prep(c.bookingId);
        _case = 'cancel:$label';
        final det = await api.bookingDetail(c.bookingId);
        final pv = det.cancelPreview;
        final code = det.cancelReasons.isNotEmpty ? det.cancelReasons.first.code : 'other';
        CancelResult? res;
        ApiException? err;
        try {
          res = await ledger.run('cancel:${c.bookingId}:$code', (key) => api.cancelBooking(c.bookingId, reasonCode: code, idempotencyKey: key));
        } on ApiException catch (e) {
          err = e;
        }
        final st = sql('select status from bookings where id=${c.bookingId}');
        final ok = err == null && res?.feeVnd == pv?.feeVnd && res?.refundVnd == pv?.refundVnd && st == 'CANCELLED';
        _step('9-$label', 'cancelPreview fee/refund == cancel response', ok, http: cust.rec.calls.last.status, detail: {
          'bookingId': c.bookingId,
          'preview': {'feeVnd': pv?.feeVnd, 'refundVnd': pv?.refundVnd, 'reason': pv?.reasonCode},
          'cancelResponse': {'feeVnd': res?.feeVnd, 'refundVnd': res?.refundVnd, 'refundStatus': res?.refundStatus},
          'reasonCodeUsed': code, 'serverReasons': det.cancelReasons.map((r) => r.code).toList(), 'dbStatus': st,
          if (err != null) 'error': '${err.status} ${err.code} ${err.message} retryAfter=${err.retryAfter}',
        });
        await Future<void>.delayed(const Duration(seconds: 65)); // cancel budget: 3/min/user + 429 seen at +21s
      }

      await one('free-window', (id) {});
      await one('after-start', (id) {
        sql("update bookings set scheduled_at=now()-interval '1 hour', status='CONFIRMED' where id=$id");
      });
    });
  });
}
