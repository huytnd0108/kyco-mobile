// Release-i (4f36881d) verification against the lab on 127.0.0.1:4142. QA only; lab only.
//   flutter test test/live/release_i_live_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 \
//     --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
//
// Real KycoApi + models. Items:
//   a) GET /legal      b) signup with ConsentPayload.forLegal (+ consent false / absent)
//   c) re-consent on an existing user (+ /me shape for the gate)
//   e) tasker cancel-preview == actual cancel (6 situations, tasker row restored between them)
//   d) become-tasker multipart consent (last: signup budget 3 / 15 min)
// Evidence goes to $QA/out/mobile/release-i-live.result.json.
@Tags(['live'])
@Timeout(Duration(minutes: 45))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/format.dart' show uuidV4;
import 'package:kyco_mobile/core/models.dart';

import 'live_support_rd.dart';

final List<Map<String, dynamic>> checks = [];
final List<Map<String, dynamic>> scenarios = [];
final List<String> createdUsers = [];
final List<String> notes = [];
final rnd = Random();

void rec(String item, String name, bool ok, String detail) {
  checks.add({'item': item, 'name': name, 'ok': ok, 'detail': detail});
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  [$item] $name -- $detail');
}

String j(Object? o, [int n = 500]) {
  final s = jsonEncode(o);
  return s.length > n ? '${s.substring(0, n)}...' : s;
}

LiveClient mk() {
  guardLab();
  final store = InMemoryTokenStore();
  final r = Recorder();
  final dio = Dio(BaseOptions(baseUrl: kApiBase, validateStatus: (_) => true, headers: {'accept': 'application/json'}))
    ..interceptors.add(r)
    ..interceptors.add(CaptureInterceptor('release-i-live'));
  return LiveClient(KycoApi(KycoApiClient(tokens: store, dio: dio), store), r, store);
}

Future<LiveClient> login(String email, String pw) async {
  await paceLogin();
  final c = mk();
  await c.api.login(email: email, password: pw);
  return c;
}

dynamic rawData(LiveClient c) {
  final b = c.rec.calls.last.respBody;
  return b is Map && b.containsKey('data') ? b['data'] : b;
}

// ---- signup budget (3 per 15 min per IP) --------------------------------------------------------
final List<DateTime> _attempts = [];
Future<void> budget(String note) async {
  // Shared with other suites through $QA/state/signup-budget.json (ts in ms).
  final bf = File('$kQaRoot/state/signup-budget.json');
  if (bf.existsSync() && _attempts.isEmpty) {
    for (final e in jsonDecode(bf.readAsStringSync()) as List) {
      final t = DateTime.fromMillisecondsSinceEpoch((e as Map)['ts'] as int);
      if (DateTime.now().difference(t) < const Duration(seconds: 905)) _attempts.add(t);
    }
  }
  while (true) {
    final now = DateTime.now();
    _attempts.removeWhere((t) => now.difference(t) > const Duration(seconds: 905));
    if (_attempts.length < 3) break;
    final wait = const Duration(seconds: 906) - now.difference(_attempts.first);
    stdout.writeln('INFO signup budget full: waiting ${wait.inSeconds}s');
    await Future<void>.delayed(wait + const Duration(seconds: 1));
  }
  _attempts.add(DateTime.now());
  final f = File('$kQaRoot/state/signup-budget.json');
  final list = f.existsSync() ? (jsonDecode(f.readAsStringSync()) as List) : [];
  list.add({'pkg': 'I-SUITE', 'ts': DateTime.now().millisecondsSinceEpoch, 'note': note});
  f.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(list));
}

String consentRows(int uid) => sql(
    "select kind||'|'||version||'|'||to_char(accepted_at at time zone 'utc','YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')||'|'||source||'|'||coalesce(left(user_agent,40),'~NULL~')||'|'||coalesce(ip,'~NULL~') "
    "from user_consents where user_id=$uid order by id");

// ---- tasker 1 state helpers ---------------------------------------------------------------------
Map<String, String> taskerState() {
  final r = sql("select is_banned||'|'||coalesce(banned_reason,'~')||'|'||coalesce(banned_at::text,'~')||'|'||coalesce(suspended_until::text,'~')||'|'||"
      "coalesce(consecutive_cancels,0)||'|'||coalesce(cancellations_30d,0)||'|'||coalesce(penalty_score,0) from taskers where id=1").split('|');
  return {
    'is_banned': r[0],
    'banned_reason': r[1],
    'banned_at': r[2],
    'suspended_until': r[3],
    'consecutive': r[4],
    'c30': r[5],
    'penalty': r[6],
  };
}

int wallet() => sqlInt("select coalesce((select balance_vnd::bigint from wallets where owner_type='tasker' and owner_id=1),0)");

void setTasker(int consecutive, int c30, int penalty) => sql(
    "update taskers set is_banned=false, banned_reason=null, banned_at=null, suspended_until=null, "
    "consecutive_cancels=$consecutive, cancellations_30d=$c30, penalty_score=$penalty where id=1");

BookingDraft draft(int svc, String note) {
  final t = DateTime.now().add(const Duration(days: 1));
  return BookingDraft(
    serviceId: svc,
    serviceName: 'release-i probe',
    basePriceVnd: 0,
    scheduledDate: ymd(t),
    scheduledTime: randomTime(),
    wardName: 'Quận 1',
    neighborhood: 'Bến Nghé',
    addressLine: '12 Lê Lợi',
    notes: note,
  );
}

void main() {
  group('release-i live verification', skip: kLive ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    LegalInfo? legal;
    Map<String, dynamic>? legalRaw;
    final tag = DateTime.now().millisecondsSinceEpoch.toString();
    final probeBookings = <int>[];
    late Map<String, String> taskerBefore;

    setUpAll(() {
      guardLab();
      Directory('$kQaRoot/out/mobile').createSync(recursive: true);
      taskerBefore = taskerState();
      stdout.writeln('INFO tasker1 before: ${j(taskerBefore)} wallet=${wallet()}');
    });

    tearDownAll(() {
      for (final id in probeBookings) {
        sql("update jobs set status='closed' where booking_id=$id and status in ('pending','open')");
      }
      // restore tasker 1 to the pre-run state
      final b = taskerBefore;
      sql("update taskers set is_banned=${b['is_banned']}, banned_reason=${b['banned_reason'] == '~' ? 'null' : "'${b['banned_reason']}'"}, "
          "banned_at=${b['banned_at'] == '~' ? 'null' : "'${b['banned_at']}'"}, suspended_until=${b['suspended_until'] == '~' ? 'null' : "'${b['suspended_until']}'"}, "
          "consecutive_cancels=${b['consecutive']}, cancellations_30d=${b['c30']}, penalty_score=${b['penalty']} where id=1");
      final fails = checks.where((c) => c['ok'] != true).length;
      writeJson('$kQaRoot/out/mobile/release-i-live.result.json', {
        'pkg': 'release-i-live',
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'pass': checks.length - fails,
        'fail': fails,
        'createdUsers': createdUsers,
        'probeBookings': probeBookings,
        'notes': notes,
        'taskerRestoredTo': taskerState(),
        'scenarios': scenarios,
        'checks': checks,
      });
      stdout.writeln('release-i-live: pass=${checks.length - fails} fail=$fails');
    });

    // ── a) GET /legal ─────────────────────────────────────────────────────
    test('a) GET /v1/legal parses', () async {
      final c = mk();
      legal = await c.api.legal();
      final call = c.rec.calls.last;
      legalRaw = (rawData(c) as Map).cast<String, dynamic>();
      rec('a', 'GET /v1/legal -> 200', call.status == 200, 'status=${call.status} trace=${call.traceId}');
      rec('a', 'parses termsVersion/privacyVersion', legal != null && legal!.termsVersion.isNotEmpty && legal!.privacyVersion.isNotEmpty,
          'terms=${legal?.termsVersion} privacy=${legal?.privacyVersion}');
      rec('a', 'consentRequired present and true', legalRaw!['consentRequired'] == true && legal!.consentRequired, 'raw=${j(legalRaw)}');
      rec('a', 'termsUrl/privacyUrl present in body', legalRaw!['termsUrl'] is String && legalRaw!['privacyUrl'] is String,
          'terms=${legalRaw!['termsUrl']} privacy=${legalRaw!['privacyUrl']}');
      // The app only opens absolute https URLs; the lab serves http://localhost so the model drops them (expected).
      rec('a', 'model URL handling (https only; lab is http => null)',
          (legalRaw!['termsUrl'] as String).startsWith('https://') ? legal!.termsUrl != null : legal!.termsUrl == null,
          'model termsUrl=${legal!.termsUrl} privacyUrl=${legal!.privacyUrl}');
      final payload = ConsentPayload.forLegal(legal);
      rec('a', 'release-i server: /legal has NO consentSchema -> app schema 1 (legacy path)',
          !legalRaw!.containsKey('consentSchema') && legal!.consentSchema == 1 && !legal!.perDocumentConsent, 'consentSchema=${legalRaw!['consentSchema']} parsed=${legal!.consentSchema}');
      rec('a', 'ConsentPayload.forLegal builds {terms,privacy,version=min}', payload != null && payload.version == legal!.signupConsentVersion,
          j(payload?.toJson()));
    });

    // ── b) signup ─────────────────────────────────────────────────────────
    int? signupUid;
    String? graceEmail; // signed up WITHOUT consent in (b): needsReconsent == true for (c)
    test('b) signup with the app consent payload -> 201 + rows', () async {
      await budget('I-SUITE b signup with consent');
      final c = mk();
      final email = 'qa.i.$tag@qa.local';
      final payload = ConsentPayload.forLegal(legal);
      final before = sqlInt('select count(*) from user_consents');
      AuthResult? res;
      ApiException? err;
      try {
        res = await c.api.signup(email: email, password: 'QaSignup12345!', name: 'QA ReleaseI', consent: payload);
      } on ApiException catch (e) {
        err = e;
      }
      final call = c.rec.calls.last;
      rec('b', 'signup(consent: ConsentPayload.forLegal) -> 201', res != null && call.status == 201,
          'status=${call.status} reqKeys=${call.reqKeys} body=${err == null ? 'ok' : '${err.code} ${err.message} ${err.fields}'} trace=${call.traceId}');
      signupUid = res?.user?.id ?? sqlInt("select id from users where email='$email'");
      createdUsers.add('$email (id=$signupUid)');
      final rows = consentRows(signupUid!);
      stdout.writeln('INFO consent rows for $signupUid:\n$rows');
      final lines = rows.split('\n').where((l) => l.isNotEmpty).toList();
      final kinds = lines.map((l) => l.split('|')[0]).toList()..sort();
      rec('b', 'SQL user_consents: exactly terms + privacy rows', kinds.join(',') == 'privacy,terms', 'rows=\n$rows');
      final okVer = lines.every((l) => l.split('|')[1] == payload!.version);
      rec('b', 'row version == payload version (${payload!.version})', okVer, 'rows versions=${lines.map((l) => l.split('|')[1]).toList()}');
      final okSrc = lines.every((l) => l.split('|')[3] == 'mobile');
      rec('b', 'row source == mobile', okSrc, 'sources=${lines.map((l) => l.split('|')[3]).toList()}');
      final okAt = lines.every((l) => l.split('|')[2].startsWith(DateTime.now().toUtc().toIso8601String().substring(0, 10)));
      rec('b', 'row accepted_at is today (UTC)', okAt, 'accepted_at=${lines.map((l) => l.split('|')[2]).toList()}');
      final okUa = lines.every((l) => l.split('|')[4] != '~NULL~');
      rec('b', 'row user_agent recorded', okUa, 'ua=${lines.map((l) => l.split('|')[4]).toList()}');
      rec('b', 'row ip recorded (INFO)', true, 'ip=${lines.map((l) => l.split('|')[5]).toList()}');
      rec('b', 'rows added == 2', sqlInt('select count(*) from user_consents') - before == 2, 'delta=${sqlInt('select count(*) from user_consents') - before}');
      // /me for the new user
      final me = await c.api.me();
      rec('b', 'new user /me consents.needsReconsent == false', me.consents != null && !me.needsReconsent,
          'consents=${j(rawData(c) is Map ? (rawData(c) as Map)['consents'] : null)}');
    });

    test('b) consent terms:false -> 422 fields.consent', () async {
      await budget('I-SUITE b consent terms:false');
      final dio = Dio(BaseOptions(baseUrl: kApiBase, validateStatus: (_) => true, headers: {'accept': 'application/json'}));
      final email = 'qa.i.false.$tag@qa.local';
      final before = sqlInt("select count(*) from users where email='$email'");
      final r = await dio.post('/auth/signup', data: {
        'email': email,
        'password': 'QaSignup12345!',
        'name': 'QA NoConsent',
        'consent': {'terms': false, 'privacy': true, 'version': legal?.signupConsentVersion},
      });
      final body = r.data;
      final fields = body is Map ? body['fields'] : null;
      rec('b', 'consent terms:false -> 422', r.statusCode == 422, 'status=${r.statusCode} body=${j(body)}');
      rec('b', 'fields has key consent', fields is Map && fields.containsKey('consent'), 'fields=${j(fields)}');
      rec('b', 'no user created', sqlInt("select count(*) from users where email='$email'") == before, 'users with email=${sqlInt("select count(*) from users where email='$email'")}');
    });

    test('b) signup with NO consent key -> accepted (mobile grace) and logged', () async {
      await budget('I-SUITE b signup without consent');
      final c = mk();
      final email = 'qa.i.nocons.$tag@qa.local';
      AuthResult? res;
      ApiException? err;
      final logBefore = File('$kQaRoot/logs/server.log').lengthSync();
      try {
        res = await c.api.signup(email: email, password: 'QaSignup12345!', name: 'QA Grace'); // consent: null => key omitted
      } on ApiException catch (e) {
        err = e;
      }
      final call = c.rec.calls.last;
      rec('b', 'signup with no consent key -> 201 (grace until 2026-12-31)', res != null && call.status == 201,
          'status=${call.status} reqKeys=${call.reqKeys} ${err == null ? '' : '${err.code} ${err.fields}'}');
      final uid = res?.user?.id ?? sqlInt("select id from users where email='$email'");
      createdUsers.add('$email (id=$uid)');
      if (res != null) graceEmail = email;
      rec('b', 'no consent rows written for the grace signup', consentRows(uid).isEmpty, 'rows="${consentRows(uid)}"');
      await Future<void>.delayed(const Duration(seconds: 1));
      final log = File('$kQaRoot/logs/server.log').readAsStringSync();
      final tail = log.substring(logBefore.clamp(0, log.length));
      final m = RegExp(r'.*consent_missing.*').firstMatch(tail);
      rec('b', 'consent_missing counter/log emitted', m != null, 'server.log: ${m?.group(0)?.substring(0, min(300, m.group(0)!.length)) ?? '(none)'}');
      if (res != null) {
        final me = await c.api.me();
        rec('b', 'grace user /me needsReconsent == true (will see the gate)', me.needsReconsent, 'consents=${j((rawData(c) as Map)['consents'])}');
      }
    });

    // ── c) re-consent ─────────────────────────────────────────────────────
    test('c) existing user: needsReconsent -> POST /me/consents -> cleared (+ f: /me shape)', () async {
      // demo@ already accepted in earlier runs (append-only): use the grace user from (b), else demo.
      final cEmail = graceEmail ?? kCustEmail;
      final c = await login(cEmail, graceEmail != null ? 'QaSignup12345!' : kCustPw);
      final uid = sqlInt("select id from users where email='$cEmail'");
      final rowsBefore = sqlInt('select count(*) from user_consents where user_id=$uid');
      final me1 = await c.api.me();
      final raw1 = (rawData(c) as Map)['consents'];
      rec('c', 'existing user /me consents.needsReconsent == true', me1.needsReconsent && me1.consents != null,
          'rows before=$rowsBefore raw=${j(raw1)}');
      rec('f', '/me consents shape parses (all keys the app reads)',
          raw1 is Map &&
              raw1.containsKey('termsVersion') &&
              raw1.containsKey('termsAcceptedAt') &&
              raw1.containsKey('privacyVersion') &&
              raw1.containsKey('privacyAcceptedAt') &&
              raw1.containsKey('currentTermsVersion') &&
              raw1.containsKey('currentPrivacyVersion') &&
              raw1['needsReconsent'] is bool &&
              me1.consents!.currentTermsVersion == legal?.termsVersion &&
              me1.consents!.acceptVersion != null,
          'keys=${raw1 is Map ? raw1.keys.toList() : raw1} parsed acceptVersion=${me1.consents?.acceptVersion} current=${me1.consents?.currentTermsVersion}/${me1.consents?.currentPrivacyVersion}');
      final v = me1.consents!.acceptVersion;
      final accepted = await c.api.recordConsents(version: v);
      final call = c.rec.calls.last;
      rec('c', 'POST /v1/me/consents (acceptVersion=$v) -> 201', call.status == 201 && accepted != null, 'status=${call.status} body=${j(call.respBody)}');
      rec('c', 'response needsReconsent == false', accepted?.needsReconsent == false, 'accepted=${accepted?.needsReconsent} terms=${accepted?.termsVersion}@${accepted?.termsAcceptedAt}');
      final me2 = await c.api.me();
      rec('c', '/me afterwards needsReconsent == false', !me2.needsReconsent, 'consents=${j((rawData(c) as Map)['consents'])}');
      final rows = consentRows(uid);
      stdout.writeln('INFO consent rows for demo ($uid):\n$rows');
      final n1 = sqlInt('select count(*) from user_consents where user_id=$uid');
      rec('c', 'SQL: terms+privacy rows exist (source=mobile, ua set)',
          n1 - rowsBefore == 2 && rows.split('\n').every((l) => l.split('|')[3] == 'mobile' && l.split('|')[4] != '~NULL~'), 'rows=\n$rows');
      // replay
      final again = await c.api.recordConsents(version: v);
      final call2 = c.rec.calls.last;
      final n2 = sqlInt('select count(*) from user_consents where user_id=$uid');
      final me3 = await c.api.me();
      rec('c', 'replayed POST: 201, still needsReconsent false, only appends (append-only record)',
          call2.status == 201 && again?.needsReconsent == false && !me3.needsReconsent && n2 - n1 == 2,
          'status=${call2.status} rows $n1 -> $n2 me.needsReconsent=${me3.needsReconsent}');
      // stale version rejected
      Object? bad;
      try {
        await c.api.recordConsents(version: '2099-01-01');
      } on ApiException catch (e) {
        bad = e;
      }
      rec('c', 'POST with a non-current version -> 422 fields.version', bad is ApiException && bad.status == 422 && (bad.fields?.containsKey('version') ?? false),
          bad is ApiException ? '${bad.status} ${bad.fields}' : 'no error: $bad');
    });

    // ── e) tasker cancel preview == actual ────────────────────────────────
    int? svc;
    final situations = <Map<String, dynamic>>[
      {'name': 'S1 free cancel (+6h)', 'min': 360, 'cons': 0, 'c30': 0, 'pen': 0},
      {'name': 'S2 late cancel, fine, last-minute penalty (+2h)', 'min': 120, 'cons': 1, 'c30': 1, 'pen': 10},
      {'name': 'S3 late cancel, fine, normal penalty (+3.5h)', 'min': 210, 'cons': 0, 'c30': 0, 'pen': 0},
      {'name': 'S4 TOO_LATE_1H blocked (+30m)', 'min': 30, 'cons': 1, 'c30': 1, 'pen': 10},
      {'name': 'S5 free cancel -> permanent ban (+6h, consecutive 2->3)', 'min': 360, 'cons': 2, 'c30': 2, 'pen': 0},
      {'name': 'S6 late cancel + 7-day suspension (+2h, c30 4->5)', 'min': 120, 'cons': 0, 'c30': 4, 'pen': 0},
      {'name': 'S7 free cancel + 30-day suspension (+6h, c30 7->8)', 'min': 360, 'cons': 0, 'c30': 7, 'pen': 0},
    ];
    for (final s in situations) {
      test('e) ${s['name']}', () async {
        final cust = await login(kCustEmail, kCustPw);
        final tsk = await login(kTaskerEmail, kTaskerPw);
        svc ??= (await cust.api.services(limit: 5)).items.any((e) => e.id == 90) ? 90 : (await cust.api.services(limit: 5)).items.first.id;
        final b = await cust.api.createBooking(draft(svc!, 'release-i cancel ${s['name']}'));
        final bookingId = b.bookingId;
        probeBookings.add(bookingId);
        final jobId = sqlInt('select id from jobs where booking_id=$bookingId order by id desc limit 1');
        sql('update taskers set is_banned=false, banned_reason=null, banned_at=null, suspended_until=null where id=1');
        String claim = 'claimed via app';
        try {
          await tsk.api.claimJob(jobId);
        } on ApiException catch (e) {
          claim = 'claim failed ${e.status} ${e.code}; assigned by SQL';
          sql("update jobs set tasker_id=1, status='active' where id=$jobId");
        }
        // move the slot and set the discipline counters for this situation
        sql("update bookings set scheduled_at = now() + interval '${s['min']} minutes' where id=$bookingId");
        setTasker(s['cons'] as int, s['c30'] as int, s['pen'] as int);
        final jobPre = sql("select status||'|'||coalesce(tasker_id::text,'-') from jobs where id=$jobId");
        final bookPre = sql('select status from bookings where id=$bookingId');
        final tPre = taskerState();
        final wPre = wallet();
        final maxFine = sqlInt('select coalesce(max(id),0) from tasker_fines');
        final maxCanc = sqlInt('select coalesce(max(id),0) from cancellations');

        // preview via the app method, + job detail cancelPreview
        final p = await tsk.api.taskerCancelPreview(jobId);
        final prevCall = tsk.rec.calls.last;
        final prevRaw = (rawData(tsk) as Map).cast<String, dynamic>();
        final detail = await tsk.api.taskerJobDetail(jobId);
        final dp = detail.cancelPreview;
        stdout.writeln('INFO ${s['name']}: job=$jobId booking=$bookingId $claim jobPre=$jobPre bookPre=$bookPre tPre=${j(tPre)} wallet=$wPre');
        stdout.writeln('INFO preview raw: ${j(prevRaw, 1500)}');
        expect(p, isNotNull);
        final strike = (prevRaw['strike'] as Map?) ?? {};
        final reasonCode = p!.reasons.isNotEmpty ? p.reasons.first.code : 'other';

        // real cancel through the app's cancelJob
        ApiException? err;
        Map<String, dynamic>? cancelRes;
        final key = uuidV4();
        try {
          cancelRes = await tsk.api.cancelJob(jobId, reasonCode: reasonCode, idempotencyKey: key);
        } on ApiException catch (e) {
          err = e;
        }
        final cancelCall = tsk.rec.calls.last;
        final tPost = taskerState();
        final wPost = wallet();
        final jobPost = sql("select status||'|'||coalesce(tasker_id::text,'-') from jobs where id=$jobId");
        final bookPost = sql('select status from bookings where id=$bookingId');
        final fineRows = sql("select id||'|'||amount_vnd::bigint||'|'||kind||'|'||status from tasker_fines where id>$maxFine order by id");
        final fineAmt = fineRows.isEmpty ? 0 : fineRows.split('\n').map((l) => int.parse(l.split('|')[1])).fold<int>(0, (a, b) => a + b);
        final cancRow = sql("select id||'|'||reason_code||'|'||fee_vnd::bigint||'|'||penalty_score||'|'||coalesce(fine_id::text,'-')||'|'||fine_amount_vnd::bigint from cancellations where id>$maxCanc order by id");
        final penaltyDelta = int.parse(tPost['penalty']!) - int.parse(tPre['penalty']!);
        final banned = tPost['is_banned'] == 'true';
        final susp = tPost['suspended_until'] != '~';
        stdout.writeln('INFO cancel -> status=${cancelCall.status} err=${err?.code} res=${j(cancelRes ?? cancelCall.respBody)}');
        stdout.writeln('INFO after: tPost=${j(tPost)} wallet=$wPost fines="$fineRows" canc="$cancRow" job=$jobPost booking=$bookPost');

        final id = (s['name'] as String).split(' ').first;
        final cmp = <String, dynamic>{};
        if (!p.canCancel) {
          rec('e', '$id preview canCancel=false blockedCode=TOO_LATE_1H', p.blockedCode == 'TOO_LATE_1H', 'blockedCode=${p.blockedCode} label=${p.blockedLabel} fineVnd=${p.fineVnd}');
          rec('e', '$id job detail cancelPreview agrees (canCancel=false)', dp != null && dp.canCancel == false && dp.blockedCode == p.blockedCode, 'detail=${dp?.canCancel}/${dp?.blockedCode}');
          rec('e', '$id cancel POST rejected', err != null && cancelCall.status != null && cancelCall.status! >= 400 && cancelCall.status! < 500,
              'status=${cancelCall.status} code=${err?.code} msg=${err?.message}');
          rec('e', '$id nothing changed (counters, wallet, fines, job, booking)',
              j(tPre) == j(tPost) && wPre == wPost && fineRows.isEmpty && cancRow.isEmpty && jobPre == jobPost && bookPre == bookPost,
              'tasker pre=${j(tPre)} post=${j(tPost)} wallet $wPre->$wPost fines="$fineRows" job $jobPre->$jobPost booking $bookPre->$bookPost');
          cmp.addAll({'preview': prevRaw, 'cancelStatus': cancelCall.status, 'cancelCode': err?.code, 'unchanged': j(tPre) == j(tPost) && wPre == wPost});
        } else {
          rec('e', '$id cancel POST succeeded', err == null && cancelCall.status == 200, 'status=${cancelCall.status} err=${err?.code} res=${j(cancelRes)}');
          rec('e', '$id fineVnd(${p.fineVnd}) == created fine row amount ($fineAmt)', p.fineVnd == fineAmt && (p.fineVnd == 0) == fineRows.isEmpty, 'fine rows="$fineRows"');
          rec('e', '$id fine == wallet debit (${wPre - wPost})', wPre - wPost == p.fineVnd, 'wallet $wPre -> $wPost');
          rec('e', '$id fine == cancellations.fine_amount_vnd', cancRow.isNotEmpty && int.parse(cancRow.split('|')[5]) == p.fineVnd, 'cancellations="$cancRow"');
          rec('e', '$id strike.countAfter(${strike['countAfter']}) == consecutive_cancels after (${tPost['consecutive']})', strike['countAfter'].toString() == tPost['consecutive'], '');
          rec('e', '$id strike.cancels30dAfter(${strike['cancels30dAfter']}) == cancellations_30d after (${tPost['c30']})', strike['cancels30dAfter'].toString() == tPost['c30'], '');
          rec('e', '$id penaltyScoreAdd(${strike['penaltyScoreAdd']}) == penalty_score delta ($penaltyDelta)', strike['penaltyScoreAdd'] == penaltyDelta && cancRow.split('|')[3] == penaltyDelta.toString(), 'cancellations.penalty_score=${cancRow.split('|')[3]}');
          final cons = p.consequence;
          final okBlock = p.willBlock == (banned || susp) &&
              (cons == 'permanent' ? banned : cons == null ? (!banned && !susp) : (susp && !banned));
          rec('e', '$id willBlock(${p.willBlock}) / consequence($cons) == tasker state after (banned=$banned suspended=${tPost['suspended_until']})', okBlock, 'banned_reason=${tPost['banned_reason']}');
          if (cons != null && cons.startsWith('suspend')) {
            final days = cons == 'suspend_30d' ? 30 : 7;
            final bu = DateTime.tryParse(p.blockedUntil ?? '');
            final su = DateTime.tryParse(tPost['suspended_until']!.replaceFirst(' ', 'T').replaceFirst('+00', 'Z'));
            final close = bu != null && su != null && bu.difference(su).abs().inSeconds < 120 && (su.difference(DateTime.now()).inHours - days * 24).abs() <= 1;
            rec('e', '$id preview.blockedUntil ~ suspended_until (+${days}d)', close, 'preview=${p.blockedUntil} sql=${tPost['suspended_until']}');
          }
          final jobStatusPost = jobPost.split('|')[0];
          rec('e', '$id repooled(${p.repooled}) == job status after ($jobStatusPost, booking $bookPost)',
              p.repooled ? (jobStatusPost == 'pending' && jobPost.endsWith('|-')) : jobStatusPost == 'cancelled', 'job $jobPre -> $jobPost; booking $bookPre -> $bookPost');
          rec('e', '$id reason code sent ($reasonCode) stored on cancellation', cancRow.split('|')[1] == reasonCode, 'cancellations="$cancRow" serverReasons=${p.reasons.map((r) => r.code).toList()}');
          rec('e', '$id job detail cancelPreview == endpoint preview', dp != null && dp.fineVnd == p.fineVnd && dp.willBlock == p.willBlock && dp.consequence == p.consequence && dp.repooled == p.repooled && dp.canCancel, 'detail fine=${dp?.fineVnd} willBlock=${dp?.willBlock}');
          rec('e', '$id cancel response repooled == preview', (cancelRes?['repooled'] ?? p.repooled) == p.repooled, 'res=${j(cancelRes)}');
          cmp.addAll({
            'preview': prevRaw,
            'cancelRes': cancelRes,
            'fineRows': fineRows,
            'walletDelta': wPost - wPre,
            'penaltyDelta': penaltyDelta,
          });
        }
        scenarios.add({
          'id': id,
          'name': s['name'],
          'jobId': jobId,
          'bookingId': bookingId,
          'minutesToSlot': s['min'],
          'countersBefore': {'consecutive': tPre['consecutive'], 'c30': tPre['c30'], 'penalty': tPre['penalty']},
          'taskerAfter': tPost,
          'jobBefore': jobPre,
          'jobAfter': jobPost,
          'bookingBefore': bookPre,
          'bookingAfter': bookPost,
          'walletBefore': wPre,
          'walletAfter': wPost,
          'cancellationRow': cancRow,
          'previewTrace': prevCall.traceId,
          'cancelTrace': cancelCall.traceId,
          ...cmp,
        });
        // restore tasker state before the next situation
        sql('update taskers set is_banned=false, banned_reason=null, banned_at=null, suspended_until=null where id=1');
        setTasker(int.parse(taskerBefore['consecutive']!), int.parse(taskerBefore['c30']!), int.parse(taskerBefore['penalty']!));
        sql("update jobs set status='closed' where id=$jobId and status in ('pending','open')");
      });
    }

    // ── d) become-tasker multipart consent ────────────────────────────────
    test('d) become-tasker multipart consent_terms/consent_privacy/consent_version', () async {
      final phone = '+849${(10000000 + rnd.nextInt(89999999))}';
      final bytes = File('$kQaRoot/fixtures/real.jpg').readAsBytesSync();
      final files = [for (final k in ['cccd_front', 'cccd_back', 'selfie']) KycUploadFile(kind: k, filename: '$k.jpg', bytes: bytes, mimeType: 'image/jpeg')];
      final c = mk();
      legal ??= await c.api.legal();
      await budget('I-SUITE d become-tasker consent');
      // OTP minted AFTER the budget wait (it lives 10 min)
      final r = Process.runSync('node', ['$kQaRoot/scripts/e2e/otp.mjs', phone, 'register']);
      final otp = (r.stdout as String).trim();
      expect(otp, matches(RegExp(r'^\d{6}$')), reason: 'otp minted: ${r.stderr}');
      final payload = ConsentPayload.forLegal(legal);
      int? uid;
      ApiException? err;
      try {
        uid = await c.api.becomeTasker(
            phone: phone, otpCode: otp, name: 'QA Release I', city: 'Hồ Chí Minh', district: 'Quận 1', files: files, consent: payload);
      } on ApiException catch (e) {
        err = e;
      }
      final call = c.rec.calls.last;
      rec('d', 'become-tasker with consent fields -> 200/201 {userId}', uid != null && uid > 0 && (call.status == 200 || call.status == 201),
          'status=${call.status} userId=$uid fields=${payload?.toFormFields()} ${err == null ? '' : '${err.code} ${err.fields}'}');
      if (uid != null) {
        createdUsers.add('$phone become-tasker (id=$uid)');
        final rows = consentRows(uid);
        stdout.writeln('INFO consent rows become-tasker $uid:\n$rows');
        final ls = rows.split('\n').where((l) => l.isNotEmpty).toList();
        final kinds = ls.map((l) => l.split('|')[0]).toList()..sort();
        rec('d', 'SQL user_consents: terms + privacy rows (version=${payload!.version}, source=mobile)',
            kinds.join(',') == 'privacy,terms' && ls.every((l) => l.split('|')[1] == payload.version && l.split('|')[3] == 'mobile' && l.split('|')[4] != '~NULL~'),
            'rows=\n$rows');
        rec('d', 'users.role == pending_tasker', sql('select role from users where id=$uid') == 'pending_tasker', 'role=${sql('select role from users where id=$uid')}');
      }
    });

    // ── g) wire proof: the new app never sent per-document versions to release-i ──
    test('g) wire capture: no termsVersion/privacyVersion/consent_*_version ever sent', () {
      final f = File('$kQaRoot/logs/J-req-capture.jsonl');
      final mine = f.existsSync()
          ? f.readAsLinesSync().where((l) => l.contains('"tag":"release-i-live"')).map((l) => jsonDecode(l) as Map).toList()
          : <Map>[];
      final since = DateTime.fromMillisecondsSinceEpoch(int.parse(tag));
      final run = mine.where((m) => DateTime.parse(m['ts'] as String).isAfter(since.subtract(const Duration(seconds: 1)))).toList();
      final bad = run.where((m) {
        final b = jsonEncode(m['body']);
        return b.contains('termsVersion') || b.contains('privacyVersion') || b.contains('consent_terms_version') || b.contains('consent_privacy_version');
      }).toList();
      rec('g', 'captured ${run.length} consent-related requests; none carries per-document versions', run.length >= 4 && bad.isEmpty,
          'paths=${run.map((m) => m['path']).toList()} offenders=${bad.length}; sample=${run.isEmpty ? '' : jsonEncode(run.first['body'])}');
      bool isLegacy(Map m) {
        final b = m['body'];
        if (b is! Map) return false;
        final c = b['consent'];
        return (c is Map && c.containsKey('version')) || b.containsKey('consent_version') ||
            (m['path'].toString().endsWith('/me/consents') && b.containsKey('version'));
      }

      final legacy = run.where(isLegacy);
      rec('g', 'legacy single version (min/max/consent_version) is what was sent', legacy.length >= 3, 'legacy-shaped requests=${legacy.length}');
    });
  });
}
