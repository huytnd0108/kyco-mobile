// MQA-70 replay (recreated): the app's IdempotencyLedger driven against the
// REAL KycoApi + lab backend (release-d 96a4b8d8) with injected "lost
// response" failures. QA only; lab only.
//
// Scenarios: S1 tasker job-cancel x2 lost, S2 payout lost response, S3 two
// concurrent ledger.run for one payout, S3b double tap with enough balance for
// two payouts (the ledger now coalesces: exactly 1 row), S4 client killed
// after send then restarted from the persisted key file, S5 payout above
// balance -> 422 key dropped -> corrected amount, S6 customer cancel lost
// response, S7 initiatePayment lost response at AWAITING_PAYMENT.
//
//   flutter test test/live/idempotency_replay_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 \
//     --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
@Tags(['live'])
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/models.dart';

import 'live_support_rd.dart';

String get _resultPath => '$kQaRoot/out/mobile/MQA70-replay-rd.result.json';
String get _callsPath => '$kQaRoot/out/mobile/contract-calls-replay-rd.jsonl';

class FileKeyStore implements PendingKeyStore {
  FileKeyStore(this.path);
  final String path;
  @override
  Future<String?> read() async => File(path).existsSync() ? File(path).readAsStringSync() : null;
  @override
  Future<void> write(String? json) async {
    if (json == null) {
      if (File(path).existsSync()) File(path).deleteSync();
    } else {
      File(path).writeAsStringSync(json);
    }
  }
}

final List<Map<String, dynamic>> _scenarios = [];
String _case = '';

int _idem() => sqlInt('select count(*) from api_idempotency_keys');
int _payouts() => sqlInt('select count(*) from payout_requests where tasker_id=1');

/// The cancel routes allow 3 requests per 60 s window per user (profiles.signup). Start each cancel scenario at the top of a fresh
/// minute so back-to-back runs / scenarios never share a window (a retried cancel is up to 3 calls).
Future<void> _freshCancelWindow() async {
  final now = DateTime.now();
  final wait = (60 - now.second) + 2;
  if (now.second > 6 || now.second < 0) await Future<void>.delayed(Duration(seconds: wait));
}

void _setBalance(int v) {
  final has = sqlInt("select count(*) from wallets where owner_type='tasker' and owner_id=1");
  if (has == 0) {
    sql("insert into wallets (owner_type, owner_id, balance_vnd, currency) values ('tasker', 1, $v, 'VND')");
  } else {
    sql("update wallets set balance_vnd=$v where owner_type='tasker' and owner_id=1");
  }
}

Map<String, dynamic> _callsSummary(List<Call> calls) => {
      'n': calls.length,
      'keys': calls.map((c) => mask(c.idemKey)).toList(),
      'statuses': calls.map((c) => c.status).toList(),
      'replayed': calls.where((c) => c.replayed == 'true').length,
    };

void _record(String id, String name, bool ok, Map<String, dynamic> expected, Map<String, dynamic> actual, List<Call> calls, {bool diagnostic = false}) {
  _scenarios.add({
    'id': id, 'name': name, 'ok': ok, if (diagnostic) 'diagnostic': true,
    'expected': expected, 'actual': actual,
    'calls': [for (final c in calls) {'path': c.path, 'status': c.status, 'key': mask(c.idemKey), 'replayedHeader': c.replayed, 'traceId': c.traceId, if (c.respBody is Map && (c.respBody as Map)['ok'] == false) 'code': (c.respBody as Map)['code'], if (c.respBody is Map && (c.respBody as Map)['ok'] == false) 'message': (c.respBody as Map)['message']}],
  });
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  $id $name  expected=${jsonEncode(expected)} actual=${jsonEncode(actual)}');
}

void main() {
  group('MQA-70 replay (release-d)', skip: kLive ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    late LiveClient cust;
    late LiveClient tasker;
    int? svc;
    final snap = <String, dynamic>{};
    var startedAt = '';

    Future<int> fixtureBooking({String status = 'CONFIRMED', bool assign = true}) async {
      final t = DateTime.now().add(const Duration(days: 1));
      final c = await cust.api.createBooking(BookingDraft(
          serviceId: svc!, serviceName: 'MQA70', basePriceVnd: 0, scheduledDate: ymd(t), scheduledTime: randomTime(),
          wardName: 'Quận 1', neighborhood: 'Bến Nghé', addressLine: '12 Lê Lợi', notes: 'MQA-70 replay'));
      final job = sqlInt('select id from jobs where booking_id=${c.bookingId} order by id desc limit 1');
      if (assign) sql("update jobs set tasker_id=1, status='active', started_at=now() where id=$job");
      sql("update bookings set status='$status' where id=${c.bookingId}");
      return c.bookingId;
    }

    setUpAll(() async {
      guardLab();
      shiftCancelQuota();
      Directory('$kQaRoot/out/mobile').createSync(recursive: true);
      final f = File(_callsPath);
      if (f.existsSync()) f.deleteSync();
      startedAt = DateTime.now().toUtc().toIso8601String();
      snap['bank'] = sql('select coalesce(bank_code,\'~NULL~\') ||\'|\'|| coalesce(bank_account_number,\'~NULL~\') ||\'|\'|| coalesce(bank_account_holder,\'~NULL~\') from taskers where id=1');
      snap['hasWallet'] = sqlInt("select count(*) from wallets where owner_type='tasker' and owner_id=1");
      snap['walletBal'] = snap['hasWallet'] == 1 ? sql("select balance_vnd::bigint from wallets where owner_type='tasker' and owner_id=1") : '~NONE~';
      snap['maxPayout'] = sqlInt('select coalesce(max(id),0) from payout_requests');
      snap['maxWt'] = sqlInt('select coalesce(max(id),0) from wallet_transactions');
      snap['maxNotif'] = sqlInt('select coalesce(max(id),0) from notifications');
      snap['penalty'] = sql('select penalty_score from taskers where id=1');
      sql("update taskers set bank_code='VCB', bank_account_number='0123456789', bank_account_holder='QA REPLAY' where id=1");
      cust = await loginClient(kCustEmail, kCustPw, jsonlPath: _callsPath, caseName: () => _case);
      tasker = await loginClient(kTaskerEmail, kTaskerPw, jsonlPath: _callsPath, caseName: () => _case);
      svc = (await cust.api.services()).items.first.id;
      // fresh step-up grant for payouts (password)
      await tasker.api.stepUp(password: kTaskerPw);
    });

    tearDownAll(() {
      sql('delete from payout_requests where tasker_id=1 and id > ${snap['maxPayout']}');
      sql('delete from wallet_transactions where id > ${snap['maxWt']}');
      sql('delete from notifications where id > ${snap['maxNotif']}');
      if (snap['hasWallet'] == 0) {
        sql("delete from wallets where owner_type='tasker' and owner_id=1");
      } else {
        sql("update wallets set balance_vnd=${snap['walletBal']} where owner_type='tasker' and owner_id=1");
      }
      final b = (snap['bank'] as String).split('|');
      String lit(String s) => s == '~NULL~' ? 'null' : "'${s.replaceAll("'", "''")}'";
      sql('update taskers set bank_code=${lit(b[0])}, bank_account_number=${lit(b[1])}, bank_account_holder=${lit(b[2])}, penalty_score=${snap['penalty']} where id=1');
      final restored = sql('select coalesce(bank_code,\'~NULL~\') ||\'|\'|| coalesce(bank_account_number,\'~NULL~\') ||\'|\'|| coalesce(bank_account_holder,\'~NULL~\') from taskers where id=1') == snap['bank'] &&
          sqlInt("select count(*) from wallets where owner_type='tasker' and owner_id=1") == snap['hasWallet'] &&
          (snap['hasWallet'] == 0 || sql("select balance_vnd::bigint from wallets where owner_type='tasker' and owner_id=1") == snap['walletBal']);
      final fail = _scenarios.where((s) => s['ok'] != true && s['diagnostic'] != true).length;
      final diagFail = _scenarios.where((s) => s['ok'] != true && s['diagnostic'] == true).length;
      writeJson(_resultPath, {
        'pkg': 'MQA-70-replay-rd',
        'startedAt': startedAt,
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'labSha': '96a4b8d8',
        'mobile': 'kmob-wt/replay (uncommitted waves; IdempotencyLedger coalescing in place)',
        'status': fail == 0 && diagFail == 0 ? 'PASS' : 'FAIL',
        'counts': {'pass': _scenarios.where((s) => s['ok'] == true).length, 'fail': fail + diagFail},
        'scenarios': _scenarios,
        'restored': {'ok': restored, 'bank': snap['bank'], 'wallet': snap['walletBal'], 'deleted': 'payout_requests id>${snap['maxPayout']} (tasker 1), wallet_transactions id>${snap['maxWt']}, notifications id>${snap['maxNotif']}'},
        'notes': 'Keys masked (first 8 chars). Fixture bookings stay in the lab DB. api_idempotency_keys rows are left (audit trail).',
      });
      stdout.writeln('MQA70-replay-rd: ${_scenarios.where((s) => s['ok'] == true).length}/${_scenarios.length} restored=$restored -> $_resultPath');
    });

    test('S1 tasker job cancel retried (lost response twice)', () async {
      final b = await fixtureBooking();
      final job = sqlInt('select id from jobs where booking_id=$b order by id desc limit 1');
      final ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 3);
      final path = '/api/v1/tasker/jobs/$job/cancel';
      await _freshCancelWindow();
      final canc0 = sqlInt('select count(*) from cancellations where booking_id=$b');
      final idem0 = _idem();
      final n0 = tasker.rec.calls.length;
      tasker.rec.dropPaths[path] = 2;
      _case = 'S1';
      var attempts = 0;
      ApiException? last;
      for (; attempts < 5; attempts++) {
        try {
          await ledger.run('job-cancel:$job:sick:${IdempotencyLedger.textTag('QA')}',
              (key) => tasker.api.cancelJob(job, reasonCode: 'sick', reasonText: 'QA', idempotencyKey: key));
          last = null;
          break;
        } on ApiException catch (e) {
          last = e;
        }
      }
      final calls = tasker.rec.calls.sublist(n0).where((c) => c.path == path).toList();
      final keys = calls.map((c) => c.idemKey).toSet();
      final canc = sqlInt('select count(*) from cancellations where booking_id=$b') - canc0;
      final ok = last == null && canc == 1 && _idem() - idem0 == 1 && keys.length == 1 && calls.where((c) => c.replayed == 'true').isNotEmpty;
      _record('S1', 'tasker job cancel retried (lost response twice)', ok,
          {'cancellations': 1, 'idempotencyRows': 1, 'sameKey': true, 'replayedResponses': '>=1'},
          {'cancellationsDelta': canc, 'idempotencyDelta': _idem() - idem0, 'attempts': attempts + 1, ..._callsSummary(calls), 'bookingId': b, 'jobId': job, 'bookingStatus': sql('select status from bookings where id=$b')}, calls);
    });

    test('S2 payout retried (lost response)', () async {
      _setBalance(1000000);
      final ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 3);
      const path = '/api/v1/tasker/payouts';
      final p0 = _payouts(), idem0 = _idem(), n0 = tasker.rec.calls.length;
      tasker.rec.dropPaths[path] = 1;
      _case = 'S2';
      ApiException? last;
      PayoutRequestResult? res;
      for (var i = 0; i < 4; i++) {
        try {
          res = await ledger.run('payout:100000', (key) => tasker.api.requestPayout(100000, idempotencyKey: key));
          last = null;
          break;
        } on ApiException catch (e) {
          last = e;
        }
      }
      final calls = tasker.rec.calls.sublist(n0).where((c) => c.path == path && c.method == 'POST').toList();
      final ok = last == null && _payouts() - p0 == 1 && _idem() - idem0 == 1 && calls.map((c) => c.idemKey).toSet().length == 1 && calls.any((c) => c.replayed == 'true');
      _record('S2', 'payout 100000 retried (lost response)', ok, {'payout_requests': 1, 'idempotencyRows': 1, 'replayedResponses': '>=1'},
          {'payoutDelta': _payouts() - p0, 'idempotencyDelta': _idem() - idem0, ..._callsSummary(calls), 'payoutId': res?.id}, calls);
    });

    test('S3 two concurrent ledger.run for the same payout', () async {
      _setBalance(1000000);
      final ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 3);
      final p0 = _payouts(), idem0 = _idem(), n0 = tasker.rec.calls.length;
      _case = 'S3';
      final outs = await Future.wait([
        for (var i = 0; i < 2; i++)
          ledger.run('payout:100000', (key) => tasker.api.requestPayout(100000, idempotencyKey: key)).then((v) => 'ok id=${v.id}').catchError((Object e) => 'err $e'),
      ]);
      final calls = tasker.rec.calls.sublist(n0).where((c) => c.path.endsWith('/tasker/payouts') && c.method == 'POST').toList();
      final ok = _payouts() - p0 == 1 && _idem() - idem0 == 1 && calls.map((c) => c.idemKey).toSet().length == 1 && !outs.any((o) => o.startsWith('err'));
      _record('S3', 'two concurrent ledger.run for the same payout', ok, {'payout_requests': 1, 'idempotencyRows': 1, 'sameKey': true, 'bothCallersOk': true},
          {'payoutDelta': _payouts() - p0, 'idempotencyDelta': _idem() - idem0, 'outcomes': outs, ..._callsSummary(calls)}, calls);
    });

    test('S3b double tap with balance for two payouts (coalesced)', () async {
      _setBalance(200000);
      final ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 3);
      final p0 = _payouts(), idem0 = _idem(), n0 = tasker.rec.calls.length;
      _case = 'S3b';
      Future<String> tap() => ledger
          .run('payout:100000', (key) => tasker.api.requestPayout(100000, idempotencyKey: key))
          .then((v) => 'ok id=${v.id}')
          .catchError((Object e) => 'err $e');
      final first = tap();
      final second = tap(); // same instant
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final third = tap(); // loser re-taps while the winner is still in flight
      final outs = await Future.wait([first, second, third]);
      final rowsAfterPair = _payouts() - p0;
      final calls = tasker.rec.calls.sublist(n0).where((c) => c.path.endsWith('/tasker/payouts') && c.method == 'POST').toList();
      final bal = sql("select balance_vnd::bigint from wallets where owner_type='tasker' and owner_id=1");
      final ok = rowsAfterPair == 1 && _idem() - idem0 == 1 && !outs.any((o) => o.startsWith('err'));
      _record('S3b', 'double/triple tap, balance covers two payouts: exactly 1 row (ledger coalesces)', ok,
          {'payout_requests': 1, 'idempotencyRows': 1, 'bothCallersOk': true},
          {'rowsAfterTaps': rowsAfterPair, 'payoutDelta': _payouts() - p0, 'idempotencyDelta': _idem() - idem0, 'outcomes': outs, 'walletBalanceAfter': bal, 'httpPosts': calls.length, ..._callsSummary(calls)}, calls);
    });

    test('S4 client killed after send; restart ledger from file; retry', () async {
      _setBalance(1000000);
      final file = '${Directory.systemTemp.path}/mqa70-s4-keys.json';
      if (File(file).existsSync()) File(file).deleteSync();
      final p0 = _payouts(), idem0 = _idem(), n0 = tasker.rec.calls.length;
      const path = '/api/v1/tasker/payouts';
      tasker.rec.dropPaths[path] = 1;
      _case = 'S4';
      String? firstErr;
      final ledger1 = IdempotencyLedger(store: FileKeyStore(file), userId: () => 3);
      try {
        await ledger1.run('payout:100000', (key) => tasker.api.requestPayout(100000, idempotencyKey: key));
      } on ApiException catch (e) {
        firstErr = e.code;
      }
      final persisted = File(file).existsSync();
      final rowsAfterKill = _payouts() - p0;
      // "restart": a brand-new ledger from the same file
      final ledger2 = IdempotencyLedger(store: FileKeyStore(file), userId: () => 3);
      final res = await ledger2.run('payout:100000', (key) => tasker.api.requestPayout(100000, idempotencyKey: key));
      final calls = tasker.rec.calls.sublist(n0).where((c) => c.path == path && c.method == 'POST').toList();
      final ok = firstErr == 'network' && persisted && rowsAfterKill == 1 && _payouts() - p0 == 1 && _idem() - idem0 == 1 &&
          calls.map((c) => c.idemKey).toSet().length == 1 && calls.last.replayed == 'true';
      _record('S4', 'client killed after send; restart ledger from file; retry', ok,
          {'payout_requests': 1, 'idempotencyRows': 1, 'sameKeyAfterRestart': true},
          {'firstError': firstErr, 'keyPersistedInFile': persisted, 'rowsAfterKillBeforeRetry': rowsAfterKill, 'payoutDelta': _payouts() - p0, 'idempotencyDelta': _idem() - idem0, 'payoutId': res.id, ..._callsSummary(calls)}, calls);
      if (File(file).existsSync()) File(file).deleteSync();
    });

    test('S5 payout above balance -> 422, key dropped; corrected amount -> new key', () async {
      _setBalance(100000);
      final ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 3);
      final p0 = _payouts(), idem0 = _idem(), n0 = tasker.rec.calls.length;
      _case = 'S5';
      ApiException? e422;
      try {
        await ledger.run('payout:150000', (key) => tasker.api.requestPayout(150000, idempotencyKey: key));
      } on ApiException catch (e) {
        e422 = e;
      }
      final badKey = tasker.rec.calls.sublist(n0).last.idemKey;
      final rowsAfter422 = _payouts() - p0;
      final fresh = await ledger.keyFor('payout:150000');
      await ledger.forget('payout:150000');
      final good = await ledger.run('payout:100000', (key) => tasker.api.requestPayout(100000, idempotencyKey: key));
      final calls = tasker.rec.calls.sublist(n0).where((c) => c.path.endsWith('/tasker/payouts') && c.method == 'POST').toList();
      final goodKey = calls.last.idemKey;
      final ok = e422?.status == 422 && rowsAfter422 == 0 && _payouts() - p0 == 1 && fresh != badKey && goodKey != badKey;
      _record('S5', 'payout above balance -> 422, key dropped; corrected amount -> new key', ok,
          {'firstStatus': 422, 'rowsAfter422': 0, 'payout_requests': 1, 'newKey': true},
          {'firstStatus': e422?.status, 'fields': e422?.fields, 'rowsAfter422': rowsAfter422, 'payoutDelta': _payouts() - p0, 'idempotencyDelta': _idem() - idem0, 'badKey': mask(badKey), 'freshKeyForSameFp': mask(fresh), 'goodKey': mask(goodKey), 'payoutId': good.id}, calls);
    });

    test('S6 customer cancelBooking retried (lost response)', () async {
      final b = await fixtureBooking(assign: false);
      sql('update bookings set compensation_lock_until=null where id=$b');
      final ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 1);
      final path = '/api/v1/bookings/$b/cancel';
      final canc0 = sqlInt('select count(*) from cancellations where booking_id=$b');
      final idem0 = _idem(), n0 = cust.rec.calls.length;
      cust.rec.dropPaths[path] = 1;
      _case = 'S6';
      final det = await cust.api.bookingDetail(b);
      final code = det.cancelReasons.isNotEmpty ? det.cancelReasons.first.code : 'other';
      await _freshCancelWindow();
      ApiException? last;
      CancelResult? res;
      for (var i = 0; i < 4; i++) {
        try {
          res = await ledger.run('cancel:$b:$code', (key) => cust.api.cancelBooking(b, reasonCode: code, idempotencyKey: key));
          last = null;
          break;
        } on ApiException catch (e) {
          last = e;
        }
      }
      final calls = cust.rec.calls.sublist(n0).where((c) => c.path == path).toList();
      final canc = sqlInt('select count(*) from cancellations where booking_id=$b') - canc0;
      final ok = last == null && canc == 1 && _idem() - idem0 == 1 && calls.any((c) => c.replayed == 'true') && sql('select status from bookings where id=$b') == 'CANCELLED';
      _record('S6', 'customer cancelBooking retried (lost response)', ok, {'cancellations': 1, 'idempotencyRows': 1, 'replayedResponses': '>=1'},
          {'cancellationsDelta': canc, 'idempotencyDelta': _idem() - idem0, 'bookingId': b, 'bookingStatus': sql('select status from bookings where id=$b'), 'cancelResponse': {'fee': res?.feeVnd, 'refund': res?.refundVnd, 'refundStatus': res?.refundStatus}, ..._callsSummary(calls)}, calls);
    });

    test('S7 initiatePayment retried (lost response), AWAITING_PAYMENT', () async {
      final b = await fixtureBooking(status: 'AWAITING_CUSTOMER_CONFIRMATION');
      final job = sqlInt('select id from jobs where booking_id=$b order by id desc limit 1');
      sql("update jobs set status='closed', finished_at=now() where id=$job");
      sql('update bookings set completed_at=now() where id=$b');
      final ledger = IdempotencyLedger(store: MemoryPendingKeyStore(), userId: () => 1);
      _case = 'S7-confirm';
      await ledger.run('confirm:$b:vnpay', (key) => cust.api.confirmCompletion(b, action: 'confirm', paymentMethod: 'vnpay', idempotencyKey: key));
      final path = '/api/v1/payment/initiate';
      final idem0 = _idem(), n0 = cust.rec.calls.length;
      final pay0 = sqlInt('select count(*) from payments where booking_id=$b');
      cust.rec.dropPaths[path] = 1;
      _case = 'S7';
      ApiException? last;
      PaymentInitiateResult? res;
      for (var i = 0; i < 4; i++) {
        try {
          res = await ledger.run('pay-initiate:$b', (key) => cust.api.initiatePayment(b, idempotencyKey: key));
          last = null;
          break;
        } on ApiException catch (e) {
          last = e;
        }
      }
      final calls = cust.rec.calls.sublist(n0).where((c) => c.path == path).toList();
      final pending = sqlInt("select count(*) from payments where booking_id=$b and status='pending' and provider_tx_id not like 'kyco-%'"); // payable intents (confirm-completion also writes a kyco-post-confirm-* placeholder, no payUrl)
      final ok = last == null && pending == 1 && _idem() - idem0 == 1 && res?.kind == 'ok' && calls.map((c) => c.idemKey).toSet().length == 1;
      _record('S7', 'initiatePayment retried (lost response), booking AWAITING_PAYMENT', ok, {'pendingPayments': 1, 'idempotencyRows': 1},
          {'pendingPayments': pending, 'pendingPlaceholderRows': sqlInt("select count(*) from payments where booking_id=$b and status='pending' and provider_tx_id like 'kyco-%'"), 'paymentsDelta': sqlInt('select count(*) from payments where booking_id=$b') - pay0, 'idempotencyDelta': _idem() - idem0, 'kind': res?.kind, 'bookingId': b, ..._callsSummary(calls)}, calls);
      sql("update jobs set status='closed' where booking_id=$b and status in ('pending','open')");
    });
  });
}
