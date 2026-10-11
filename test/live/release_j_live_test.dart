// Release-j (kyco c96c4ca0) consent verification against the lab on 127.0.0.1:4142. QA only; lab only.
//   flutter test test/live/release_j_live_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 \
//     --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
//
// Real KycoApi + models + the app's own 422 -> copy mapping (apiErrorText).
// Signup budget: /v1/auth/signup, /v1/signup/quick and /v1/become-tasker have separate limiter keys (3 / window each).
// Evidence: $QA/out/mobile/release-j-live.result.json and $QA/logs/J-req-capture.jsonl (request bodies).
@Tags(['live'])
@Timeout(Duration(minutes: 60))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/ui/error_text.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import 'live_support_rd.dart';

final checks = <Map<String, dynamic>>[];
final createdUsers = <String>[];
final notes = <String>[];
final rnd = Random();
final vi = lookupAppLocalizations(const Locale('vi'));

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
    ..interceptors.add(CaptureInterceptor('release-j-live'));
  return LiveClient(KycoApi(KycoApiClient(tokens: store, dio: dio), store), r, store);
}

Dio rawDio() => Dio(BaseOptions(baseUrl: kApiBase, validateStatus: (_) => true, headers: {'accept': 'application/json'}))
  ..interceptors.add(CaptureInterceptor('release-j-live'));

dynamic rawData(LiveClient c) {
  final b = c.rec.calls.last.respBody;
  return b is Map && b.containsKey('data') ? b['data'] : b;
}

Future<LiveClient> login(String email, String pw) async {
  await paceLogin();
  final c = mk();
  await c.api.login(email: email, password: pw);
  return c;
}

// ---- signup budget, per limiter key (3 per ~15 min), shared through the state file --------------------
final _own = <String, List<DateTime>>{};
Future<void> budget(String route, String note) async {
  final bf = File('$kQaRoot/state/signup-budget.json');
  final list = bf.existsSync() ? (jsonDecode(bf.readAsStringSync()) as List) : [];
  final at = _own.putIfAbsent(route, () => []);
  if (at.isEmpty) {
    for (final e in list) {
      final m = e as Map;
      // entries without a route (older suites) count against every route (conservative)
      if (m['route'] == null || m['route'] == route) {
        final t = DateTime.fromMillisecondsSinceEpoch(m['ts'] as int);
        if (DateTime.now().difference(t) < const Duration(seconds: 905)) at.add(t);
      }
    }
  }
  while (true) {
    final now = DateTime.now();
    at.removeWhere((t) => now.difference(t) > const Duration(seconds: 905));
    if (at.length < 3) break;
    final wait = const Duration(seconds: 906) - now.difference(at.first);
    stdout.writeln('INFO signup budget [$route] full: waiting ${wait.inSeconds}s');
    await Future<void>.delayed(wait + const Duration(seconds: 1));
  }
  at.add(DateTime.now());
  final cur = bf.existsSync() ? (jsonDecode(bf.readAsStringSync()) as List) : [];
  cur.add({'pkg': 'J-SUITE', 'route': route, 'ts': DateTime.now().millisecondsSinceEpoch, 'note': note});
  bf.writeAsStringSync(const JsonEncoder.withIndent(' ').convert(cur));
}

String consentRows(int uid) => sql(
    "select kind||'|'||version||'|'||source||'|'||coalesce(left(user_agent,30),'~NULL~') from user_consents where user_id=$uid order by id");

List<String> rowsOf(int uid) => consentRows(uid).split('\n').where((l) => l.isNotEmpty).toList();

/// Friendly copy for a 422 the way the screens render it.
String copy(Map<String, dynamic> fields) =>
    apiErrorText(vi, ApiException('VALIDATION', 'Request failed', status: 422, fields: fields.map((k, v) => MapEntry(k, '$v'))));

Map<String, dynamic>? fieldsOf(Object? body) => body is Map && body['fields'] is Map ? (body['fields'] as Map).cast<String, dynamic>() : null;

void main() {
  group('release-j live verification', skip: kLive ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    LegalInfo? legal;
    Map<String, dynamic>? legalRaw;
    final tag = DateTime.now().millisecondsSinceEpoch.toString();
    int? signupUid;
    String? signupEmail;

    setUpAll(() {
      guardLab();
      Directory('$kQaRoot/out/mobile').createSync(recursive: true);
    });

    tearDownAll(() {
      final fails = checks.where((c) => c['ok'] != true).length;
      writeJson('$kQaRoot/out/mobile/release-j-live.result.json', {
        'pkg': 'release-j-live',
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'pass': checks.length - fails,
        'fail': fails,
        'createdUsers': createdUsers,
        'notes': notes,
        'checks': checks,
      });
      stdout.writeln('release-j-live: pass=${checks.length - fails} fail=$fails');
    });

    test('a) GET /v1/legal advertises consentSchema 2 and the app switches to per-document', () async {
      final c = mk();
      legal = await c.api.legal();
      legalRaw = (rawData(c) as Map).cast<String, dynamic>();
      rec('a', 'GET /v1/legal -> 200', c.rec.calls.last.status == 200, 'status=${c.rec.calls.last.status} raw=${j(legalRaw)}');
      rec('a', 'consentSchema == 2 in the body', legalRaw!['consentSchema'] == 2, 'consentSchema=${legalRaw!['consentSchema']}');
      rec('a', 'app parses it: perDocumentConsent', legal!.consentSchema == 2 && legal!.perDocumentConsent, 'parsed=${legal!.consentSchema}');
      final p = ConsentPayload.forLegal(legal)!;
      rec('a', 'payload is {terms,privacy,termsVersion,privacyVersion} with NO version', j(p.toJson()) == j({'terms': true, 'privacy': true, 'termsVersion': legal!.termsVersion, 'privacyVersion': legal!.privacyVersion}), j(p.toJson()));
      rec('a', 'multipart fields use consent_terms_version / consent_privacy_version', p.toFormFields().containsKey('consent_terms_version') && !p.toFormFields().containsKey('consent_version'), j(p.toFormFields()));
      notes.add('server defines ONE known revision per document (KNOWN_VERSIONS terms/privacy = [${legal!.termsVersion}]) -> '
          'the "older-but-known" case (recorded, needsReconsent stays true) and diverging per-document versions cannot be exercised live; covered by unit tests only.');
    });

    // ── /auth/signup ──────────────────────────────────────────────────────
    test('b) POST /v1/auth/signup 422s: all three version keys, then false terms', () async {
      await budget('v1:signup', 'J-SUITE b signup bad versions');
      final dio = rawDio();
      final email = 'qa.j.bad.$tag@qa.local';
      final before = sqlInt("select count(*) from users where email='$email'");
      var r = await dio.post('/auth/signup', data: {
        'email': email, 'password': 'QaSignup12345!', 'name': 'QA J Bad',
        'consent': {'terms': true, 'privacy': true, 'version': '2099-01-01', 'termsVersion': '2026-01-01', 'privacyVersion': '2099-01-01'},
      });
      var f = fieldsOf(r.data);
      rec('b', 'signup unknown/newer versions -> 422', r.statusCode == 422, 'status=${r.statusCode} body=${j(r.data)}');
      rec('b', 'fields keys == consent.version + consent.termsVersion + consent.privacyVersion',
          f != null && f.containsKey('consent.version') && f.containsKey('consent.termsVersion') && f.containsKey('consent.privacyVersion'), 'fields=${j(f)}');
      rec('b', 'app copy for those keys == consentVersionInvalid', f != null && copy(f) == vi.consentVersionInvalid, 'copy="${f == null ? '' : copy(f)}"');
      await budget('v1:signup', 'J-SUITE b signup false terms');
      r = await dio.post('/auth/signup', data: {
        'email': email, 'password': 'QaSignup12345!', 'name': 'QA J Bad',
        'consent': {'terms': false, 'privacy': true, 'termsVersion': legal!.termsVersion, 'privacyVersion': legal!.privacyVersion},
      });
      f = fieldsOf(r.data);
      rec('b', 'signup terms:false -> 422 fields.consent', r.statusCode == 422 && f != null && f.containsKey('consent'), 'status=${r.statusCode} fields=${j(f)}');
      rec('b', 'app copy for fields.consent == consentRequired', f != null && copy(f) == vi.consentRequired, 'copy="${f == null ? '' : copy(f)}"');
      rec('b', 'no user created by the 422s', sqlInt("select count(*) from users where email='$email'") == before, 'rows=${sqlInt("select count(*) from users where email='$email'")}');
    });

    test('b) signup with the app payload (per-document) -> 201 + rows carrying the versions', () async {
      await budget('v1:signup', 'J-SUITE b signup per-document');
      final c = mk();
      final email = 'qa.j.$tag@qa.local';
      final payload = ConsentPayload.forLegal(legal);
      final before = sqlInt('select count(*) from user_consents');
      AuthResult? res;
      ApiException? err;
      try {
        res = await c.api.signup(email: email, password: 'QaSignup12345!', name: 'QA ReleaseJ', consent: payload);
      } on ApiException catch (e) {
        err = e;
      }
      final call = c.rec.calls.last;
      rec('b', 'signup(ConsentPayload per-document) -> 201', res != null && call.status == 201,
          'status=${call.status} reqKeys=${call.reqKeys} ${err == null ? '' : '${err.code} ${err.fields}'} trace=${call.traceId}');
      signupEmail = email;
      signupUid = res?.user?.id ?? sqlInt("select id from users where email='$email'");
      createdUsers.add('$email (id=$signupUid)');
      final rows = rowsOf(signupUid!);
      stdout.writeln('INFO rows for $signupUid:\n${rows.join('\n')}');
      final kinds = rows.map((l) => l.split('|')[0]).toList()..sort();
      rec('b', 'user_consents: exactly terms + privacy', kinds.join(',') == 'privacy,terms', 'rows=$rows');
      final tv = rows.firstWhere((l) => l.startsWith('terms|'), orElse: () => '||').split('|')[1];
      final pv = rows.firstWhere((l) => l.startsWith('privacy|'), orElse: () => '||').split('|')[1];
      rec('b', 'terms row version == termsVersion, privacy row == privacyVersion', tv == legal!.termsVersion && pv == legal!.privacyVersion, 'terms=$tv privacy=$pv legal=${legal!.termsVersion}/${legal!.privacyVersion}');
      rec('b', 'source == mobile, user_agent recorded', rows.every((l) => l.split('|')[2] == 'mobile' && l.split('|')[3] != '~NULL~'), 'rows=$rows');
      rec('b', 'rows added == 2', sqlInt('select count(*) from user_consents') - before == 2, 'delta=${sqlInt('select count(*) from user_consents') - before}');
      final me = await c.api.me();
      rec('b', 'new user /me needsReconsent == false', me.consents != null && !me.needsReconsent, 'consents=${j((rawData(c) as Map)['consents'])}');
    });

    // ── /signup/quick ─────────────────────────────────────────────────────
    String qphone() => '09${10000000 + rnd.nextInt(89999999)}';

    test('c) POST /v1/signup/quick: bad per-document versions via the app, false privacy, then valid', () async {
      final email = 'qa.j.q.$tag@qa.local';
      final phone = qphone();
      final c = mk();
      await budget('v1:signup:quick', 'J-SUITE c quick bad versions (app payload)');
      ApiException? e1;
      try {
        await c.api.quickSignup(
            phone: phone, email: email, password: 'QaSignup12345!', name: 'QA J Quick',
            consent: const ConsentPayload(termsVersion: '2026-01-01', privacyVersion: '2099-01-01'));
      } on ApiException catch (e) {
        e1 = e;
      }
      rec('c', 'quick signup unknown termsVersion + newer privacyVersion -> 422 with both keys',
          e1 != null && e1.status == 422 && (e1.fields?.containsKey('consent.termsVersion') ?? false) && (e1.fields?.containsKey('consent.privacyVersion') ?? false),
          e1 == null ? 'no error' : '${e1.status} ${e1.fields}');
      rec('c', 'app copy (apiErrorText) == consentVersionInvalid', e1 != null && apiErrorText(vi, e1) == vi.consentVersionInvalid, 'copy="${e1 == null ? '' : apiErrorText(vi, e1)}"');
      await budget('v1:signup:quick', 'J-SUITE c quick false privacy');
      final r = await rawDio().post('/signup/quick', data: {
        'phone': phone, 'email': email, 'password': 'QaSignup12345!', 'name': 'QA J Quick',
        'consent': {'terms': true, 'privacy': false, 'termsVersion': legal!.termsVersion, 'privacyVersion': legal!.privacyVersion},
      });
      final f = fieldsOf(r.data);
      rec('c', 'quick signup privacy:false -> 422 fields.consent', r.statusCode == 422 && f != null && f.containsKey('consent'), 'status=${r.statusCode} fields=${j(f)}');
      await budget('v1:signup:quick', 'J-SUITE c quick per-document valid');
      ApiException? e3;
      try {
        await c.api.quickSignup(phone: phone, email: email, password: 'QaSignup12345!', name: 'QA J Quick', consent: ConsentPayload.forLegal(legal));
      } on ApiException catch (e) {
        e3 = e;
      }
      final call = c.rec.calls.last;
      rec('c', 'quick signup per-document -> 201', e3 == null && call.status == 201, 'status=${call.status} ${e3 == null ? '' : '${e3.code} ${e3.fields}'}');
      final uid = sqlInt("select id from users where email='$email'");
      createdUsers.add('$email (quick id=$uid)');
      final rows = rowsOf(uid);
      rec('c', 'quick signup rows: terms + privacy at the legal versions',
          rows.length == 2 && rows.any((l) => l.startsWith('terms|${legal!.termsVersion}|')) && rows.any((l) => l.startsWith('privacy|${legal!.privacyVersion}|')), 'rows=$rows');
    });

    // ── POST /me/consents ─────────────────────────────────────────────────
    test('d) POST /v1/me/consents: 422 keys (no rows written), then per-document re-consent', () async {
      // user 22-style grace user (no consent rows) if still pristine, else the user signed up in (b)
      var email = 'qa.i.nocons.1791663273726@qa.local';
      var pw = 'QaSignup12345!';
      final pristine = sqlInt("select count(*) from user_consents where user_id=(select id from users where email='$email')") == 0 &&
          sqlInt("select count(*) from users where email='$email'") == 1;
      if (!pristine) {
        email = signupEmail ?? email;
        notes.add('grace user already consented; re-consent exercised on the (b) signup user');
      }
      final c = await login(email, pw);
      final uid = sqlInt("select id from users where email='$email'");
      final me0 = await c.api.me();
      final raw0 = (rawData(c) as Map)['consents'] as Map?;
      rec('d', 'user $uid /me consents: ${pristine ? 'needsReconsent true' : 'consented'}; current versions present',
          raw0 != null && raw0['currentTermsVersion'] == legal!.termsVersion && raw0['currentPrivacyVersion'] == legal!.privacyVersion && me0.needsReconsent == pristine, 'consents=${j(raw0)}');
      final n0 = sqlInt('select count(*) from user_consents where user_id=$uid');

      Future<ApiException?> tryPost({String? version, String? tv, String? pv}) async {
        try {
          await c.api.recordConsents(version: version, termsVersion: tv, privacyVersion: pv);
          return null;
        } on ApiException catch (e) {
          return e;
        }
      }

      final cases = <String, ({String? version, String? tv, String? pv, List<String> keys})>{
        'newer termsVersion': (version: null, tv: '2099-01-01', pv: legal!.privacyVersion, keys: ['consent.termsVersion']),
        'unknown-older privacyVersion': (version: null, tv: legal!.termsVersion, pv: '2026-01-01', keys: ['consent.privacyVersion']),
        'newer legacy version': (version: '2099-01-01', tv: null, pv: null, keys: ['consent.version']),
      };
      for (final e in cases.entries) {
        final err = await tryPost(version: e.value.version, tv: e.value.tv, pv: e.value.pv);
        final ks = err?.fields?.keys.toSet() ?? <String>{};
        rec('d', 'me/consents ${e.key} -> 422 ${e.value.keys}', err != null && err.status == 422 && ks.containsAll(e.value.keys) && ks.length == e.value.keys.length, err == null ? 'no error' : '${err.status} ${err.fields}');
        rec('d', 'me/consents ${e.key}: app copy == consentVersionInvalid', err != null && apiErrorText(vi, err) == vi.consentVersionInvalid, 'copy="${err == null ? '' : apiErrorText(vi, err)}"');
      }
      // false terms / privacy: raw (the app never sends false)
      final tok = await c.store.accessToken;
      Future<Response<dynamic>> rawConsent(Map<String, dynamic> b) =>
          rawDio().post('/me/consents', data: b, options: Options(headers: {'authorization': 'Bearer $tok'}));
      var r = await rawConsent({'terms': false, 'privacy': true});
      var f = fieldsOf(r.data);
      rec('d', 'me/consents terms:false -> 422 fields.terms', r.statusCode == 422 && f != null && f.containsKey('terms'), 'status=${r.statusCode} fields=${j(f)} body=${j(r.data)}');
      rec('d', 'app copy for fields.terms == consentRequired', f != null && copy(f) == vi.consentRequired, 'copy="${f == null ? '' : copy(f)}"');
      r = await rawConsent({'terms': true, 'privacy': false});
      f = fieldsOf(r.data);
      rec('d', 'me/consents privacy:false -> 422 fields.privacy', r.statusCode == 422 && f != null && f.containsKey('privacy'), 'status=${r.statusCode} fields=${j(f)}');
      rec('d', 'app copy for fields.privacy == consentRequired', f != null && copy(f) == vi.consentRequired, 'copy="${f == null ? '' : copy(f)}"');
      rec('d', 'no consent rows written by any 422', sqlInt('select count(*) from user_consents where user_id=$uid') == n0, 'rows $n0 -> ${sqlInt('select count(*) from user_consents where user_id=$uid')}');

      // the app's re-consent path: per-document versions from /me (fallback /legal)
      final per = me0.consents!.perDocumentVersions(legal)!;
      final accepted = await c.api.recordConsents(termsVersion: per.$1, privacyVersion: per.$2);
      final call = c.rec.calls.last;
      rec('d', 'POST /me/consents {termsVersion, privacyVersion} (flat) -> 201', call.status == 201 && accepted != null, 'status=${call.status} body=${j(call.respBody)}');
      rec('d', 'response needsReconsent == false, versions recorded', accepted?.needsReconsent == false && accepted?.termsVersion == per.$1 && accepted?.privacyVersion == per.$2, 'terms=${accepted?.termsVersion} privacy=${accepted?.privacyVersion}');
      final me1 = await c.api.me();
      rec('d', '/me afterwards needsReconsent == false', !me1.needsReconsent, 'consents=${j((rawData(c) as Map)['consents'])}');
      final rows = rowsOf(uid).sublist(n0);
      rec('d', 'SQL: exactly 2 new rows (terms/privacy) at the per-document versions, source mobile',
          rows.length == 2 && rows.any((l) => l.startsWith('terms|${per.$1}|mobile')) && rows.any((l) => l.startsWith('privacy|${per.$2}|mobile')), 'new rows=$rows');
      // legacy single version still honoured by release-j
      final legacy = await c.api.recordConsents(version: per.$1);
      rec('d', 'legacy {version: current} still accepted -> 201 needsReconsent false', c.rec.calls.last.status == 201 && legacy?.needsReconsent == false, 'status=${c.rec.calls.last.status}');
      notes.add('older-but-known re-consent ("recorded, needsReconsent stays true") SKIPPED: the server knows only one revision per document.');
    });

    // ── become-tasker multipart ───────────────────────────────────────────
    test('e) POST /v1/become-tasker multipart: per-document consent_*_version', () async {
      final bytes = File('$kQaRoot/fixtures/real.jpg').readAsBytesSync();
      final files = [for (final k in ['cccd_front', 'cccd_back', 'selfie']) KycUploadFile(kind: k, filename: '$k.jpg', bytes: bytes, mimeType: 'image/jpeg')];
      String otpFor(String phone) {
        final r = Process.runSync('node', ['$kQaRoot/scripts/e2e/otp.mjs', phone, 'register']);
        final otp = (r.stdout as String).trim();
        expect(otp, matches(RegExp(r'^\d{6}$')), reason: 'otp minted: ${r.stderr}');
        return otp;
      }

      final c = mk();
      // 1) unknown consent_privacy_version -> 422 on the documented key
      var phone = '+849${10000000 + rnd.nextInt(89999999)}';
      await budget('v1:become-tasker', 'J-SUITE e become-tasker bad privacy version');
      var otp = otpFor(phone);
      ApiException? err;
      try {
        await c.api.becomeTasker(phone: phone, otpCode: otp, name: 'QA Release J', city: 'Hồ Chí Minh', district: 'Quận 1', files: files,
            consent: ConsentPayload(termsVersion: legal!.termsVersion, privacyVersion: '2099-01-01'));
      } on ApiException catch (e) {
        err = e;
      }
      rec('e', 'become-tasker consent_privacy_version=2099-01-01 -> 422 consent.privacyVersion', err != null && err.status == 422 && (err.fields?.containsKey('consent.privacyVersion') ?? false),
          err == null ? 'no error (accepted!)' : '${err.status} ${err.code} ${err.fields}');
      rec('e', 'app copy == consentVersionInvalid', err != null && apiErrorText(vi, err) == vi.consentVersionInvalid, 'copy="${err == null ? '' : apiErrorText(vi, err)}"');
      rec('e', 'no user created for the rejected phone', sqlInt("select count(*) from users where phone like '%${phone.substring(3)}'") == 0, 'users=${sqlInt("select count(*) from users where phone like '%${phone.substring(3)}'")}');
      // 2) valid per-document
      phone = '+849${10000000 + rnd.nextInt(89999999)}';
      await budget('v1:become-tasker', 'J-SUITE e become-tasker per-document valid');
      otp = otpFor(phone); // minted AFTER the wait (10 min life)
      final payload = ConsentPayload.forLegal(legal)!;
      int? uid;
      ApiException? err2;
      try {
        uid = await c.api.becomeTasker(phone: phone, otpCode: otp, name: 'QA Release J', city: 'Hồ Chí Minh', district: 'Quận 1', files: files, consent: payload);
      } on ApiException catch (e) {
        err2 = e;
      }
      final call = c.rec.calls.last;
      rec('e', 'become-tasker per-document consent fields -> 200/201 {userId}', uid != null && uid > 0 && (call.status == 200 || call.status == 201),
          'status=${call.status} userId=$uid fields=${payload.toFormFields()} ${err2 == null ? '' : '${err2.code} ${err2.fields}'}');
      if (uid != null) {
        createdUsers.add('$phone become-tasker (id=$uid)');
        final rows = rowsOf(uid);
        rec('e', 'rows: terms@${legal!.termsVersion} + privacy@${legal!.privacyVersion}, source mobile',
            rows.length == 2 && rows.any((l) => l.startsWith('terms|${legal!.termsVersion}|mobile')) && rows.any((l) => l.startsWith('privacy|${legal!.privacyVersion}|mobile')), 'rows=$rows');
      }
    });

    // ── wire proof ────────────────────────────────────────────────────────
    test('g) wire capture: schema-2 requests carry per-document versions and no legacy version', () {
      final f = File('$kQaRoot/logs/J-req-capture.jsonl');
      final since = DateTime.fromMillisecondsSinceEpoch(int.parse(tag)).subtract(const Duration(seconds: 1));
      final run = f.readAsLinesSync().map((l) => jsonDecode(l) as Map).where((m) => m['tag'] == 'release-j-live' && DateTime.parse(m['ts'] as String).isAfter(since)).toList();
      bool app(Map m) => true;
      final good = run.where((m) {
        final b = m['body'];
        if (b is! Map) return false;
        final c = b['consent'];
        if (c is Map) return c.containsKey('termsVersion') && c.containsKey('privacyVersion') && !c.containsKey('version');
        return b.containsKey('consent_terms_version') || (b.containsKey('termsVersion') && !b.containsKey('version')) || b.isEmpty;
      });
      rec('g', 'captured ${run.length} requests (${run.where(app).map((m) => m['path'].toString().split('/v1/').last).toSet()})', run.length >= 8, 'good-shaped=${good.length}');
    });
  });
}
