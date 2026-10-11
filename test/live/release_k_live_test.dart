// Release-k (kyco ff6198c3) one-pending-payout verification against the lab on 127.0.0.1:4142. QA only; lab only.
//   flutter test test/live/release_k_live_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 \
//     --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
//
// Real KycoApi + the app's IdempotencyLedger. Row counts come from SQL for every scenario.
// Data changes (restored in tearDownAll): taskers(1).bank_*, wallets(tasker 1) balance, payout_requests /
// wallet_transactions / notifications / api_idempotency_keys / admin_audit rows created during the run.
@Tags(['live'])
@Timeout(Duration(minutes: 40))
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/models.dart';

import 'live_support_rd.dart';

final checks = <Map<String, dynamic>>[];
final notes = <String>[];
final scen = <String, Map<String, dynamic>>{};

void rec(String item, String name, bool ok, String detail) {
  checks.add({'item': item, 'name': name, 'ok': ok, 'detail': detail});
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  [$item] $name -- $detail');
}

String j(Object? o, [int n = 600]) {
  final s = jsonEncode(o);
  return s.length > n ? '${s.substring(0, n)}...' : s;
}

const tid = 1;
const tUser = "(select user_account_id from taskers where id=1)";

int pays() => sqlInt('select count(*) from payout_requests where tasker_id=$tid');
int pendings() => sqlInt("select count(*) from payout_requests where tasker_id=$tid and status='pending'");
int bal() => sqlInt("select balance_vnd::bigint from wallets where owner_type='tasker' and owner_id=$tid");
int txs() => sqlInt("select count(*) from wallet_transactions where wallet_id=(select id from wallets where owner_type='tasker' and owner_id=$tid)");
int idems() => sqlInt('select count(*) from api_idempotency_keys');
Map<String, int> state() => {'payouts': pays(), 'pending': pendings(), 'balance': bal(), 'walletTx': txs(), 'idemKeys': idems()};

Dio raw([String? lang]) => Dio(BaseOptions(baseUrl: kApiBase, validateStatus: (_) => true, headers: {'accept': 'application/json', 'accept-language': ?lang}));

Future<LiveClient> login(String email, String pw) => loginClient(email, pw);

Future<Map<String, dynamic>> walletRaw(LiveClient c, [String lang = 'vi']) async {
  final tok = await c.store.accessToken;
  final r = await raw(lang).get('/tasker/wallet', options: Options(headers: {'authorization': 'Bearer $tok'}));
  return ((r.data as Map)['data'] as Map).cast<String, dynamic>();
}

Future<void> taskerStepUp(LiveClient c) async {
  final s = await c.api.stepUpStatus();
  if (!s.fresh) await c.api.stepUp(password: kTaskerPw);
}

final adminBase = kApiBase.replaceFirst('/api/v1', '/api/admin/v1');
LiveClient? adminC;
Future<LiveClient> admin() async {
  adminC ??= await login('admin@qa.local', 'Admin12345qa');
  final s = await adminC!.api.stepUpStatus();
  if (!s.fresh) await adminC!.api.stepUp(password: 'Admin12345qa');
  return adminC!;
}

Future<Response<dynamic>> adminResolve(int id, String action) async {
  final a = await admin();
  final tok = await a.store.accessToken;
  return Dio(BaseOptions(validateStatus: (_) => true, headers: {'accept': 'application/json'})).post('$adminBase/payouts/$id',
      data: {'action': action, 'note': 'QA release-k'},
      options: Options(headers: {'authorization': 'Bearer $tok', 'Idempotency-Key': 'qa-k-${DateTime.now().microsecondsSinceEpoch}-$id-$action'}));
}

class Snap {
  late String bank, wallets, tasker;
  late int maxTx, maxPay, maxNotif, maxIdem, maxAudit;
}

final snap = Snap();

void main() {
  group('release-k live verification', skip: kLive ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    late LiveClient t;
    late IdempotencyLedger ledger;
    int? p1, p2;
    String? key1;

    setUpAll(() {
      guardLab();
      Directory('$kQaRoot/out/lab').createSync(recursive: true);
      snap.bank = sql("select coalesce(bank_code,'~NULL~')||'|'||coalesce(bank_account_number,'~NULL~')||'|'||coalesce(bank_account_holder,'~NULL~') from taskers where id=$tid");
      snap.wallets = sql("select id||'|'||balance_vnd from wallets order by id").replaceAll('\n', ';');
      snap.tasker = sql("select penalty_score||'|'||is_banned||'|'||cancellations_30d||'|'||consecutive_cancels||'|'||coalesce(suspended_until::text,'~')||'|'||trust_score from taskers where id=$tid");
      snap.maxTx = sqlInt('select coalesce(max(id),0) from wallet_transactions');
      snap.maxPay = sqlInt('select coalesce(max(id),0) from payout_requests');
      snap.maxNotif = sqlInt('select coalesce(max(id),0) from notifications');
      snap.maxIdem = sqlInt('select coalesce(max(id),0) from api_idempotency_keys');
      snap.maxAudit = sqlInt('select coalesce(max(id),0) from admin_audit');
      stdout.writeln('SNAP bank=${snap.bank} wallets=${snap.wallets} tasker=${snap.tasker}');
      sql("update taskers set bank_code='VCB', bank_account_number='1234567890', bank_account_holder='QA RELEASE K' where id=$tid");
      sql("update wallets set balance_vnd=500000 where owner_type='tasker' and owner_id=$tid");
      if (pendings() != 0) throw StateError('tasker 1 already has a pending payout; abort');
    });

    tearDownAll(() {
      sql('delete from wallet_transactions where id>${snap.maxTx}');
      sql('delete from payout_requests where id>${snap.maxPay}');
      sql('delete from notifications where id>${snap.maxNotif}');
      sql('delete from api_idempotency_keys where id>${snap.maxIdem}');
      for (final w in snap.wallets.split(';')) {
        final p = w.split('|');
        sql('update wallets set balance_vnd=${p[1]} where id=${p[0]}');
      }
      final b = snap.bank.split('|');
      String lit(String v) => v == '~NULL~' ? 'NULL' : "'$v'";
      sql('update taskers set bank_code=${lit(b[0])}, bank_account_number=${lit(b[1])}, bank_account_holder=${lit(b[2])} where id=$tid');
      final restored = sql("select id||'|'||balance_vnd from wallets order by id").replaceAll('\n', ';') == snap.wallets;
      final tk = sql("select penalty_score||'|'||is_banned||'|'||cancellations_30d||'|'||consecutive_cancels||'|'||coalesce(suspended_until::text,'~')||'|'||trust_score from taskers where id=$tid");
      final fails = checks.where((c) => c['ok'] != true).length;
      writeJson('$kQaRoot/out/lab/K-live.result.json', {
        'pkg': 'release-k-live',
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'pass': checks.length - fails,
        'fail': fails,
        'restored': {'wallets': restored, 'bank': snap.bank, 'taskerCountersUnchanged': tk == snap.tasker, 'maxTx': snap.maxTx, 'maxPay': snap.maxPay},
        'scenarios': scen,
        'notes': notes,
        'checks': checks,
      });
      stdout.writeln('release-k-live: pass=${checks.length - fails} fail=$fails restored=$restored');
    });

    test('a) tasker with balance + bank + step-up: gate open', () async {
      t = await login(kTaskerEmail, kTaskerPw);
      ledger = IdempotencyLedger(store: MemoryPendingKeyStore());
      await taskerStepUp(t);
      final s0 = state();
      final w = await walletRaw(t);
      rec('a', 'balance 500000, 0 payouts pending', s0['balance'] == 500000 && s0['pending'] == 0, j(s0));
      rec('a', 'wallet: canRequestPayout true', w['canRequestPayout'] == true, 'canRequestPayout=${w['canRequestPayout']}');
      rec('a', 'wallet: pendingPayoutRequestId null (key present)', w.containsKey('pendingPayoutRequestId') && w['pendingPayoutRequestId'] == null, 'v=${w['pendingPayoutRequestId']}');
      rec('a', 'wallet: payoutBlockedReason null (key present)', w.containsKey('payoutBlockedReason') && w['payoutBlockedReason'] == null, 'v=${w['payoutBlockedReason']}');
      // the real model: does it surface the new fields?
      final model = await t.api.taskerWallet();
      notes.add('WalletSummary (lib/core/models/tasker.dart) has no pendingPayoutRequestId/canRequestPayout/payoutBlockedReason fields: parsed balanceVnd=${model.balanceVnd} only.');
      scen['a'] = {'before': s0, 'wallet': w};
    });

    test('b) first payout 100000 via the ledger -> 201; wallet gate closes (vi + en)', () async {
      await taskerStepUp(t);
      final before = state();
      final r = await ledger.run('payout:100000', (k) => t.api.requestPayout(100000, idempotencyKey: k));
      final call = t.rec.calls.last;
      key1 = call.idemKey;
      p1 = r.id;
      final after = state();
      rec('b', 'POST /tasker/payouts 100000 -> 201 pending', call.status == 201 && r.status == 'pending', 'status=${call.status} id=${r.id} body=${j(call.respBody)}');
      rec('b', 'rows +1, pending 1, balance -100000, 1 debit tx', after['payouts'] == before['payouts']! + 1 && after['pending'] == 1 && after['balance'] == before['balance']! - 100000 && after['walletTx'] == before['walletTx']! + 1, 'before=${j(before)} after=${j(after)}');
      final wv = await walletRaw(t, 'vi');
      final we = await walletRaw(t, 'en');
      rec('b', 'wallet(vi): canRequestPayout false, pendingPayoutRequestId == new id', wv['canRequestPayout'] == false && wv['pendingPayoutRequestId'] == r.id, 'pending=${wv['pendingPayoutRequestId']} id=${r.id}');
      final bv = wv['payoutBlockedReason'] as Map?;
      final be = we['payoutBlockedReason'] as Map?;
      rec('b', 'payoutBlockedReason {code:PAYOUT_PENDING_EXISTS,label} vi', bv != null && bv['code'] == 'PAYOUT_PENDING_EXISTS' && '${bv['label']}'.startsWith('Bạn đang có'), j(bv));
      rec('b', 'payoutBlockedReason label en', be != null && be['code'] == 'PAYOUT_PENDING_EXISTS' && '${be['label']}'.startsWith('You already have'), j(be));
      scen['b'] = {'before': before, 'after': after, 'id': r.id};
    });

    test('c) second payout (different action/key) -> 409 PAYOUT_PENDING_EXISTS, 0 rows, no debit', () async {
      await taskerStepUp(t);
      final before = state();
      // 50000 is below PAYOUT_MIN (100000): validation runs first -> 422, still no row.
      ApiException? e50;
      try {
        await ledger.run('payout:50000', (k) => t.api.requestPayout(50000, idempotencyKey: k));
      } on ApiException catch (e) {
        e50 = e;
      }
      rec('c', '50000 (below min) -> 422 amount_vnd, validation precedes the pending gate', e50?.status == 422 && ((e50?.fields?.containsKey('amount_vnd') ?? false) || (e50?.fields?.containsKey('amountVnd') ?? false)), '${e50?.code} ${e50?.status} fields=${e50?.fields}');
      ApiException? e;
      await ledger.run('payout:150000', (k) => t.api.requestPayout(150000, idempotencyKey: k)).then((_) => null, onError: (Object x) {
        if (x is ApiException) e = x;
      });
      final call = t.rec.calls.last;
      final body = call.respBody as Map;
      final after = state();
      rec('c', '150000 new key -> 409', call.status == 409 && e?.status == 409, 'status=${call.status} idemKey=${call.idemKey}');
      rec('c', 'code PAYOUT_PENDING_EXISTS, retryable false', body['code'] == 'PAYOUT_PENDING_EXISTS' && body['retryable'] == false, 'code=${body['code']} retryable=${body['retryable']}');
      final details = (body['details'] as Map?);
      rec('c', 'details.pendingRequestId == first id', details != null && details['pendingRequestId'] == p1, 'details=${j(details)} first=$p1');
      rec('c', '0 new rows, no debit, no tx, no pending change', after['payouts'] == before['payouts'] && after['balance'] == before['balance'] && after['walletTx'] == before['walletTx'] && after['pending'] == 1, 'before=${j(before)} after=${j(after)}');
      rec('c', 'envelope message localized (vi)', '${body['message']}'.startsWith('Bạn đang có'), 'message=${body['message']}');
      final en = await raw('en').post('/tasker/payouts',
          data: {'amountVnd': 150000},
          options: Options(headers: {'authorization': 'Bearer ${await t.store.accessToken}', 'Idempotency-Key': 'qa-k-en-${DateTime.now().microsecondsSinceEpoch}'}));
      rec('c', 'envelope message localized (en)', en.statusCode == 409 && '${(en.data as Map)['message']}'.startsWith('You already have'), 'status=${en.statusCode} message=${(en.data as Map)['message']} title=${(en.data as Map)['title']}');
      rec('c', 'app ApiException parsed: code/status/message/fields only (no details)', e != null && e!.code == 'PAYOUT_PENDING_EXISTS' && e!.status == 409, 'ApiException(code=${e?.code}, status=${e?.status}, message="${e?.message}", fields=${e?.fields}) -- class has no details/retryable member: details.pendingRequestId is DROPPED by ApiException.fromEnvelope');
      scen['c'] = {'before': before, 'after': after, 'body': body, 'ledgerKeyKeptAfter409': ApiKeep.kept(e)};
    });

    test('d) same-key replay of the first request -> stored 201, same id, 1 row', () async {
      await taskerStepUp(t);
      final before = state();
      final tok = await t.store.accessToken;
      final r = await raw().post('/tasker/payouts', data: {'amountVnd': 100000}, options: Options(headers: {'authorization': 'Bearer $tok', 'Idempotency-Key': key1}));
      final d = (r.data as Map)['data'] as Map?;
      final after = state();
      rec('d', 'replay with first key -> 201 same id', r.statusCode == 201 && d?['id'] == p1, 'status=${r.statusCode} id=${d?['id']} first=$p1 replayed=${r.headers.value('idempotent-replayed')}');
      rec('d', 'still exactly 1 payout row, balance unchanged', after['payouts'] == before['payouts'] && after['pending'] == 1 && after['balance'] == before['balance'], 'before=${j(before)} after=${j(after)}');
      // same replay through KycoApi
      final r2 = await t.api.requestPayout(100000, idempotencyKey: key1!);
      rec('d', 'KycoApi.requestPayout(first key) -> same id', r2.id == p1, 'id=${r2.id}');
      scen['d'] = {'before': before, 'after': after};
    });

    test('f) admin rejects pending -> refund, gate reopens, stale-key retry, new payout 201', () async {
      final before = state();
      final r = await adminResolve(p1!, 'reject');
      final after = state();
      rec('f', 'admin reject (step-up) -> 200', r.statusCode == 200, 'status=${r.statusCode} body=${j(r.data)}');
      rec('f', 'reject refunds the FULL amount (100000) to the wallet, pending 0, row status rejected', after['balance'] == before['balance']! + 100000 && after['pending'] == 0 && sql('select status from payout_requests where id=$p1') == 'rejected', 'before=${j(before)} after=${j(after)} refundTx=${sql("select reason||'|'||amount_vnd::bigint||'|'||coalesce(notes,'') from wallet_transactions where id=(select max(id) from wallet_transactions)")}');
      await taskerStepUp(t);
      final w = await walletRaw(t);
      rec('f', 'wallet: canRequestPayout true again, pending null, reason null', w['canRequestPayout'] == true && w['pendingPayoutRequestId'] == null && w['payoutBlockedReason'] == null, j({'can': w['canRequestPayout'], 'p': w['pendingPayoutRequestId'], 'r': w['payoutBlockedReason']}));
      // ledger: retry the 150000 action that got the 409 (key was kept per keepAfter 409)
      final callsBefore = t.rec.calls.length;
      PayoutRequestResult? retry;
      ApiException? retryErr;
      try {
        retry = await ledger.run('payout:150000', (k) => t.api.requestPayout(150000, idempotencyKey: k));
      } on ApiException catch (e) {
        retryErr = e;
      }
      final rc = t.rec.calls.last;
      final reusedKey = t.rec.calls.sublist(0, callsBefore).any((c) => c.idemKey == rc.idemKey);
      scen['f_staleKeyRetry'] = {'reusedKeyFrom409': reusedKey, 'status': rc.status, 'replayed': rc.replayed, 'body': rc.respBody};
      rec('f', 'INFO ledger retry of the 409-ed action after the slot is free', true, 'reusedSameKeyAsThe409=$reusedKey status=${rc.status} replayedHeader=${rc.replayed} result=${retry?.id ?? retryErr}');
      if (retry != null) {
        p2 = retry.id;
        rec('f', 'new payout (150000) -> 201 after reject', rc.status == 201, 'id=$p2 state=${j(state())}');
      } else {
        notes.add('After the slot freed, ledger.run(payout:150000) retry reused the 409 key and got status=${rc.status} replayed=${rc.replayed}: ${j(rc.respBody)}');
        // fall back to a brand new action
        await taskerStepUp(t);
        final n = await ledger.run('payout:200000', (k) => t.api.requestPayout(200000, idempotencyKey: k));
        p2 = n.id;
        rec('f', 'new payout (200000, fresh key) -> 201 after reject', t.rec.calls.last.status == 201, 'id=$p2 state=${j(state())}');
      }
      scen['f'] = {'before': before, 'afterReject': after, 'afterNew': state(), 'p2': p2};
    });

    test('g) admin approves (pay) pending -> slot freed, no refund', () async {
      final before = state();
      final amt = sqlInt('select amount_vnd::bigint from payout_requests where id=$p2');
      final r = await adminResolve(p2!, 'pay');
      final after = state();
      rec('g', 'admin approve (pay) -> 200', r.statusCode == 200, 'status=${r.statusCode} body=${j(r.data)}');
      rec('g', 'status paid, pending 0, balance unchanged (no refund), rows unchanged', sql('select status from payout_requests where id=$p2') == 'paid' && after['pending'] == 0 && after['balance'] == before['balance'] && after['payouts'] == before['payouts'], 'amount=$amt before=${j(before)} after=${j(after)}');
      await taskerStepUp(t);
      final w = await walletRaw(t);
      rec('g', 'wallet: canRequestPayout true after approve', w['canRequestPayout'] == true && w['pendingPayoutRequestId'] == null, j({'can': w['canRequestPayout'], 'p': w['pendingPayoutRequestId']}));
      scen['g'] = {'before': before, 'after': after, 'amount': amt};
    });

    test('e) concurrency: two clients, different keys, simultaneous -> exactly one row', () async {
      for (var round = 1; round <= 3; round++) {
        // refill so both could afford
        sql("update wallets set balance_vnd=500000 where owner_type='tasker' and owner_id=$tid");
        final a = await login(kTaskerEmail, kTaskerPw);
        final b = await login(kTaskerEmail, kTaskerPw);
        await taskerStepUp(a);
        final la = IdempotencyLedger(store: MemoryPendingKeyStore());
        final lb = IdempotencyLedger(store: MemoryPendingKeyStore());
        final before = state();
        Future<Map<String, dynamic>> go(LiveClient c, IdempotencyLedger l) async {
          try {
            final r = await l.run('payout:100000', (k) => c.api.requestPayout(100000, idempotencyKey: k));
            return {'ok': true, 'id': r.id, 'status': c.rec.calls.last.status};
          } on ApiException catch (e) {
            return {'ok': false, 'status': e.status, 'code': e.code, 'idemKey': c.rec.calls.last.idemKey};
          }
        }

        final res = await Future.wait([go(a, la), go(b, lb)]);
        final after = state();
        final won = res.where((r) => r['ok'] == true).length;
        final lost = res.where((r) => r['ok'] != true).toList();
        final keysDiffer = a.rec.calls.last.idemKey != b.rec.calls.last.idemKey;
        rec('e', 'round $round: exactly one 201', won == 1, j(res));
        rec('e', 'round $round: loser is 409 (PAYOUT_PENDING_EXISTS or CONFLICT), keys differ', lost.length == 1 && lost.first['status'] == 409 && keysDiffer, 'loser=${j(lost)} keysDiffer=$keysDiffer');
        rec('e', 'round $round: exactly 1 new row, 1 pending, exactly one debit of 100000', after['payouts'] == before['payouts']! + 1 && after['pending'] == 1 && after['balance'] == before['balance']! - 100000 && after['walletTx'] == before['walletTx']! + 1, 'before=${j(before)} after=${j(after)}');
        scen['e_round$round'] = {'results': res, 'before': before, 'after': after};
        final pid = sqlInt("select id from payout_requests where tasker_id=$tid and status='pending'");
        final rr = await adminResolve(pid, 'reject');
        rec('e', 'round $round: cleanup reject -> 200', rr.statusCode == 200, 'status=${rr.statusCode}');
      }
    });

    test('record notes', () {
      notes.add('Reject refund per code (lib/payments/payout-queue.ts rejectPayoutRequest): adjustWallet(+amountVnd) in the same tx as the status claim, notes "Payout request #id rejected — refunded"; full amount, no fee. Approve (markPayoutPaid) only flips status to paid; no wallet movement.');
      notes.add('PAYOUT_MIN is 100000: the 50000 action in the task text is a 422 (validation before the pending gate); 150000 was used for the "different key" 409 check.');
    });
  });
}

class ApiKeep {
  static bool? kept(ApiException? e) => e == null ? null : IdempotencyLedger.keepAfter(e);
}
