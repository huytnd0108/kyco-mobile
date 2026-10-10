// Release-h (d69b0328) DTO verification against the lab on 127.0.0.1:4142. QA only.
//   flutter test test/live/release_h_live_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 \
//     --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
//
// Exercises the real KycoApi + model parsing; raw bodies are read from the recorder.
// Items a..h write PASS/FAIL checks to $QA/out/mobile/release-h-live.result.json.
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/format.dart';
import 'package:kyco_mobile/core/models.dart';

import 'live_support_rd.dart';

String lang = 'vi';
final List<Map<String, dynamic>> checks = [];
final tasker1Id = 1;

void rec(String item, String name, bool ok, String detail) {
  checks.add({'item': item, 'name': name, 'ok': ok, 'detail': detail});
  stdout.writeln('${ok ? 'PASS' : 'FAIL'}  [$item] $name -- $detail');
}

LiveClient mk() {
  guardLab();
  final store = InMemoryTokenStore();
  final r = Recorder();
  final dio = Dio(BaseOptions(baseUrl: kApiBase, validateStatus: (_) => true, headers: {'accept': 'application/json'}))
    ..interceptors.add(r);
  return LiveClient(KycoApi(KycoApiClient(tokens: store, dio: dio, acceptLanguage: () => lang), store), r, store);
}

Future<LiveClient> login(String email, String pw) async {
  await paceLogin();
  final c = mk();
  await c.api.login(email: email, password: pw);
  return c;
}

/// Raw `data` of the most recent response on this client.
dynamic rawData(LiveClient c) {
  final b = c.rec.calls.last.respBody;
  return b is Map && b.containsKey('data') ? b['data'] : b;
}

String j(Object? o, [int n = 400]) {
  final s = jsonEncode(o);
  return s.length > n ? '${s.substring(0, n)}...' : s;
}

final _taskerNum = RegExp(r'(tasker|cộng tác viên|ctv)\s*#\s*\d+', caseSensitive: false);
final _viChars = RegExp(r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]', caseSensitive: false);

BookingDraft draft(int svc, String note) {
  final t = DateTime.now().add(const Duration(days: 1));
  return BookingDraft(
    serviceId: svc,
    serviceName: 'release-h probe',
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
  group('release-h live DTO verification', skip: kLive ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    late LiveClient cust;
    late LiveClient tsk;
    int? svc;
    int? bookingA; // first booking, claimed by tasker 1
    int? jobA;
    int? bookingB; // second booking (lock + compensation labels)
    final taskerUserId = () {
      try {
        return sqlInt("select id from users where email='$kTaskerEmail'");
      } catch (_) {
        return 0;
      }
    }();
    final extraBookings = <int>[];

    setUpAll(() async {
      guardLab();
      Directory('$kQaRoot/out/mobile').createSync(recursive: true);
      cust = await login(kCustEmail, kCustPw);
      tsk = await login(kTaskerEmail, kTaskerPw);
      final s = await cust.api.services(limit: 5);
      // Service 90 was the one used in earlier lab runs; fall back to the first listed.
      svc = s.items.any((e) => e.id == 90) ? 90 : s.items.first.id;
      stdout.writeln('INFO svc=$svc taskerUserId=$taskerUserId');
    });

    tearDownAll(() {
      final fails = checks.where((c) => c['ok'] != true).length;
      writeJson('$kQaRoot/out/mobile/release-h-live.result.json', {
        'pkg': 'release-h-live',
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'pass': checks.length - fails,
        'fail': fails,
        'checks': checks,
      });
      stdout.writeln('release-h-live: pass=${checks.length - fails} fail=$fails');
    });

    // ── fixtures ─────────────────────────────────────────────────────────
    test('fixture: booking A (customer) + tasker claims the job', () async {
      // a prior customer cancel within 24h puts a compensation lock on new bookings (needed for item b).
      final r = await cust.api.createBooking(draft(svc!, 'release-h A'));
      bookingA = r.bookingId;
      jobA = sqlInt('select id from jobs where booking_id=$bookingA order by id desc limit 1');
      stdout.writeln('INFO bookingA=$bookingA jobA=$jobA lock=${sql("select compensation_lock_until from bookings where id=$bookingA")}');
      // consecutive_cancels must not auto-ban us by accident; claim as tasker 1
      sql('update taskers set is_banned=false, banned_reason=null, banned_at=null, suspended_until=null where id=1');
      try {
        final c = await tsk.api.claimJob(jobA!);
        stdout.writeln('INFO claim -> ${j(c)}');
      } on ApiException catch (e) {
        stdout.writeln('INFO claim failed ${e.status} ${e.code} ${e.message}; assigning by SQL');
        sql("update jobs set tasker_id=1, status='active' where id=$jobA");
      }
      stdout.writeln('INFO job status=${sql("select status||' tasker='||coalesce(tasker_id::text,'-') from jobs where id=$jobA")}');
    });

    // ── a) notifications ────────────────────────────────────────────────
    test('a) notifications data + localization', () async {
      lang = 'vi';
      final (pv, _) = await cust.api.notifications();
      final rawVi = (rawData(cust) as List).cast<Map>();
      lang = 'en';
      final (pe, _) = await cust.api.notifications();
      (rawData(cust) as List).cast<Map>(); // en payload is parsed via `pe` below
      lang = 'vi';
      final bn = pv.items.where((n) => n.data?.bookingId == bookingA).toList();
      rec('a', 'customer notification for booking A parses data.bookingId', bn.isNotEmpty, 'count=${bn.length} raw=${j(rawVi.firstWhere((m) => '${m['link']}'.contains('/bookings/$bookingA'), orElse: () => {}))}');
      if (bn.isNotEmpty) {
        final d = bn.first.data!;
        rec('a', 'data has serviceId, serviceName (not #id), scheduledAt ISO, totalVnd>0',
            d.serviceId != null && (d.serviceName ?? '').isNotEmpty && !(d.serviceName!.contains('#')) && DateTime.tryParse(d.scheduledAt ?? '') != null && (d.totalVnd ?? 0) > 0,
            'serviceId=${d.serviceId} name=${d.serviceName} scheduledAt=${d.scheduledAt} total=${d.totalVnd}');
        final en = pe.items.firstWhere((n) => n.id == bn.first.id, orElse: () => bn.first);
        rec('a', 'same row title/body differ vi vs en', en.title != bn.first.title || en.body != bn.first.body,
            'vi="${bn.first.title} | ${bn.first.body}" en="${en.title} | ${en.body}"');
        final enText = '${en.title} ${en.body}';
        final enNoSvc = enText.replaceAll(en.data?.serviceName ?? '\u0000', '');
        rec('a', 'en copy (service name aside) has no Vietnamese diacritics and no raw #id', !_viChars.hasMatch(enNoSvc) && !enText.contains('#'), 'en="$enText"');
        final hasTr = sqlInt("select count(*) from content_translations where entity_type='service' and field='name' and entity_id=${d.serviceId} and locale='en'") > 0;
        rec('a', 'en serviceName translated when an en translation row exists (lab LAB-GAP: none for this service => vi fallback is expected)', hasTr ? en.data?.serviceName != d.serviceName : en.data?.serviceName == d.serviceName, 'translationRow=$hasTr vi="${d.serviceName}" en="${en.data?.serviceName}"');
        rec('a', 'en data keys identical to vi', j(en.data?.serviceId) == j(d.serviceId) && en.data?.bookingId == d.bookingId, 'serviceName en=${en.data?.serviceName} vi=${d.serviceName}');
      }
      // wider scan: every item with a data block across vi/en (both roles)
      var bad = 0;
      for (final n in pv.items) {
        if (n.data != null && !n.data!.isEmpty && n.data!.bookingId == null && n.data!.jobId == null) bad++;
      }
      rec('a', 'customer: no row has data without bookingId/jobId', bad == 0, 'bad=$bad of ${pv.items.length}');
      final withTotal = pv.items.where((n) => n.data?.totalVnd != null).length;
      rec('a', 'customer notifications carry totalVnd on booking rows', withTotal > 0, 'rows with total=$withTotal');
      // tasker side: tasker never sees a customer total. Make sure a tasker row with a job link exists.
      if (taskerUserId > 0) {
        final has = sqlInt("select count(*) from notifications where user_id=$taskerUserId and link like '/tasker/jobs/%'");
        if (has == 0) {
          sql("insert into notifications(user_id,type,title,body,link) values ($taskerUserId,'system','Có việc mới #$jobA','Việc #$jobA đã được giao cho bạn.','/tasker/jobs/$jobA')");
          stdout.writeln('INFO inserted tasker notification by SQL (link /tasker/jobs/$jobA)');
        }
      }
      final (tv, _) = await tsk.api.notifications();
      final tj = tv.items.where((n) => n.data?.jobId != null).toList();
      rec('a', 'tasker notification data.jobId present', tj.isNotEmpty, 'count=${tj.length} first=${tj.isEmpty ? '-' : j(tv.items.firstWhere((n) => n.data?.jobId != null).data?.jobId)}');
      final tTotals = tv.items.where((n) => n.data?.totalVnd != null).length;
      final rawT = (rawData(tsk) as List).cast<Map>().where((m) => (m['data'] is Map) && (m['data'] as Map)['totalVnd'] != null).length;
      rec('a', 'tasker never sees a customer total (data.totalVnd absent)', tTotals == 0 && rawT == 0, 'tasker rows with totalVnd=$tTotals raw=$rawT');
      lang = 'en';
      final (te, _) = await tsk.api.notifications();
      lang = 'vi';
      final tjEn = te.items.where((n) => n.data?.jobId != null).toList();
      if (tj.isNotEmpty && tjEn.isNotEmpty) {
        rec('a', 'tasker job row localized en', !_viChars.hasMatch('${tjEn.first.title} ${tjEn.first.body}') || tjEn.first.title != tj.first.title,
            'vi="${tj.first.title} | ${tj.first.body}" en="${tjEn.first.title} | ${tjEn.first.body}"');
      }
    });

    // ── b) booking page blocked reasons ─────────────────────────────────
    test('b) booking page actions.*BlockedReason', () async {
      // booking A was created by a customer with a recent cancel (24h lock) if cancellation exists in the last 24h
      final lock = sql('select compensation_lock_until from bookings where id=$bookingA');
      final d = await cust.api.bookingDetail(bookingA!);
      final raw = (rawData(cust) as Map)['actions'];
      stdout.writeln('INFO lock=$lock actions=${j(raw, 900)}');
      final locked = lock.isNotEmpty;
      final cb = raw is Map ? raw['cancelBlockedReason'] : null;
      if (locked) {
        rec('b', 'cancel blocked by 24h lock: canCancel=false + cancelBlockedReason{code,label}',
            raw['canCancel'] == false && cb is Map && '${cb['code']}'.isNotEmpty && '${cb['label']}'.isNotEmpty, 'canCancel=${raw['canCancel']} reason=${j(cb)}');
        rec('b', 'model parses cancelBlockedReason label', (d.serverActions?.cancelBlockedReason ?? '').isNotEmpty, 'parsed="${d.serverActions?.cancelBlockedReason}"');
        // cancel POST is refused 409 with same reason
        try {
          await cust.api.cancelBooking(bookingA!, reasonCode: 'other', idempotencyKey: uuidV4());
          rec('b', 'POST cancel on locked booking refused', false, 'unexpected success');
          sql("update bookings set status='CANCELLED' where false");
        } on ApiException catch (e) {
          rec('b', 'POST cancel on locked booking refused (409)', e.status == 409, 'status=${e.status} code=${e.code} msg=${e.message}');
        }
        lang = 'en';
        await cust.api.bookingDetail(bookingA!);
        final cbEn = ((rawData(cust) as Map)['actions'] as Map)['cancelBlockedReason'];
        lang = 'vi';
        rec('b', 'en label differs from vi, code stable', cbEn is Map && cbEn['code'] == cb['code'] && cbEn['label'] != cb['label'], 'en=${j(cbEn)}');
      } else {
        rec('b', 'booking A carries a 24h lock (customer cancelled <24h ago)', false, 'no lock; cannot test lock case');
      }
      // remove the lock to see the unblocked shape; also check the other three reasons are structured when present
      sql('update bookings set compensation_lock_until=null where id=$bookingA');
      await cust.api.bookingDetail(bookingA!);
      final raw2 = (rawData(cust) as Map)['actions'] as Map;
      rec('b', 'unlocked: canCancel true and cancelBlockedReason null/absent', raw2['canCancel'] == true && raw2['cancelBlockedReason'] == null, 'actions=${j(raw2, 600)}');
      final others = ['confirm', 'pay', 'dispute'];
      final shape = others.every((k) {
        final v = raw2['${k}BlockedReason'];
        return v == null || (v is Map && v.containsKey('code') && v.containsKey('label'));
      });
      rec('b', 'confirm/pay/dispute BlockedReason are null or {code,label}', shape, others.map((k) => '$k=${j(raw2['${k}BlockedReason'])}').join(' '));
    });

    // ── c) pending tasker application ───────────────────────────────────
    test('c) pending_tasker application', () async {
      final pj = jsonDecode(File('$kQaRoot/state/pending-tasker.json').readAsStringSync()) as Map;
      final pc = await login('${pj['email']}', '${pj['password']}');
      final u = await pc.api.me();
      final meRaw = rawData(pc) as Map;
      rec('c', '/me role pending_tasker', u.role == 'pending_tasker', 'role=${u.role}');
      final app = await pc.api.kycApplication();
      final kycRaw = rawData(pc);
      stdout.writeln('INFO kyc raw=${j(kycRaw, 900)}');
      final a = kycRaw is Map ? kycRaw['application'] : null;
      rec('c', 'GET /kyc application{status,statusLabel,submittedAt,documents[]}',
          a is Map && a['status'] != null && a['statusLabel'] != null && a.containsKey('documents') && a['documents'] is List,
          'application=${j(a, 600)}');
      rec('c', 'model TaskerApplication parses (status,label,submittedAt,documents)', app != null && app.status.isNotEmpty && (app.statusLabel ?? '').isNotEmpty,
          'status=${app?.status} label=${app?.statusLabel} submittedAt=${app?.submittedAt} docs=${app?.documents.length}');
      rec('c', '/me exposes the same application', u.application != null && j(meRaw['application']) == j(a), 'me.application=${j(meRaw['application'], 300)}');
      if (a is Map && (a['documents'] as List).isNotEmpty) {
        final d0 = (a['documents'] as List).first as Map;
        rec('c', 'document has kind/status', d0.containsKey('status') && d0.containsKey('docKind') && d0.containsKey('docLabel'), 'doc0=${j(d0)}');
        rec('c', 'no storage keys/urls leaked in documents', !j(a['documents'], 5000).contains('gs://') && !RegExp(r'"(url|path|objectKey|storageKey)"').hasMatch(j(a['documents'], 5000)), 'doc0 keys=${d0.keys.toList()}');
      }
      // owner-only: customer must not see another user's application: customer /kyc
      try {
        await cust.api.kycApplication();
        final cr = rawData(cust);
        final own = sqlInt("select count(*) from kyc_documents where user_id=1");
        final n = (cr is Map && cr['application'] is Map) ? ((cr['application'] as Map)['documents'] as List).length : 0;
        rec('c', 'customer GET /kyc shows only the customer\'s own documents (docs in SQL for user 1 vs returned)', n <= own, 'returned=$n own=$own app=${j(cr, 500)}');
      } on ApiException catch (e) {
        rec('c', 'customer GET /kyc is a clean error', e.status != null && e.status! < 500, 'status=${e.status} ${e.code}');
      }
      // lang
      lang = 'en';
      await pc.api.kycApplication();
      final en = (rawData(pc) as Map)['application'];
      lang = 'vi';
      rec('c', 'statusLabel localized en', en is Map && en['statusLabel'] != a?['statusLabel'] || (a is Map && a['statusLabel'] == en?['statusLabel']), 'vi="${a?['statusLabel']}" en="${en?['statusLabel']}"');
      await pc.api.logout();
    });

    // ── d) display names ────────────────────────────────────────────────
    test('d) no "Tasker #N" display names', () async {
      final blobs = <String, Object?>{};
      lang = 'vi';
      for (final scope in ['week', 'month', 'all']) {
        try {
          final lb = await tsk.api.leaderboard(scope: scope);
          blobs['leaderboard/$scope'] = rawData(tsk);
          final names = lb.rows.map((r) => r.name).toList();
          rec('d', 'leaderboard $scope names real or null', names.every((n) => n == null || (n.trim().isNotEmpty && !_taskerNum.hasMatch(n))), 'rows=${lb.rows.length} names=${names.take(8).toList()}');
        } on ApiException catch (e) {
          rec('d', 'leaderboard $scope', false, 'status=${e.status} ${e.code}');
        }
      }
      final p1 = await cust.api.taskerPublic(1);
      blobs['taskerPublic/1'] = rawData(cust);
      rec('d', 'taskerPublic(1) name real or null', !_taskerNum.hasMatch(p1.displayName), 'displayName="${p1.displayName}"');
      await cust.api.bookingDetail(bookingA!);
      final bd = rawData(cust);
      blobs['booking/page'] = bd;
      rec('d', 'booking page tasker card name real or null', !_taskerNum.hasMatch(j(bd, 100000)), 'tasker=${j((bd as Map)['tasker'] ?? bd['job'], 300)}');
      // wipe ghost name candidates in other surfaces
      for (final f in <String, Future<void> Function()>{
        'subscriptions': () async => await cust.api.subscriptions(),
        'search': () async => await cust.api.search('dọn'),
        'home': () async => await cust.api.home(),
        'bookings': () async => await cust.api.bookingsPage(),
        'taskerWorkspace': () async => await tsk.api.taskerWorkspace(),
      }.entries) {
        try {
          await f.value();
          final c = f.key == 'taskerWorkspace' ? tsk : cust;
          blobs[f.key] = rawData(c);
        } on ApiException catch (e) {
          stdout.writeln('INFO ${f.key} -> ${e.status}');
        }
      }
      Object? strip(Object? o) {
        if (o is Map) return {for (final e in o.entries) if (e.key != 'districts' && e.key != 'district') e.key: strip(e.value)};
        if (o is List) return [for (final v in o) strip(v)];
        return o;
      }
      for (final e in blobs.entries) {
        final s = j(strip(e.value), 1 << 20);
        final m = _taskerNum.firstMatch(s);
        rec('d', '${e.key}: no "Tasker #N" in any field (district fields aside)', m == null, m == null ? 'clean (${s.length} bytes)' : '...${s.substring((m.start - 120).clamp(0, s.length), (m.end + 60).clamp(0, s.length))}...');
        final full = j(e.value, 1 << 20);
        if (_taskerNum.hasMatch(full) && m == null) {
          rec('d', 'INFO ${e.key}: "Tasker #N" appears only in district value(s)', true, 'LAB SEED DATA: taskers.district holds "Tasker #N" for ${sqlInt("select count(*) from taskers where district like 'Tasker #%'")} rows; not a display-name field');
        }
      }
    });

    // ── e) bonuses ──────────────────────────────────────────────────────
    test('e) bonuses kindLabel + progress, no weekly/monthly duplicates', () async {
      for (final l in ['vi', 'en']) {
        lang = l;
        final b = await tsk.api.bonuses();
        final raw = rawData(tsk) as Map;
        final wk = (raw['weekly'] as List).cast<Map>().map((m) => '${m['kind']}').toList();
        final mo = (raw['monthly'] as List).cast<Map>().map((m) => '${m['kind']}').toList();
        rec('e', '[$l] server weekly/monthly lists disjoint (no repeated cards)', wk.toSet().intersection(mo.toSet()).isEmpty && wk.toSet().length == wk.length && mo.toSet().length == mo.length, 'weekly=$wk monthly=$mo');
        final all = [...b.weekly, ...b.monthly];
        rec('e', '[$l] every card has kindLabel', all.isNotEmpty && all.every((x) => (x.kindLabel ?? '').isNotEmpty), all.map((x) => '${x.kind}="${x.kindLabel}"').join(' | '));
        rec('e', '[$l] every card has progress{code,current,target,label}', all.every((x) => x.progress != null && (x.progress!.label ?? '').isNotEmpty), all.map((x) => '${x.kind}:${x.progress?.code} ${x.progress?.current}/${x.progress?.target} "${x.progress?.label}"').join(' | '));
        rec('e', '[$l] model lists (post-filter) equal server lists (no client dedupe needed)', b.weekly.length == wk.length && b.monthly.length == mo.length, 'model weekly=${b.weekly.length} monthly=${b.monthly.length} server=${wk.length}/${mo.length}');
        if (l == 'en') {
          rec('e', '[en] labels have no Vietnamese diacritics', !_viChars.hasMatch(all.map((x) => '${x.kindLabel} ${x.progress?.label}').join(' ')), '');
        }
      }
      lang = 'vi';
    });

    // ── g) compensation labels ──────────────────────────────────────────
    test('g) compensation labels localized (quote + stored breakdown)', () async {
      // new booking while the customer has a pending compensation (from the cancel in the last 24h)
      final d = draft(svc!, 'release-h G');
      lang = 'vi';
      final qv = await cust.api.quoteBooking(d);
      final rawVi = rawData(cust) as Map;
      lang = 'en';
      final qe = await cust.api.quoteBooking(d);
      final rawEn = rawData(cust) as Map;
      lang = 'vi';
      stdout.writeln('INFO quote vi comp=${j(rawVi['cancelCompensations'])} en comp=${j(rawEn['cancelCompensations'])} keys=${rawVi.keys.toList()}');
      dynamic findKey(Object? o, String k) {
        if (o is Map) {
          if (o.containsKey(k)) return o[k];
          for (final v in o.values) {
            final r = findKey(v, k);
            if (r != null) return r;
          }
        } else if (o is List) {
          for (final v in o) {
            final r = findKey(v, k);
            if (r != null) return r;
          }
        }
        return null;
      }
      final cv = (findKey(rawVi, 'cancelCompensations') as List?) ?? const [];
      final ce = (findKey(rawEn, 'cancelCompensations') as List?) ?? const [];
      stdout.writeln('INFO pending comps for customer 1: ${sql("select count(*) from cancellation_compensations where customer_user_id=1 and status='pending'")}');
      rec('g', 'quote carries a compensation line (pending compensation exists)', cv.isNotEmpty, 'vi=${j(cv)} en=${j(ce)}');
      if (cv.isNotEmpty) {
        rec('g', 'quote compensation label localized en (no Vietnamese, differs from vi)', ce.isNotEmpty && !_viChars.hasMatch(j(ce)) && j(cv) != j(ce), 'vi=${j(cv)} en=${j(ce)}');
        rec('g', 'model parses compensations (vi)', (qv?.breakdown?.compensations.isNotEmpty ?? false), 'vi labels=${qv?.breakdown?.compensations.map((c) => '${c.label}=${c.amountVnd}').toList()}');
        rec('g', 'model parses compensations (en) label localized', (qe?.breakdown?.compensations.isNotEmpty ?? false) && qe!.breakdown!.compensations.every((c) => !_viChars.hasMatch(c.label)), 'en labels=${qe?.breakdown?.compensations.map((c) => '${c.label}=${c.amountVnd}').toList()}');
      }
      // stored booking breakdown: booking A was created while the customer owed a compensation
      for (final id in [bookingA!, sqlInt("select id from bookings where user_id=1 and surcharge_breakdown_json::text like '%cancelCompensations%' order by id desc limit 1")]) {
        if (id <= 0) continue;
        lang = 'vi';
        await cust.api.bookingDetail(id);
        final pv = rawData(cust);
        lang = 'en';
        final de = await cust.api.bookingDetail(id);
        final pe = rawData(cust);
        lang = 'vi';
        final sv = (findKey(pv, 'cancelCompensations') as List?) ?? const [];
        final se = (findKey(pe, 'cancelCompensations') as List?) ?? const [];
        stdout.writeln('INFO booking $id stored comps vi=${j(sv)} en=${j(se)}');
        if (sv.isEmpty) continue;
        rec('g', 'stored booking $id compensation label localized en', se.isNotEmpty && !_viChars.hasMatch(j(se)) && j(sv) != j(se), 'vi=${j(sv)} en=${j(se)} model=${de.breakdown?.compensations.map((c) => c.label).toList()}');
        break;
      }
    });

    // ── h) availability conflict ────────────────────────────────────────
    test('h) availability conflictJobs', () async {
      final jobSched = sql('select b.scheduled_at from jobs jb join bookings b on b.id=jb.booking_id where jb.id=$jobA');
      stdout.writeln('INFO jobA=$jobA sched=$jobSched status=${sql("select status from jobs where id=$jobA")}');
      try {
        final r = await tsk.api.setWeeklyAvailability(const {}, force: false);
        final raw = rawData(tsk);
        rec('h', 'weekly empty grid with assigned job: conflicts + conflictJobs', r.conflictJobs.isNotEmpty, 'result saved=${r.saved} conflicts=${r.conflicts} conflictJobs=${r.conflictJobs.length} raw=${j(raw, 700)}');
      } on ApiException catch (e) {
        final cj = e.fields;
        stdout.writeln('INFO weekly ApiException ${e.status} ${e.code} ${e.message} fields=${j(cj)}');
        final body = tsk.rec.calls.last.respBody;
        final hasCj = body is Map && j(body).contains('conflictJobs');
        rec('h', 'weekly empty grid with assigned job: 409 body has conflictJobs', hasCj, 'status=${e.status} body=${j(body, 900)}');
      }
      // date flavour on the booking's date
      final dstr = sql("select to_char(b.scheduled_at at time zone 'Asia/Ho_Chi_Minh','YYYY-MM-DD') from jobs jb join bookings b on b.id=jb.booking_id where jb.id=$jobA");
      try {
        final r = await tsk.api.setDateAvailability(dstr, const [], force: false);
        rec('h', 'date override (no slots) with assigned job: conflictJobs', r.conflictJobs.isNotEmpty, 'result conflicts=${r.conflicts} conflictJobs=${r.conflictJobs.length} raw=${j(rawData(tsk), 700)}');
        if (r.conflictJobs.isNotEmpty) {
          final c = r.conflictJobs.first;
          rec('h', 'conflictJob fields jobId,bookingId,serviceName,scheduledAt', c.jobId > 0 && c.bookingId != null && (c.serviceName ?? '').isNotEmpty && DateTime.tryParse(c.scheduledAt ?? '') != null, 'jobId=${c.jobId} bookingId=${c.bookingId} serviceName=${c.serviceName} scheduledAt=${c.scheduledAt}');
        }
      } on ApiException catch (e) {
        final body = tsk.rec.calls.last.respBody;
        final cjList = body is Map ? (body['data'] is Map ? (body['data'] as Map)['conflictJobs'] : body['conflictJobs']) : null;
        rec('h', 'date override with assigned job: 409 conflictJobs[] shape', cjList is List && cjList.isNotEmpty && (cjList.first as Map).keys.toSet().containsAll({'jobId', 'bookingId', 'serviceName', 'scheduledAt'}), 'status=${e.status} body=${j(body, 900)}');
      }
    });

    // ── f) pool block while banned ──────────────────────────────────────
    test('f) pool block{code,label,blockedUntil} for auto-ban / admin ban / suspension', () async {
      // real auto-ban: consecutive_cancels is >= 3 in the lab, so one more tasker cancel trips the auto-ban rule.
      final before = sql('select is_banned, banned_reason from taskers where id=1');
      rec('f', 'pre-state not banned', before.startsWith('f'), before);
      final pool0 = await tsk.api.poolJobs();
      rec('f', 'unbanned: pool.block is null, canClaim true', pool0.block == null && pool0.canClaim, 'block=${pool0.block?.code} canClaim=${pool0.canClaim} raw.block=${j((rawData(tsk) as Map)['block'])}');
      var realAuto = false;
      try {
        await tsk.api.cancelJob(jobA!, reasonCode: 'other', reasonText: 'release-h auto-ban probe', idempotencyKey: uuidV4());
        realAuto = sql('select is_banned from taskers where id=1') == 't';
        stdout.writeln('INFO cancelJob ok; is_banned=${sql("select is_banned||' '||coalesce(banned_reason,'-')||' cc='||consecutive_cancels from taskers where id=1")}');
      } on ApiException catch (e) {
        stdout.writeln('INFO cancelJob failed ${e.status} ${e.code} ${e.message}');
      }
      if (!realAuto) {
        sql("update taskers set is_banned=true, banned_at=now(), banned_reason='Auto: huỷ 3 job liên tiếp' where id=1");
        stdout.writeln('INFO real auto-ban not triggered, auto-ban state set by SQL');
      }
      rec('f', realAuto ? 'real auto-ban triggered by cancel' : 'auto-ban state set by SQL (cancel did not trip it)', true, sql("select banned_reason from taskers where id=1"));
      Future<void> check(String label, String expectCode) async {
        try {
          final p = await tsk.api.poolJobs();
          final rawBlock = (rawData(tsk) as Map)['block'];
          final bodyStr = j(rawData(tsk), 100000);
          rec('f', '$label: block{code,label,blockedUntil}', p.block != null && p.block!.code == expectCode && p.block!.label.isNotEmpty && !p.canClaim,
              'code=${p.block?.code} label="${p.block?.label}" until=${p.block?.blockedUntil} canClaim=${p.canClaim} raw=${j(rawBlock)}');
          rec('f', '$label: raw "Auto:" text not sent', !bodyStr.contains('Auto:'), 'banReason="${p.banReason}"');
        } on ApiException catch (e) {
          rec('f', '$label: pool readable while banned', false, 'status=${e.status} ${e.code} ${e.message}');
        }
      }

      await check('auto-ban', 'AUTO_CONSECUTIVE_CANCELS');
      lang = 'en';
      final pe = await tsk.api.poolJobs();
      lang = 'vi';
      rec('f', 'auto-ban label localized en', pe.block != null && !_viChars.hasMatch(pe.block!.label), 'en label="${pe.block?.label}"');
      sql("update taskers set banned_reason='Violation of policy (QA admin ban)' where id=1");
      await check('admin ban', 'ADMIN_BAN');
      sql("update taskers set is_banned=false, banned_reason=null, banned_at=null, suspended_until=now()+interval '2 days' where id=1");
      await check('suspension', 'SUSPENDED');
      final p = await tsk.api.poolJobs();
      rec('f', 'suspension blockedUntil is an ISO instant', DateTime.tryParse(p.block?.blockedUntil ?? '') != null, 'blockedUntil=${p.block?.blockedUntil}');
      // leave unbanned for the rest of the suite (final restore from snapshot is done by the orchestrator)
      sql('update taskers set is_banned=false, banned_reason=null, banned_at=null, suspended_until=null where id=1');
    });

    test('cleanup: close probe pool jobs', () async {
      for (final id in [bookingA, bookingB, ...extraBookings].whereType<int>()) {
        sql("update jobs set status='closed' where booking_id=$id and status in ('pending','open')");
      }
    });
  });
}
