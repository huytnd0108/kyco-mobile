// K2: the mobile withdraw-screen gate (WalletSummary gate fields, runWithdrawFlow, TaskerWalletScreen) against the
// REAL lab (backend ff6198c3, 127.0.0.1:4142). Real KycoApi + real app code; lab only. Run:
//   flutter test test/live/k2_withdraw_gate_live_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
//
// Data changes (restored in tearDownAll with SCOPED sql by tracked ids; never by a bare id>N sweep):
//   taskers(1).bank_*, wallets(tasker 1).balance_vnd, payout_requests / wallet_transactions / notifications /
//   api_idempotency_keys created by this run.
@Tags(['live'])
@Timeout(Duration(minutes: 30))
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/format.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/tasker_wallet/tasker_wallet_providers.dart';
import 'package:kyco_mobile/features/tasker_wallet/tasker_wallet_screen.dart';
import 'package:kyco_mobile/features/tasker_wallet/withdraw_sheet.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../wave_c_support.dart' show TestAuth;
import 'live_support_rd.dart';

const viMsg = 'Bạn đang có một yêu cầu rút tiền chờ xử lý. Vui lòng chờ duyệt trước khi tạo yêu cầu mới.';
const enMsg = 'You already have a withdrawal request waiting for review. Please wait for it to be processed before creating a new one.';

final checks = <Map<String, dynamic>>[];
final notes = <String>[];
final scen = <String, dynamic>{};

void rec(String item, String name, bool ok, String detail) {
  checks.add({'item': item, 'name': name, 'ok': ok, 'detail': detail});
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  [$item] $name -- $detail');
}

String j(Object? o, [int n = 500]) {
  final s = jsonEncode(o);
  return s.length > n ? '${s.substring(0, n)}...' : s;
}

const tid = 1;
const walletWhere = "owner_type='tasker' and owner_id=$tid";
int pays() => sqlInt('select count(*) from payout_requests where tasker_id=$tid');
int pendings() => sqlInt("select count(*) from payout_requests where tasker_id=$tid and status='pending'");
int bal() => sqlInt("select balance_vnd::bigint from wallets where $walletWhere");
int txs() => sqlInt("select count(*) from wallet_transactions where wallet_id=(select id from wallets where $walletWhere)");
Map<String, int> state() => {'payouts': pays(), 'pending': pendings(), 'balance': bal(), 'walletTx': txs()};

class Rig {
  Rig(this.api, this.client, this.rec);
  final KycoApi api;
  final KycoApiClient client;
  final Recorder rec;
  int count(String method, String pathEnd) =>
      rec.calls.where((c) => c.method == method && c.path.endsWith(pathEnd)).length;
}

/// Runs every request in the ROOT zone so no HttpClient timer lands in the widget tester's fake-async zone.
class RootZoneAdapter implements HttpClientAdapter {
  final IOHttpClientAdapter _inner = IOHttpClientAdapter();
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) =>
      Zone.root.run(() => _inner.fetch(o, s, c));
  @override
  void close({bool force = false}) => _inner.close(force: force);
}

late InMemoryTokenStore store;
Rig rig(String lang) {
  final r = Recorder();
  final dio = Dio(BaseOptions(baseUrl: kApiBase, validateStatus: (_) => true, headers: {'accept': 'application/json', 'accept-language': lang}))
    ..httpClientAdapter = RootZoneAdapter()
    ..interceptors.add(r);
  final client = KycoApiClient(tokens: store, dio: dio, acceptLanguage: () => lang);
  return Rig(KycoApi(client, store), client, r);
}

Future<void> stepUpFresh(KycoApi api) async {
  final s = await api.stepUpStatus();
  if (!s.fresh) await api.stepUp(password: kTaskerPw);
}

Future<void> settleReal(WidgetTester t, {int n = 14, int ms = 120}) async {
  for (var i = 0; i < n; i++) {
    await t.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

Widget app(Rig r, Widget home, {String lang = 'vi', IdempotencyLedger? ledger, required SharedPreferences prefs}) => ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        tokenStoreProvider.overrideWithValue(store),
        apiClientProvider.overrideWithValue(r.client),
        kycoApiProvider.overrideWithValue(r.api),
        authControllerProvider.overrideWith(() => TestAuth(const AuthState(status: AuthStatus.signedIn, user: AuthUser(id: 3, role: 'tasker')))),
        if (ledger != null) idempotencyLedgerProvider.overrideWithValue(ledger),
      ],
      child: MaterialApp(
        theme: buildTheme(lightColorScheme),
        locale: Locale(lang),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

/// Keeps the three wallet providers alive (as the wallet screen does) and exposes a button running the real flow.
class FlowHost extends ConsumerWidget {
  const FlowHost({super.key, required this.balance, required this.onResult});
  final int balance;
  final void Function(String?) onResult;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(walletSummaryProvider);
    ref.watch(walletTxnsControllerProvider);
    ref.watch(payoutRequestsControllerProvider);
    return TextButton(onPressed: () async => onResult(await runWithdrawFlow(context, ref, balanceVnd: balance)), child: const Text('go'));
  }
}

FilledButton withdrawButton(WidgetTester t, AppLocalizations l) =>
    t.widget<FilledButton>(find.ancestor(of: find.text(l.provWalletWithdrawAction), matching: find.byWidgetPredicate((w) => w is FilledButton)));

class Snap {
  late String bank, tasker, wallets, counts;
  late int maxTx, maxPay, maxNotif, maxIdem, maxAudit;
}

final snap = Snap();
String fullCounts() => sql(
    "select (select count(*) from payout_requests)||'|'||(select count(*) from wallet_transactions)||'|'||(select count(*) from notifications)||'|'||(select count(*) from api_idempotency_keys)||'|'||(select count(*) from admin_audit)||'|'||(select md5(string_agg(id||':'||balance_vnd,',' order by id)) from wallets)");
String taskerRow() => sql("select md5(t::text) from taskers t where id=$tid");
int csvCount(String s) => s.isEmpty ? 0 : s.split(',').length;

void main() {
  group('K2 withdraw gate live', skip: kLive ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    int? p1;
    late IdempotencyLedger ledgerVi;

    setUpAll(() async {
      guardLab();
      HttpOverrides.global = null;
      Directory('$kQaRoot/out/lab').createSync(recursive: true);
      snap.bank = sql("select coalesce(bank_code,'~NULL~')||'|'||coalesce(bank_account_number,'~NULL~')||'|'||coalesce(bank_account_holder,'~NULL~') from taskers where id=$tid");
      snap.tasker = taskerRow();
      snap.wallets = sql("select id||'|'||balance_vnd from wallets order by id").replaceAll('\n', ';');
      snap.counts = fullCounts();
      snap.maxTx = sqlInt('select coalesce(max(id),0) from wallet_transactions');
      snap.maxPay = sqlInt('select coalesce(max(id),0) from payout_requests');
      snap.maxNotif = sqlInt('select coalesce(max(id),0) from notifications');
      snap.maxIdem = sqlInt('select coalesce(max(id),0) from api_idempotency_keys');
      snap.maxAudit = sqlInt('select coalesce(max(id),0) from admin_audit');
      File('$kQaRoot/out/lab/K2-snapshot.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'bank': snap.bank,
        'wallets': snap.wallets,
        'counts(payouts|walletTx|notif|idem|audit|walletsMd5)': snap.counts,
        'taskerRowMd5': snap.tasker,
        'taskerRow': jsonDecode(sql("select row_to_json(t)::text from taskers t where id=$tid")),
        'maxTx': snap.maxTx, 'maxPay': snap.maxPay, 'maxNotif': snap.maxNotif, 'maxIdem': snap.maxIdem, 'maxAudit': snap.maxAudit,
        'taskerPayouts': sql("select coalesce(string_agg(id||':'||status||':'||amount_vnd,','),'none') from payout_requests where tasker_id=$tid"),
      }));
      stdout.writeln('SNAP bank=${snap.bank} wallets=${snap.wallets} counts=${snap.counts}');
      if (pendings() != 0) throw StateError('tasker 1 already has a pending payout; abort');
      sql("update taskers set bank_code='VCB', bank_account_number='1234567890', bank_account_holder='QA K2 GATE' where id=$tid");
      sql("update wallets set balance_vnd=500000 where $walletWhere");
      await paceLogin();
      final c = newClient();
      await c.api.login(email: kTaskerEmail, password: kTaskerPw);
      store = c.store;
      ledgerVi = IdempotencyLedger(store: MemoryPendingKeyStore());
    });

    tearDownAll(() {
      final tkId = sql('select user_account_id from taskers where id=$tid');
      final created = {
        'payout_requests': sql("select coalesce(string_agg(id::text,','),'') from payout_requests where id>${snap.maxPay} and tasker_id=$tid"),
        'wallet_transactions': sql("select coalesce(string_agg(id::text,','),'') from wallet_transactions where id>${snap.maxTx} and wallet_id=(select id from wallets where $walletWhere)"),
        'notifications': sql("select coalesce(string_agg(id::text,','),'') from notifications where id>${snap.maxNotif} and user_id=$tkId"),
        'api_idempotency_keys': sql("select coalesce(string_agg(id::text,','),'') from api_idempotency_keys where id>${snap.maxIdem} and user_id=$tkId"),
      };
      final foreign = {
        'payout_requests': sqlInt('select count(*) from payout_requests where id>${snap.maxPay}') - csvCount(created['payout_requests']!),
        'wallet_transactions': sqlInt('select count(*) from wallet_transactions where id>${snap.maxTx}') - csvCount(created['wallet_transactions']!),
        'notifications': sqlInt('select count(*) from notifications where id>${snap.maxNotif}') - csvCount(created['notifications']!),
        'api_idempotency_keys': sqlInt('select count(*) from api_idempotency_keys where id>${snap.maxIdem}') - csvCount(created['api_idempotency_keys']!),
      };
      for (final e in created.entries) {
        if (e.value.isNotEmpty) sql('delete from ${e.key} where id in (${e.value})');
      }
      for (final w in snap.wallets.split(';')) {
        final p = w.split('|');
        sql('update wallets set balance_vnd=${p[1]} where id=${p[0]}');
      }
      final b = snap.bank.split('|');
      String lit(String v) => v == '~NULL~' ? 'NULL' : "'$v'";
      sql('update taskers set bank_code=${lit(b[0])}, bank_account_number=${lit(b[1])}, bank_account_holder=${lit(b[2])} where id=$tid');
      final restored = {
        'countsEqualSnapshot': fullCounts() == snap.counts,
        'countsNow': fullCounts(),
        'countsSnap': snap.counts,
        'walletsEqual': sql("select id||'|'||balance_vnd from wallets order by id").replaceAll('\n', ';') == snap.wallets,
        'walletsNow': sql("select id||'|'||balance_vnd from wallets order by id").replaceAll('\n', ';'),
        'taskerRowMd5Equal': taskerRow() == snap.tasker,
        'bankNow': sql("select coalesce(bank_code,'~NULL~')||'|'||coalesce(bank_account_number,'~NULL~')||'|'||coalesce(bank_account_holder,'~NULL~') from taskers where id=$tid"),
        'bankSnap': snap.bank,
        'deletedIds': created,
        'rowsAboveMaxCreatedByOthers_leftUntouched': foreign,
      };
      final fails = checks.where((c) => c['ok'] != true).length;
      writeJson('$kQaRoot/out/lab/K2-withdraw-gate.result.json', {
        'pkg': 'K2-withdraw-gate',
        'labSha': 'ff6198c3',
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'pass': checks.length - fails,
        'fail': fails,
        'restored': restored,
        'scenarios': scen,
        'notes': notes,
        'checks': checks,
      });
      stdout.writeln('K2: pass=${checks.length - fails} fail=$fails restored=${restored['countsEqualSnapshot']}/${restored['walletsEqual']}/${restored['taskerRowMd5Equal']}');
    });

    // ───────── none pending ─────────
    test('1a) none pending: WalletSummary canRequestPayout=true', () async {
      final r = rig('vi');
      await stepUpFresh(r.api);
      final w = await r.api.taskerWallet();
      rec('1', 'none pending: canRequestPayout true, pendingPayoutRequestId null, reason null',
          w.canRequestPayout && w.pendingPayoutRequestId == null && w.payoutBlockedReason == null && w.balanceVnd == 500000,
          'can=${w.canRequestPayout} pid=${w.pendingPayoutRequestId} reason=${w.payoutBlockedReason?.label} balance=${w.balanceVnd} sql=${j(state())}');
    });

    testWidgets('4a) screen, none pending: withdraw enabled, no pending link', (t) async {
      final r = rig('vi');
      final l = lookupAppLocalizations(const Locale('vi'));
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await t.runAsync(SharedPreferences.getInstance);
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(r, const TaskerWalletScreen(), prefs: prefs!));
      await settleReal(t);
      final enabled = withdrawButton(t, l).onPressed != null;
      rec('4', 'screen (real lab, none pending): withdraw button enabled', enabled, 'enabled=$enabled walletGETs=${r.count('GET', '/tasker/wallet')}');
      rec('4', 'screen (none pending): no pending link, no blocked fallback', find.text(l.provWalletViewPendingRequest).evaluate().isEmpty && find.text(l.provWalletPayoutBlockedFallback).evaluate().isEmpty, 'ok');
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });

    // ───────── 3) 422 ─────────
    test('3a) 422 direct: below min (50000) and above balance -> fields.amountVnd, 0 rows', () async {
      final r = rig('vi');
      await stepUpFresh(r.api);
      final before = state();
      final led = IdempotencyLedger(store: MemoryPendingKeyStore());
      for (final amt in [50000, 5000000]) {
        ApiException? e;
        try {
          await led.run('payout:$amt', (k) => r.api.requestPayout(amt, idempotencyKey: k));
        } on ApiException catch (x) {
          e = x;
        }
        rec('3', '$amt -> 422 with fields.amountVnd (server key)', e?.status == 422 && (e?.fields?.containsKey('amountVnd') ?? false),
            'status=${e?.status} code=${e?.code} fields=${j(e?.fields)} message="${e?.message}"');
        scen['422_direct_$amt'] = {'status': e?.status, 'code': e?.code, 'fields': e?.fields, 'message': e?.message};
      }
      final after = state();
      rec('3', '422 direct: 0 new rows, balance unchanged, no tx', j(before) == j(after), 'before=${j(before)} after=${j(after)}');
    });

    testWidgets('3b) runWithdrawFlow: above-balance (stale UI balance) -> friendly copy; below-min blocked in sheet (0 POST)', (t) async {
      final r = rig('vi');
      await t.runAsync(() => stepUpFresh(r.api));
      final l = lookupAppLocalizations(const Locale('vi'));
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await t.runAsync(SharedPreferences.getInstance);
      final before = state();
      final led = IdempotencyLedger(store: MemoryPendingKeyStore());
      String? msg;
      var done = false;
      await t.pumpWidget(app(r, FlowHost(balance: 10000000, onResult: (m) {
        msg = m;
        done = true;
      }), ledger: led, prefs: prefs!));
      await settleReal(t, n: 4);
      await t.tap(find.text('go'));
      await settleReal(t, n: 4);
      final postsBefore = r.count('POST', '/tasker/payouts');
      await t.enterText(find.byType(TextField), '50000');
      await t.tap(find.text(l.provWalletContinue));
      await settleReal(t, n: 3);
      final minShown = find.text(l.provWalletWithdrawMinError(formatVnd(100000))).evaluate().isNotEmpty;
      rec('3', 'below-min 50000: sheet shows the min error, no POST sent', minShown && r.count('POST', '/tasker/payouts') == postsBefore,
          'minErrorShown=$minShown posts=${r.count('POST', '/tasker/payouts') - postsBefore}');
      // 5,000,000 > real balance 500000 but <= the (stale) balance the UI believes: reaches the server
      await t.enterText(find.byType(TextField), '5000000');
      await t.tap(find.text(l.provWalletContinue));
      for (var i = 0; i < 30 && !done; i++) {
        await settleReal(t, n: 1);
      }
      final post = r.rec.calls.where((c) => c.method == 'POST' && c.path.endsWith('/tasker/payouts')).toList();
      final body = post.isEmpty ? null : post.last.respBody;
      final fields = body is Map ? body['fields'] : null;
      rec('3', 'above-balance 5000000: server 422 with fields.amountVnd', post.isNotEmpty && post.last.status == 422 && fields is Map && fields.containsKey('amountVnd'),
          'status=${post.isEmpty ? null : post.last.status} body=${j(body)}');
      rec('3', 'above-balance: user copy == provWalletWithdrawInvalidAmount (friendly)', msg == l.provWalletWithdrawInvalidAmount, 'copy="$msg"');
      final after = state();
      rec('3', 'above-balance flow: 0 new rows, balance unchanged', j(before) == j(after), 'before=${j(before)} after=${j(after)}');
      scen['3b'] = {'copy': msg, 'serverBody': body};
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });

    // ───────── first payout, gate model ─────────
    test('1b) one pending payout (100000): WalletSummary gate fields (vi + en)', () async {
      final rv = rig('vi');
      final re = rig('en');
      await stepUpFresh(rv.api);
      final before = state();
      final res = await ledgerVi.run('payout:100000', (k) => rv.api.requestPayout(100000, idempotencyKey: k));
      p1 = res.id;
      final after = state();
      rec('1', 'first payout 100000 -> 201 pending, +1 row, -100000, +1 debit',
          res.status == 'pending' && after['payouts'] == before['payouts']! + 1 && after['balance'] == before['balance']! - 100000 && after['walletTx'] == before['walletTx']! + 1,
          'id=${res.id} before=${j(before)} after=${j(after)}');
      final wv = await rv.api.taskerWallet();
      final we = await re.api.taskerWallet();
      rec('1', 'vi: canRequestPayout=false, pendingPayoutRequestId==id, reason.label vi',
          !wv.canRequestPayout && wv.pendingPayoutRequestId == p1 && wv.payoutBlockedReason?.code == 'PAYOUT_PENDING_EXISTS' && (wv.payoutBlockedReason?.label?.startsWith('Bạn đang có') ?? false),
          'can=${wv.canRequestPayout} pid=${wv.pendingPayoutRequestId} reason=${wv.payoutBlockedReason?.code}/"${wv.payoutBlockedReason?.label}"');
      rec('1', 'en: canRequestPayout=false, pendingPayoutRequestId==id, reason.label en',
          !we.canRequestPayout && we.pendingPayoutRequestId == p1 && (we.payoutBlockedReason?.label?.startsWith('You already have') ?? false),
          'can=${we.canRequestPayout} pid=${we.pendingPayoutRequestId} reason=${we.payoutBlockedReason?.code}/"${we.payoutBlockedReason?.label}"');
      scen['1b'] = {'id': p1, 'viLabel': wv.payoutBlockedReason?.label, 'enLabel': we.payoutBlockedReason?.label, 'before': before, 'after': after};
    });

    testWidgets('4b) screen, one pending: button disabled, reason label, link highlights the pending tile', (t) async {
      final r = rig('vi');
      final l = lookupAppLocalizations(const Locale('vi'));
      SharedPreferences.setMockInitialValues(const {});
      final prefs = await t.runAsync(SharedPreferences.getInstance);
      t.view.physicalSize = const Size(800, 2400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(r, const TaskerWalletScreen(), prefs: prefs!));
      await settleReal(t);
      final disabled = withdrawButton(t, l).onPressed == null;
      final w = await t.runAsync(() => r.api.taskerWallet());
      final label = w!.payoutBlockedReason!.label!;
      rec('4', 'screen (real lab, pending): withdraw button disabled', disabled, 'disabled=$disabled');
      rec('4', 'screen (pending): server reason label shown', find.text(label).evaluate().length == 1, 'label="$label" found=${find.text(label).evaluate().length}');
      rec('4', 'screen (pending): "Xem yêu cầu đang chờ" link present', find.text(l.provWalletViewPendingRequest).evaluate().length == 1, 'link=${l.provWalletViewPendingRequest}');
      bool highlighted() => find
          .ancestor(
              of: find.text(formatVnd(100000)),
              matching: find.byWidgetPredicate((x) => x is Container && x.decoration is BoxDecoration && (x.decoration as BoxDecoration).border != null && (x.decoration as BoxDecoration).color != null))
          .evaluate()
          .isNotEmpty;
      final hBefore = highlighted();
      await t.tap(find.text(l.provWalletViewPendingRequest));
      await settleReal(t, n: 3);
      final hAfter = highlighted();
      rec('4', 'screen (pending): link highlights the pending tile (off before, on after)', !hBefore && hAfter, 'before=$hBefore after=$hAfter tileAmount=${formatVnd(100000)} id=$p1');
      await t.tap(find.byType(FilledButton).first, warnIfMissed: false);
      await settleReal(t, n: 2);
      rec('4', 'screen (pending): tapping the disabled button opens no sheet', find.byType(WithdrawSheet).evaluate().isEmpty, 'sheet=${find.byType(WithdrawSheet).evaluate().length}');
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });

    // ───────── 2) second payout while pending ─────────
    for (final lang in ['vi', 'en']) {
      testWidgets('2) runWithdrawFlow second payout while pending ($lang)', (t) async {
        final r = rig(lang);
        await t.runAsync(() => stepUpFresh(r.api));
        final l = lookupAppLocalizations(Locale(lang));
        SharedPreferences.setMockInitialValues(const {});
        final prefs = await t.runAsync(SharedPreferences.getInstance);
        final amount = lang == 'vi' ? 150000 : 170000;
        final led = IdempotencyLedger(store: MemoryPendingKeyStore());
        final before = state();
        String? msg;
        var done = false;
        await t.pumpWidget(app(r, FlowHost(balance: before['balance']!, onResult: (m) {
          msg = m;
          done = true;
        }), lang: lang, ledger: led, prefs: prefs!));
        await settleReal(t, n: 4); // initial provider loads
        final g0 = (r.count('GET', '/tasker/wallet'), r.count('GET', '/tasker/payout-requests'), r.count('GET', '/tasker/wallet/transactions'));
        await t.tap(find.text('go'));
        await settleReal(t, n: 4);
        await t.enterText(find.byType(TextField), '$amount');
        await t.tap(find.text(l.provWalletContinue));
        for (var i = 0; i < 30 && !done; i++) {
          await settleReal(t, n: 1);
        }
        await settleReal(t, n: 6); // let the invalidated providers refetch
        final post = r.rec.calls.where((c) => c.method == 'POST' && c.path.endsWith('/tasker/payouts')).toList();
        final usedKey = post.isEmpty ? null : post.last.idemKey;
        final expected = lang == 'vi' ? viMsg : enMsg;
        final pb = post.isEmpty ? <String, dynamic>{} : (post.last.respBody as Map).cast<String, dynamic>();
        rec('2', '[$lang] POST -> 409 PAYOUT_PENDING_EXISTS', post.isNotEmpty && post.last.status == 409 && pb['code'] == 'PAYOUT_PENDING_EXISTS', 'status=${post.isEmpty ? null : post.last.status} body=${j(pb)}');
        rec('2', '[$lang] user copy == server PAYOUT_PENDING_EXISTS message', msg == expected && msg == pb['message'], 'copy="$msg"');
        final g1 = (r.count('GET', '/tasker/wallet'), r.count('GET', '/tasker/payout-requests'), r.count('GET', '/tasker/wallet/transactions'));
        rec('2', '[$lang] wallet + payout-requests + transactions providers refreshed (+1 GET each)', g1.$1 == g0.$1 + 1 && g1.$2 == g0.$2 + 1 && g1.$3 == g0.$3 + 1, 'before=$g0 after=$g1');
        final k2 = await t.runAsync(() => led.keyFor('payout:$amount'));
        rec('2', '[$lang] ledger DROPPED the key: keyFor(payout:$amount) is new', usedKey != null && k2 != null && k2 != usedKey, 'used=${mask(usedKey)} now=${mask(k2)}');
        final after = state();
        rec('2', '[$lang] SQL: 0 new rows, no debit, no tx, still 1 pending', j(before) == j(after) && after['pending'] == 1, 'before=${j(before)} after=${j(after)}');
        scen['2_$lang'] = {'copy': msg, 'amount': amount, 'before': before, 'after': after};
        await t.pumpWidget(const SizedBox());
        await t.pump();
      });
    }
  });
}
