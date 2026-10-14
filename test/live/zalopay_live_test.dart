// ZALOPAY-LAB: the ZaloPay rail (backend 140b0a49, feat/zalopay-rail) against the uncommitted mobile build, LAB ONLY
// (127.0.0.1:4142), using the REAL KycoApi, the app's IdempotencyLedger, pollPaymentStatus and PayFlowController.
// The ZaloPay SANDBOX gateway (sb-openapi.zalopay.vn) is called by the lab server at initiate (create order); the
// payment itself is NOT made in the ZaloPay app (needs a PIN): settlement is a correctly signed callback
// (HMAC-SHA256 over the raw `data` string with key2) POSTed to the real /api/payment/zalopay/callback route.
//
// Needs the ZaloPay sandbox env in the TEST process env (read from Platform.environment, never printed):
//   set -a; . /home/bi/kyco-secrets/zalopay-sandbox.env; set +a
//   flutter test test/live/zalopay_live_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
//
// The flag-OFF step runs $QA/scripts/zp-flag.sh off|on (lab DB flag flip + lab server restart) and always turns it back ON.
// Data cleanup: scoped by the booking ids this run created (wallet txs / payouts), wallets restored from a snapshot.
@Tags(['live'])
@Timeout(Duration(minutes: 20))
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/payment_poll.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/format.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart' show authUserIdProvider;
import 'package:kyco_mobile/features/bookings/payment_flow.dart';

import 'live_support_rd.dart';

String get _resultPath => '$kQaRoot/out/mobile/ZALOPAY-LIVE.result.json';
String get _callsPath => '$kQaRoot/out/mobile/contract-calls-zalopay.jsonl';

final List<Map<String, dynamic>> _steps = [];
String _case = '';

void _step(String id, String name, bool ok, {int? http, Map<String, dynamic>? detail}) {
  _steps.add({'id': id, 'name': name, 'ok': ok, 'http': http, ...?detail});
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $id $name  http=$http ${detail == null ? '' : jsonEncode(detail)}');
}

List<List<String>> _rows(String q) => sql(q).split('\n').where((l) => l.isNotEmpty).map((l) => l.split('|')).toList();

Map<String, dynamic> _ledger(int bookingId) {
  final wt = _rows('select wt.id, w.owner_type, w.owner_id, wt.type, wt.amount_vnd::bigint, wt.reason '
      'from wallet_transactions wt join wallets w on w.id=wt.wallet_id where wt.related_booking_id=$bookingId order by wt.id');
  return {
    'walletTransactions': [
      for (final r in wt) {'id': int.parse(r[0]), 'wallet': '${r[1]}:${r[2]}', 'type': r[3], 'amountVnd': int.parse(r[4]), 'reason': r[5]}
    ],
    'taskerPayouts': _rows('select id, tasker_id, amount_vnd::bigint, platform_fee_vnd::bigint, status from tasker_payouts where booking_id=$bookingId')
        .map((r) => {'id': int.parse(r[0]), 'taskerId': int.parse(r[1]), 'amountVnd': int.parse(r[2]), 'platformFeeVnd': int.parse(r[3]), 'status': r[4]})
        .toList(),
    'payments': _rows("select id, method, status, amount_vnd::bigint, coalesce(provider_tx_id,'') from payments where booking_id=$bookingId order by id")
        .map((r) => {'id': int.parse(r[0]), 'method': r[1], 'status': r[2], 'amountVnd': int.parse(r[3]), 'providerTxId': r[4]})
        .toList(),
  };
}

String _env(String k) => (Platform.environment[k] ?? '').trim();

/// Signed ZaloPay callback. key2 is read from the env, used for the HMAC only, never printed or stored.
/// [tamperMac] flips the last hex digit of the mac.
Future<({int status, Map<String, dynamic> body})> _callback(String appTransId, int amount,
    {bool tamperMac = false, String? dataOverrideAfterSign}) async {
  final key2 = _env('ZALOPAY_KEY2');
  final appId = int.parse(_env('ZALOPAY_APP_ID'));
  final data = jsonEncode({
    'app_id': appId,
    'app_trans_id': appTransId,
    'app_time': DateTime.now().millisecondsSinceEpoch,
    'app_user': 'kyco-lab',
    'amount': amount,
    'embed_data': '{}',
    'item': '[]',
    'zp_trans_id': 260000000000000 + DateTime.now().millisecondsSinceEpoch % 1000000000,
    'server_time': DateTime.now().millisecondsSinceEpoch,
    'channel': 36,
    'merchant_user_id': 'lab',
    'user_fee_amount': 0,
    'discount_amount': 0,
  });
  var mac = Hmac(sha256, utf8.encode(key2)).convert(utf8.encode(data)).toString();
  if (tamperMac) mac = mac.substring(0, mac.length - 1) + (mac.endsWith('0') ? '1' : '0');
  final body = jsonEncode({'data': dataOverrideAfterSign ?? data, 'mac': mac, 'type': 1});
  final dio = Dio(BaseOptions(validateStatus: (_) => true, headers: {'content-type': 'application/json'}));
  final r = await dio.post<String>(
    'http://127.0.0.1:4142/api/payment/zalopay/callback',
    data: body,
    options: Options(responseType: ResponseType.plain),
  );
  Map<String, dynamic> parsed = {};
  try {
    parsed = jsonDecode(r.data ?? '{}') as Map<String, dynamic>;
  } catch (_) {}
  return (status: r.statusCode ?? 0, body: parsed);
}

String _flag(String onOff) {
  final r = Process.runSync('$kQaRoot/scripts/zp-flag.sh', [onOff]);
  if (r.exitCode != 0) throw StateError('zp-flag.sh $onOff failed: ${r.stderr}');
  return (r.stdout as String).trim();
}

void main() {
  group('ZALOPAY-LAB', skip: kLive ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    late LiveClient cust;
    late IdempotencyLedger ledger;
    int? svc;
    final snap = <String, dynamic>{};
    final created = <int>[];
    var startedAt = '';

    setUpAll(() async {
      guardLab();
      expect(_env('ZALOPAY_KEY2'), isNotEmpty, reason: 'source the zalopay sandbox env into the test process');
      expect(_env('ZALOPAY_APP_ID'), isNotEmpty);
      Directory('$kQaRoot/out/mobile').createSync(recursive: true);
      final f = File(_callsPath);
      if (f.existsSync()) f.deleteSync();
      startedAt = DateTime.now().toUtc().toIso8601String();
      snap['wallets'] = _rows('select id, owner_type, owner_id, balance_vnd::bigint from wallets order by id');
      snap['maxWallet'] = sqlInt('select coalesce(max(id),0) from wallets');
      cust = await loginClient(kCustEmail, kCustPw, jsonlPath: _callsPath, caseName: () => _case);
      ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 1);
      svc = (await cust.api.services()).items.first.id;
    });

    tearDownAll(() {
      try {
        // make sure the lab ends with the flag ON (idempotent, restarts the lab server only if it was OFF)
        if (sql("select value from site_settings where key='feature.payment_zalopay_enabled'") != 'true') _flag('on');
      } catch (e) {
        stdout.writeln('WARN flag restore: $e');
      }
      if (created.isNotEmpty) {
        final ids = created.join(',');
        sql('delete from wallet_transactions where related_booking_id in ($ids)');
        sql('delete from tasker_payouts where booking_id in ($ids)');
        sql("update jobs set status='closed' where booking_id in ($ids) and status in ('pending','open')");
      }
      for (final r in snap['wallets'] as List<List<String>>) {
        sql('update wallets set balance_vnd=${r[3]} where id=${r[0]}');
      }
      final after = _rows('select id, owner_type, owner_id, balance_vnd::bigint from wallets order by id');
      final restored = jsonEncode(after) == jsonEncode(snap['wallets']);
      _steps.add({'id': 'RESTORE', 'name': 'wallets restored; scoped wallet_transactions/tasker_payouts deleted', 'ok': restored, 'http': null});
      final failed = _steps.where((s) => s['ok'] != true).length;
      writeJson(_resultPath, {
        'pkg': 'ZALOPAY-LAB',
        'startedAt': startedAt,
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'labSha': '140b0a49',
        'status': failed == 0 ? 'PASS' : 'FAIL',
        'counts': {'pass': _steps.length - failed, 'fail': failed},
        'bookingsCreated': created,
        'steps': _steps,
      });
      stdout.writeln('ZALOPAY-LAB: ${_steps.length - failed}/${_steps.length} -> $_resultPath');
    });

    /// New customer booking driven (lab SQL, as pay_e2e_rd) to AWAITING_CUSTOMER_CONFIRMATION, then confirm with
    /// zalopay through the ledger -> AWAITING_PAYMENT. Returns (bookingId, totalVnd).
    Future<(int, int)> awaitingPayment(String note) async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final c = await cust.api.createBooking(BookingDraft(
          serviceId: svc!, serviceName: 'ZP-LAB', basePriceVnd: 0, scheduledDate: ymd(tomorrow), scheduledTime: randomTime(),
          wardName: 'Quận 1', neighborhood: 'Bến Nghé', addressLine: '12 Lê Lợi', notes: note));
      final b = c.bookingId;
      created.add(b);
      final job = sqlInt('select id from jobs where booking_id=$b order by id desc limit 1');
      sql("update jobs set tasker_id=1, status='closed', started_at=now()-interval '2 hours', finished_at=now() where id=$job");
      sql("update bookings set status='AWAITING_CUSTOMER_CONFIRMATION', completed_at=now() where id=$b");
      await ledger.run('confirm:$b:zalopay', (key) => cust.api.confirmCompletion(b, action: 'confirm', paymentMethod: 'zalopay', idempotencyKey: key));
      expect(sql('select status from bookings where id=$b'), 'AWAITING_PAYMENT');
      return (b, c.totalVnd!);
    }

    int initiateCalls() => cust.rec.calls.where((x) => x.path.endsWith('/payment/initiate')).length;

    test('zalopay rail e2e', () async {
      final api = cust.api;

      // ---------------------------------------------------------------- (a) methods
      _case = 'methods';
      final info = await api.paymentMethods();
      final raw = (cust.rec.calls.last.respBody as Map)['data'] as Map;
      final miList = (raw['methodInfo'] as List).cast<Map>();
      final zpEntry = miList.where((m) => m['method'] == 'zalopay').toList();
      _step('a', 'GET /payment/methods lists zalopay; methodInfo zalopay sandbox:true; fromJson parses it',
          (raw['methods'] as List).contains('zalopay') && zpEntry.length == 1 && zpEntry.first['sandbox'] == true &&
              info.methods.contains('zalopay') && info.isSandbox('zalopay') && !info.isSandbox('momo') && !info.isSandbox('vnpay'),
          http: cust.rec.calls.last.status, detail: {'methods': raw['methods'], 'zalopayEntry': zpEntry.isEmpty ? null : zpEntry.first, 'parsedMethods': info.methods, 'parsedSandbox': info.sandbox.toList()});

      // ---------------------------------------------------------------- (b) initiate
      final (B, total) = await awaitingPayment('ZP-LAB main');
      _step('b0', 'fixture: booking AWAITING_PAYMENT, total >= 10,000, method zalopay',
          total >= 10000 && sql('select payment_method from bookings where id=$B') == 'zalopay',
          detail: {'bookingId': B, 'totalVnd': total});
      expect(total, greaterThanOrEqualTo(10000));

      _case = 'initiate';
      final t0 = DateTime.now();
      final n0 = initiateCalls();
      final r1 = await ledger.run('zp-direct:$B', (key) => api.initiatePayment(B, idempotencyKey: key));
      final t1 = DateTime.now();
      final payUri = Uri.tryParse(r1.payUrl ?? '');
      final exp = r1.expiry;
      final expDelta = exp?.difference(t1).inSeconds;
      _step('b1', 'initiate -> kind ok', r1.kind == 'ok' && r1.method == 'zalopay', http: cust.rec.calls.last.status,
          detail: {'kind': r1.kind, 'method': r1.method, 'providerTxId': r1.providerTxId});
      _step('b2', 'payUrl host qcgateway.zalopay.vn and PayFlowController.isOpenablePayUrl', payUri?.host == 'qcgateway.zalopay.vn' && PayFlowController.isOpenablePayUrl(r1.payUrl),
          detail: {'host': payUri?.host, 'scheme': payUri?.scheme, 'isOpenable': PayFlowController.isOpenablePayUrl(r1.payUrl)});
      _step('b3', 'deeplink == payUrl and isOpenableDeeplink', r1.deeplink != null && r1.deeplink == r1.payUrl && PayFlowController.isOpenableDeeplink(r1.deeplink),
          detail: {'equal': r1.deeplink == r1.payUrl, 'isOpenable': PayFlowController.isOpenableDeeplink(r1.deeplink), 'deeplinkNull': r1.deeplink == null});
      final qr = r1.qrCodeUrl;
      _step('b4', 'qrCodeUrl is a non-URL EMVCo string (starts 000201)', qr != null && qr.startsWith('000201') && Uri.tryParse(qr)?.hasScheme != true,
          detail: {'prefix': qr?.substring(0, qr.length < 12 ? qr.length : 12), 'length': qr?.length});
      _step('b5', 'expiresAt ~ now + 30 min (+-2 min)', expDelta != null && (expDelta - 1800).abs() <= 120,
          detail: {'secondsFromNow': expDelta, 'expiresAt': r1.expiresAt});
      _step('b6', 'sandbox == true', r1.sandbox == true, detail: {'sandbox': r1.sandbox});
      expect(r1.providerTxId, isNotEmpty);
      final txn = r1.providerTxId!;
      final dbRow = _rows("select method, status, amount_vnd::bigint, provider_tx_id from payments where booking_id=$B and provider_tx_id='$txn'");
      _step('b7', 'payments row: method zalopay, pending, amount == booking total, app_trans_id yymmdd_k<booking>_<n>',
          dbRow.length == 1 && dbRow[0][0] == 'zalopay' && dbRow[0][1] == 'pending' && int.parse(dbRow[0][2]) == total && RegExp('^\\d{6}_k${B}_\\d+\$').hasMatch(txn),
          detail: {'row': dbRow, 'appTransId': txn});
      expect(DateTime.now().difference(t0).inSeconds, lessThan(60));

      // PayFlowController (the app's real pay button controller): opens the deeplink via the launcher
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
      await container.read(payFlowProvider(B).notifier).pay();
      final st = container.read(payFlowProvider(B));
      _step('b8', 'PayFlowController.pay(): launches the https qcgateway link, phase awaiting, sandbox flag surfaced',
          launched.length == 1 && launched.first.host == 'qcgateway.zalopay.vn' && st.phase == PayPhase.awaiting && st.sandbox == true,
          detail: {'launched': launched.length, 'host': launched.isEmpty ? null : launched.first.host, 'phase': st.phase.name, 'sandbox': st.sandbox});
      // flow already used a P6 reuse: still the same txn
      final payRowsAfterFlow = sqlInt("select count(*) from payments where booking_id=$B and method='zalopay' and provider_tx_id not like 'kyco-%'");

      // ---------------------------------------------------------------- (c) replay
      _case = 'replay';
      final k = uuidV4();
      final ra = await api.initiatePayment(B, idempotencyKey: k);
      final rb = await api.initiatePayment(B, idempotencyKey: k);
      final hdr = cust.rec.calls.where((x) => x.path.endsWith('/payment/initiate')).last.replayed;
      _step('c1', 'same key twice -> identical payUrl + providerTxId (idempotent-replayed header)',
          ra.payUrl == rb.payUrl && ra.providerTxId == rb.providerTxId && ra.providerTxId == txn && hdr == 'true',
          detail: {'samePayUrl': ra.payUrl == rb.payUrl, 'sameTxn': ra.providerTxId == rb.providerTxId, 'replayedHeader': hdr});
      final rn = await api.initiatePayment(B, idempotencyKey: uuidV4());
      final zpRows = sqlInt("select count(*) from payments where booking_id=$B and method='zalopay' and provider_tx_id not like 'kyco-%'");
      final livePending = sqlInt("select count(*) from payments where booking_id=$B and method='zalopay' and status='pending' and provider_tx_id not like 'kyco-%'");
      _step('c2', 'NEW key inside the window -> same payUrl + txn (P6), no second create (1 zalopay row, 1 pending)',
          rn.payUrl == r1.payUrl && rn.providerTxId == txn && zpRows == 1 && livePending == 1 && payRowsAfterFlow == 1,
          detail: {'samePayUrl': rn.payUrl == r1.payUrl, 'sameTxn': rn.providerTxId == txn, 'zalopayRows': zpRows, 'pending': livePending, 'rowsAfterPayFlow': payRowsAfterFlow});
      final before = initiateCalls();
      final fp = 'dbl:$B';
      final futs = await Future.wait([
        ledger.run(fp, (key) => api.initiatePayment(B, idempotencyKey: key)),
        ledger.run(fp, (key) => api.initiatePayment(B, idempotencyKey: key)),
      ]);
      final sent = initiateCalls() - before;
      _step('c3', 'double tap through ledger.run concurrently -> ONE request on the wire, both get the same result',
          sent == 1 && futs[0].providerTxId == futs[1].providerTxId && futs[0].providerTxId == txn, detail: {'requestsSent': sent, 'sameTxn': futs[0].providerTxId == futs[1].providerTxId});
      expect(n0, lessThan(initiateCalls()));

      // ---------------------------------------------------------------- (d) callback
      _case = 'callback';
      final s0 = await api.paymentStatus(B);
      _step('d0', 'payment-status before callback is not paid', !s0.serverSaysPaid, http: cust.rec.calls.last.status, detail: {'status': s0.status});
      // bad MAC on the UNPAID booking: rejected, nothing paid
      final bad0 = await _callback(txn, total, tamperMac: true);
      final stillPending = sql("select status from payments where booking_id=$B and provider_tx_id='$txn'");
      _step('d1', 'bad MAC on the unpaid booking -> rejected (return_code 2), payment stays pending',
          bad0.body['return_code'] == 2 && stillPending == 'pending' && sql('select status from bookings where id=$B') == 'AWAITING_PAYMENT',
          http: bad0.status, detail: {'body': bad0.body, 'paymentStatus': stillPending});
      // tampered data with the mac of the original
      final okData = await _callback(txn, total + 1000, dataOverrideAfterSign: '{"app_trans_id":"$txn","amount":$total}');
      _step('d1b', 'data swapped after signing (mac over other data) -> rejected, still pending',
          okData.body['return_code'] == 2 && sql("select status from payments where booking_id=$B and provider_tx_id='$txn'") == 'pending',
          http: okData.status, detail: {'body': okData.body});

      final ledBefore = _ledger(B);
      final good = await _callback(txn, total);
      _step('d2', 'correctly signed callback -> 200 ack return_code 1', good.status == 200 && good.body['return_code'] == 1, http: good.status, detail: {'body': good.body});
      final outcome = await pollPaymentStatus(() => api.paymentStatus(B), delays: const [Duration(milliseconds: 500), Duration(milliseconds: 500), Duration(milliseconds: 500), Duration(milliseconds: 1000)]);
      await container.read(payFlowProvider(B).notifier).check();
      final phase2 = container.read(payFlowProvider(B)).phase;
      final bst = sql('select status from bookings where id=$B');
      final ps = await api.paymentStatus(B);
      _step('d3', 'poll payment-status -> paid; PayFlow phase paid; booking SETTLED',
          outcome == PaymentPollOutcome.paid && phase2 == PayPhase.paid && ps.serverSaysPaid && bst == 'SETTLED',
          http: cust.rec.calls.last.status, detail: {'poll': outcome.name, 'phase': phase2.name, 'bookingStatus': bst, 'paymentStatus': ps.status});
      final led1 = _ledger(B);
      int payIn(Map<String, dynamic> l) => (l['walletTransactions'] as List).where((t) => t['wallet'] == 'kyco_clearing:0' && t['reason'] == 'payment_in').length;
      final paidRows1 = (led1['payments'] as List).where((p) => p['status'] == 'paid').length;
      _step('d3b', 'exactly one paid payments row (zalopay) and one payment_in after the first callback',
          paidRows1 == 1 && payIn(led1) == 1 && (led1['payments'] as List).any((p) => p['status'] == 'paid' && p['method'] == 'zalopay'),
          detail: {'paidRows': paidRows1, 'paymentIn': payIn(led1), 'payIn-before': payIn(ledBefore)});

      final dup = await _callback(txn, total);
      final led2 = _ledger(B);
      _step('d4', 'duplicate callback acked (return_code 1), no second payment_in / ledger row',
          dup.status == 200 && dup.body['return_code'] == 1 && payIn(led2) == 1 &&
              (led2['walletTransactions'] as List).length == (led1['walletTransactions'] as List).length &&
              (led2['payments'] as List).where((p) => p['status'] == 'paid').length == 1,
          http: dup.status, detail: {'body': dup.body, 'walletTxBefore': (led1['walletTransactions'] as List).length, 'walletTxAfter': (led2['walletTransactions'] as List).length});
      // second duplicate after dropping the redis fast-path key: must be stopped by the durable DB claim
      final del = await Process.run('docker', ['exec', 'kyco-redis', 'redis-cli', 'DEL', 'webhook:zalopay:$txn']);
      final dup2 = await _callback(txn, total);
      final led2b = _ledger(B);
      _step('d4b', 'duplicate callback with the Redis claim removed -> DB claim still blocks a second payment_in',
          dup2.body['return_code'] == 1 && payIn(led2b) == 1 && (led2b['walletTransactions'] as List).length == (led1['walletTransactions'] as List).length &&
              (led2b['payments'] as List).where((p) => p['status'] == 'paid').length == 1,
          http: dup2.status, detail: {'body': dup2.body, 'redisDel': '${del.stdout}'.trim(), 'paymentIn': payIn(led2b), 'paidRows': (led2b['payments'] as List).where((p) => p['status'] == 'paid').length});
      final bad1 = await _callback(txn, total, tamperMac: true);
      final led3 = _ledger(B);
      _step('d5', 'bad MAC after paid -> rejected (return_code 2); booking stays paid exactly once',
          bad1.body['return_code'] == 2 && sql('select status from bookings where id=$B') == 'SETTLED' && (led3['payments'] as List).where((p) => p['status'] == 'paid').length == 1 && payIn(led3) == 1,
          http: bad1.status, detail: {'body': bad1.body});

      // ---------------------------------------------------------------- (e) ledger 80/20
      final tx = led3['walletTransactions'] as List;
      int sumOf(String wallet, String reason) => tx.where((t) => t['wallet'] == wallet && t['reason'] == reason).fold<int>(0, (a, t) => a + (t['amountVnd'] as int) * (t['type'] == 'credit' ? 1 : -1));
      final taskerNet = sumOf('tasker:1', 'tasker_earning');
      final commission = sumOf('kyco_revenue:0', 'commission');
      final sweep = -sumOf('kyco_revenue:0', 'insurance_sweep');
      final insuranceIn = sumOf('kyco_insurance:0', 'insurance_sweep');
      final clearingIn = sumOf('kyco_clearing:0', 'payment_in');
      final clearingOut = -sumOf('kyco_clearing:0', 'settlement');
      final defaultBp = sqlInt("select platform_rate_bp from commission_rules where scope_kind='default' and is_active limit 1");
      final bp = defaultBp == 0 ? 2000 : defaultBp;
      final expFee = (total * bp / 10000).round();
      final expTasker = total - expFee;
      final expSweep = [(total * 50) ~/ 10000, expFee ~/ 2].reduce((a, b) => a < b ? a : b);
      _step('e', '80/20 ledger from the zalopay payment: tasker 80%, kyco 20% commission, insurance sweep, clearing in == out == total',
          taskerNet == expTasker && commission == expFee && clearingIn == total && clearingOut == total && sweep == expSweep && insuranceIn == expSweep && (led3['taskerPayouts'] as List).length == 1,
          detail: {
            'totalVnd': total, 'rateBp': bp,
            'expected': {'taskerNet': expTasker, 'commission': expFee, 'insuranceSweep': expSweep},
            'actual': {'taskerEarning': taskerNet, 'commission': commission, 'sweepOutOfRevenue': sweep, 'insuranceIn': insuranceIn, 'clearingIn': clearingIn, 'clearingOut': clearingOut},
            'taskerPayouts': led3['taskerPayouts'],
          });

      // ---------------------------------------------------------------- kB2: bad-MAC pending, race, expiry (g)
      final (kB2, total2) = await awaitingPayment('ZP-LAB expiry');
      _case = 'initiate-b2';
      final k2a = uuidV4();
      final race = await Future.wait([
        api.initiatePayment(kB2, idempotencyKey: k2a),
        api.initiatePayment(kB2, idempotencyKey: uuidV4()),
        api.initiatePayment(kB2, idempotencyKey: uuidV4()),
      ].map((f) => f.then<Object>((v) => v, onError: (Object e) => e)));
      final okRes = race.whereType<PaymentInitiateResult>().toList();
      final txns = okRes.map((r) => r.providerTxId).toSet();
      final liveIntents = sqlInt("select count(*) from payments where booking_id=$kB2 and method='zalopay' and status='pending' and provider_tx_id is not null and provider_tx_id not like 'kyco-%'");
      _step('c4', 'three concurrent initiates with DIFFERENT keys -> one live intent, all successful answers carry the same txn',
          okRes.isNotEmpty && txns.length == 1 && liveIntents == 1,
          detail: {'okCount': okRes.length, 'errors': race.whereType<ApiException>().map((e) => '${e.status} ${e.code}').toList(), 'distinctTxn': txns.length, 'liveIntents': liveIntents,
            'note': 'a 409/in-progress loser is acceptable; two live intents is not'});
      final tx2a = okRes.first.providerTxId!;
      // expire it (lab row, by id) and initiate with a fresh key
      final payId = sqlInt("select id from payments where booking_id=$kB2 and provider_tx_id='$tx2a'");
      sql("update payments set url_created_at = now() - interval '31 minutes' where id=$payId");
      _case = 'initiate-after-expiry';
      final rex = await api.initiatePayment(kB2, idempotencyKey: uuidV4());
      final oldStatus = sql('select status from payments where id=$payId');
      final rowsB2 = sqlInt("select count(*) from payments where booking_id=$kB2 and method='zalopay' and provider_tx_id not like 'kyco-%'");
      _step('g', 'expired intent (url_created_at -31 min): a fresh key creates a NEW app_trans_id (attempt+1), old row retired',
          rex.kind == 'ok' && rex.providerTxId != tx2a && rex.payUrl != okRes.first.payUrl && PayFlowController.isOpenablePayUrl(rex.payUrl) && oldStatus != 'pending' && rowsB2 == 2,
          http: cust.rec.calls.last.status, detail: {'oldTxn': tx2a, 'newTxn': rex.providerTxId, 'samePayUrl': rex.payUrl == okRes.first.payUrl, 'oldRowStatus': oldStatus, 'zalopayRows': rowsB2, 'newExpiresAt': rex.expiresAt});

      // ---------------------------------------------------------------- (f) negatives
      _case = 'neg';
      // f1: amount below 10,000
      final (kB3, _) = await awaitingPayment('ZP-LAB min amount');
      sql('update bookings set total_vnd=9000 where id=$kB3');
      ApiException? minErr;
      PaymentInitiateResult? minOk;
      try {
        minOk = await api.initiatePayment(kB3, idempotencyKey: uuidV4());
      } on ApiException catch (e) {
        minErr = e;
      }
      final gw3 = sqlInt("select count(*) from payments where booking_id=$kB3 and method='zalopay' and provider_tx_id is not null and provider_tx_id not like 'kyco-%'");
      _step('f1', 'initiate with total 9,000 (< 10,000) -> server refusal (4xx, payment_method field), no gateway intent',
          minErr != null && (minErr.status ?? 0) >= 400 && (minErr.status ?? 0) < 500 && gw3 == 0,
          http: minErr?.status, detail: {'code': minErr?.code, 'fields': minErr?.fields, 'message': minErr?.message, 'okKind': minOk?.kind, 'gatewayIntents': gw3});

      // f2: not AWAITING_PAYMENT -> 409
      final (kB4, _) = await awaitingPayment('ZP-LAB wrong status');
      sql("update bookings set status='AWAITING_CUSTOMER_CONFIRMATION' where id=$kB4");
      ApiException? wrong;
      try {
        await api.initiatePayment(kB4, idempotencyKey: uuidV4());
      } on ApiException catch (e) {
        wrong = e;
      }
      _step('f2', 'initiate when not AWAITING_PAYMENT -> 409 PAYMENT_NOT_ALLOWED_IN_STATUS',
          wrong?.status == 409 && wrong?.code == 'PAYMENT_NOT_ALLOWED_IN_STATUS', http: wrong?.status, detail: {'code': wrong?.code});
      sql("update bookings set status='AWAITING_PAYMENT' where id=$kB4");

      // f3: flag OFF
      final (kB5, _) = await awaitingPayment('ZP-LAB flag off');
      String off = '';
      var methodsOff = <String>[];
      ApiException? offErr;
      PaymentInitiateResult? offOk;
      final intentsBefore = sqlInt("select count(*) from payments where booking_id=$kB5 and method='zalopay' and provider_tx_id is not null and provider_tx_id not like 'kyco-%'");
      try {
        off = _flag('off');
        _case = 'flag-off';
        methodsOff = (await api.paymentMethods()).methods;
        try {
          offOk = await api.initiatePayment(kB5, idempotencyKey: uuidV4());
        } on ApiException catch (e) {
          offErr = e;
        }
        // an already-issued intent (kB2's live one) is not re-served either
        ApiException? reserveErr;
        try {
          await api.initiatePayment(kB2, idempotencyKey: uuidV4());
        } on ApiException catch (e) {
          reserveErr = e;
        }
        final intentsAfter = sqlInt("select count(*) from payments where booking_id=$kB5 and method='zalopay' and provider_tx_id is not null and provider_tx_id not like 'kyco-%'");
        _step('f3', 'flag OFF: zalopay absent from methods, initiate refused (no gateway intent), live intent not re-served',
            !methodsOff.contains('zalopay') && methodsOff.contains('momo') && offErr != null && (offErr.status ?? 0) >= 400 && (offErr.status ?? 0) < 500 && intentsAfter == intentsBefore && reserveErr != null,
            http: offErr?.status, detail: {'flagRestart': off, 'methodsOff': methodsOff, 'initiateCode': offErr?.code, 'initiateFields': offErr?.fields, 'okKind': offOk?.kind, 'reserveCode': '${reserveErr?.status} ${reserveErr?.code}'});
      } finally {
        final on = _flag('on');
        _case = 'flag-on';
        final m = await api.paymentMethods();
        _step('f4', 'flag turned back ON: zalopay listed again', m.methods.contains('zalopay') && m.isSandbox('zalopay'), detail: {'flagRestart': on, 'methods': m.methods});
      }
      // after the flag is back, the booking can be initiated normally
      final r5 = await api.initiatePayment(kB5, idempotencyKey: uuidV4());
      _step('f5', 'flag ON again: previously refused booking now initiates ok (zalopay https link)', r5.kind == 'ok' && PayFlowController.isOpenablePayUrl(r5.payUrl), detail: {'kind': r5.kind});
      expect(total2, greaterThan(0));
    }, timeout: const Timeout(Duration(minutes: 18)));
  });
}
