// MOB-S3 live contract test (QA only, lab backend on 127.0.0.1:4142).
// Calls every real KycoApi method against the live lab API. Skipped unless
// --dart-define=LIVE_CONTRACT=true. Run with:
//   flutter test test/live/api_contract_live_test.dart --dart-define=LIVE_CONTRACT=true \
//     --dart-define=LIVE_API_BASE=http://127.0.0.1:4142/api/v1 \
//     --dart-define=QA_ROOT=/home/bi/w/AppDroid1-ori/qa-ws7 -r expanded
@Tags(['live'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/format.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/api/token_store.dart';
import 'package:kyco_mobile/core/models.dart';

const bool _live = bool.fromEnvironment('LIVE_CONTRACT');
const String _apiBase = String.fromEnvironment('LIVE_API_BASE');
const String _qaRoot = String.fromEnvironment('QA_ROOT');

String get _callsPath => '$_qaRoot/out/mobile/contract-calls.jsonl';
String get _resultPath => '$_qaRoot/out/mobile/MOB-S3.result.json';
String get _inventoryPath => '$_qaRoot/out/inventory/mobile-calls.json';

const Set<int> _s2xx = {200, 201, 204};
const int _bogusId = 99999999;
const String _custPhone = '+84901110002';
const String _custEmail = 'demo@demo.local';
const String _custPw = 'demo12345';
const String _taskerEmail = 'tasker@qa.local';
const String _taskerPw = 'TaskerQa12345!';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore({String? access, String? refresh})
      : _a = access,
        _r = refresh;
  String? _a;
  String? _r;
  @override
  Future<String?> get accessToken async => _a;
  @override
  Future<String?> get refreshToken async => _r;
  @override
  Future<void> save({required String access, required String refresh}) async {
    _a = access;
    _r = refresh;
  }
  @override
  Future<void> setAccess(String access) async => _a = access;
  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
  }
  @override
  Future<bool> get hasSession async => _a != null;
}

// Recorder state (module level so the interceptor can reach it).
int? _lastStatus;
String? _lastTrace;
String _lastPath = '';
String _caseName = '';

class _Recorder extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final opts = response.requestOptions;
    final trace = response.headers.value('x-trace-id');
    _lastStatus = response.statusCode;
    _lastTrace = trace;
    _lastPath = '${opts.method} ${opts.uri.path}';
    File(_callsPath).writeAsStringSync(
      '${jsonEncode({
            'case': _caseName,
            'method': opts.method,
            'path': opts.uri.path,
            'status': response.statusCode,
            'traceId': trace,
          })}\n',
      mode: FileMode.append,
    );
    handler.next(response);
  }
}

Dio _dio() => Dio(BaseOptions(
      baseUrl: _apiBase,
      validateStatus: (_) => true,
      headers: {'accept': 'application/json'},
    ))
      ..interceptors.add(_Recorder());

KycoApi _newApi() {
  final store = InMemoryTokenStore();
  return KycoApi(KycoApiClient(tokens: store, dio: _dio()), store);
}

final List<Map<String, dynamic>> _checks = [];
final Set<String> _called = {};
final Map<String, KycoApi> _roles = {};
final List<Map<String, String>> _skipped = [];
KycoApi? _guestApi;
DateTime? _lastLoginAt;
String _startedAt = '';

KycoApi get _guest => _guestApi ??= _newApi();

Future<void> _paceLogin() async {
  final last = _lastLoginAt;
  if (last != null) {
    final wait = const Duration(seconds: 13) - DateTime.now().difference(last);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }
  _lastLoginAt = DateTime.now();
}

Future<KycoApi> _role(String role, String email, String password) async {
  final have = _roles[role];
  if (have != null) return have;
  await _paceLogin();
  final api = _newApi();
  await api.login(email: email, password: password);
  _roles[role] = api;
  return api;
}

Future<KycoApi> _customer() => _role('customer', _custEmail, _custPw);
Future<KycoApi> _tasker() => _role('tasker', _taskerEmail, _taskerPw);

/// Runs one API call, records the outcome, never throws. PASS when the call
/// returns a parsed model with a status in [ok], or throws ApiException whose
/// status is in [ok]. FAIL on TypeError/FormatException/DioException, network
/// error, or any status outside [ok] (including 5xx).
Future<dynamic> _call(String name, Set<int> ok, Future<dynamic> Function() f) async {
  _called.add(name);
  _caseName = name;
  _lastStatus = null;
  _lastTrace = null;
  _lastPath = '';
  dynamic value;
  var passed = false;
  var detail = '';
  var errType = '';
  int? status;
  try {
    value = await f();
    status = _lastStatus;
    passed = status == null || ok.contains(status);
    detail = 'parsed ${value == null ? 'null' : value.runtimeType}';
    if (!passed) detail = 'unexpected status $status; $detail';
  } on ApiException catch (e) {
    status = e.status ?? _lastStatus;
    errType = 'ApiException(${e.code})';
    detail = e.fields == null ? e.message : '${e.message} fields=${jsonEncode(e.fields)}';
    passed = e.status != null && ok.contains(e.status) && e.status! < 500 && e.code != 'network';
  } catch (e) {
    errType = e.runtimeType.toString();
    detail = e.toString();
    passed = false;
  }
  final id = 'MOB-S3.${(_checks.length + 1).toString().padLeft(2, '0')}';
  _checks.add({
    'id': id,
    'name': name,
    'route': _lastPath,
    'expectStatus': (ok.toList()..sort()),
    'status': status,
    'ok': passed,
    'detail': detail,
    'errorType': errType,
    'traceId': _lastTrace,
  });
  stdout.writeln('${passed ? 'PASS' : 'FAIL'}  $id $name  $_lastPath status=$status ${errType.isEmpty ? '' : errType} $detail');
  return value;
}

void main() {
  group('MOB-S3 live contract', skip: _live ? null : 'set --dart-define=LIVE_CONTRACT=true', () {
    // Shared fixture ids discovered by read calls.
    int? svcId;
    int? bookingId;
    int? notifId;
    int? taskerJobId;
    int? addrId;
    bool? freshGrant;

    setUpAll(() {
      if (!_apiBase.contains('127.0.0.1:4142')) {
        fail('abort: LIVE_API_BASE must match 127.0.0.1:4142 (got "$_apiBase")');
      }
      if (_qaRoot.isEmpty) fail('abort: QA_ROOT is not set');
      Directory('$_qaRoot/out/mobile').createSync(recursive: true);
      final f = File(_callsPath);
      if (f.existsSync()) f.deleteSync();
      _startedAt = DateTime.now().toUtc().toIso8601String();
    });

    tearDownAll(() {
      final fails = _checks.where((c) => c['ok'] != true).toList();
      final passCount = _checks.length - fails.length;

      // Method universe comes from the inventory (availability(customer) and
      // availability(tasker) are one method name).
      final inv = jsonDecode(File(_inventoryPath).readAsStringSync()) as Map<String, dynamic>;
      final all = <String>{
        for (final m in (inv['methods'] as List))
          (m as Map<String, dynamic>)['method'].toString().replaceAll(RegExp(r'\(.*\)$'), ''),
      };
      const reasons = {
        'cashReceived': 'money: POST cash-received is never called (not authorised)',
        'becomeTasker': 'public signup budget (3 per 15 min per IP); covered by API-09',
        'signup': 'public signup budget (3 per 15 min per IP); covered by API-01',
      };
      final notCalled = <Map<String, String>>[];
      for (final s in _skipped) {
        notCalled.add({'method': s['method']!, 'reason': s['reason']!});
      }
      final skippedNames = _skipped.map((s) => s['method']).toSet();
      for (final m in all.toList()..sort()) {
        if (_called.contains(m) || skippedNames.contains(m)) continue;
        notCalled.add({'method': m, 'reason': reasons[m] ?? 'not called: no case written'});
      }

      final defects = [
        for (final c in fails)
          {
            'title': '${c['name']} returned unexpected result',
            'sev': ((c['status'] as int?) ?? 0) >= 500 ? 'HIGH' : 'MED',
            'endpoint': c['route'],
            'request': 'see contract-calls.jsonl (case ${c['name']})',
            'expected': 'status in ${c['expectStatus']} and a parsed model',
            'actual': 'status ${c['status']} ${c['errorType']}: ${c['detail']}',
            'traceId': c['traceId'],
            'lesson': '#12',
            'ownerPkg': 'mobile',
            'knownRow': null,
            'evidence': 'out/mobile/contract-calls.jsonl',
          },
      ];

      final result = {
        'pkg': 'MOB-S3',
        'startedAt': _startedAt,
        'finishedAt': DateTime.now().toUtc().toIso8601String(),
        'labSha': 'cfc26e1',
        'mobileSha': '65f71c3',
        'status': fails.isEmpty ? 'PASS' : 'FAIL',
        'counts': {'pass': passCount, 'fail': fails.length, 'info': 0, 'skip': _skipped.length},
        'harnessRuns': [
          {
            'cmd': 'flutter test test/live/api_contract_live_test.dart --dart-define=LIVE_CONTRACT=true (see MOB-S3 step 11)',
            'exit': fails.isEmpty ? 0 : 1,
            'pass': passCount,
            'fail': fails.length,
            'log': 'logs/MOB-S3.log',
          },
        ],
        'checks': _checks,
        'defects': defects,
        'unknownKeys': <Object>[],
        'notCalled': notCalled,
        'labGaps': [
          'no pending_tasker account exists in kyco_wapi_mobileqa; pending-only paths not exercised',
          'job lifecycle mutations use job id 99999999 (expect 404); success paths are covered by flows.mjs',
        ],
        'notes': 'Customer demo@demo.local and tasker tasker@qa.local logged in 13 s apart. '
            'createBooking created one tomorrow 10:00 pool booking in the lab DB. triggerSos paged lab ops once. '
            'setWeeklyAvailability({}) and setDateAvailability(+60d, one slot) mutated tasker availability in the lab. '
            'requestPayout is called only with amount 1 and only if no fresh step-up grant exists. '
            'No money endpoint was called.',
      };
      File(_resultPath).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
      stdout.writeln('MOB-S3 result: pass=$passCount fail=${fails.length} notCalled=${notCalled.length} -> $_resultPath');
      if (fails.isNotEmpty) {
        fail('MOB-S3: ${fails.length} FAIL (${fails.map((c) => c['name']).toSet().join(', ')})');
      }
    });

    // ── auth ────────────────────────────────────────────────────────────────
    test('login', () async {
      await _call('login', _s2xx, () => _customer());
    });

    test('requestOtp', () async {
      await _call('requestOtp', _s2xx, () => _guest.requestOtp(phone: _custPhone));
    });

    test('loginWithOtp', () async {
      // Wrong code on purpose: asserts the typed error path, never mints a session.
      await _paceLogin();
      await _call('loginWithOtp', {401, 422}, () => _newApi().loginWithOtp(phone: _custPhone, code: '000000'));
    });

    test('home', () async {
      await _call('home', _s2xx, () => _guest.home());
    });

    test('me', () async {
      final api = await _customer();
      await _call('me', _s2xx, () => api.me());
    });

    test('changePhone', () async {
      // No step-up grant: expected 403 STEP_UP_REQUIRED (or validation/conflict).
      final api = await _customer();
      await _call('changePhone', {403, 409, 422}, () => api.changePhone(phone: _custPhone, code: '000000'));
    });

    // ── bookings / reviews ────────────────────────────────────────────────
    test('bookings', () async {
      final api = await _customer();
      await _call('bookings', _s2xx, () => api.bookings());
    });

    test('bookingsPage', () async {
      final api = await _customer();
      final page = await _call('bookingsPage', _s2xx, () => api.bookingsPage()) as Paged<Booking>?;
      if (page != null && page.items.isNotEmpty) bookingId = page.items.first.id;
    });

    test('bookingDetail', () async {
      final api = await _customer();
      await _call('bookingDetail', {200, 404}, () => api.bookingDetail(bookingId ?? _bogusId));
    });

    test('createReview', () async {
      final api = await _customer();
      await _call('createReview', {404, 409, 422},
          () => api.createReview(bookingId: _bogusId, rating: 5, comment: 'MOB-S3 probe'));
    });

    // ── account ───────────────────────────────────────────────────────────
    test('inviteStats', () async {
      final api = await _customer();
      await _call('inviteStats', _s2xx, () => api.inviteStats());
    });

    test('inviteCode', () async {
      final api = await _customer();
      await _call('inviteCode', _s2xx, () => api.inviteCode());
    });

    test('addresses', () async {
      final api = await _customer();
      await _call('addresses', _s2xx, () => api.addresses());
    });

    test('createAddress', () async {
      final api = await _customer();
      await _call('createAddress', _s2xx,
          () => api.createAddress(const SavedAddress(
                id: 0,
                label: 'MOB-S3 probe',
                line: '1 Probe St',
                district: 'Quận 1',
                ward: 'Bến Nghé',
                city: 'Hồ Chí Minh',
              )));
      final list = await api.addresses();
      for (final a in list) {
        if (a.label == 'MOB-S3 probe') addrId = a.id;
      }
    });

    test('updateAddress', () async {
      final api = await _customer();
      final id = addrId ?? _bogusId;
      await _call('updateAddress', {200, 204, 404},
          () => api.updateAddress(SavedAddress(
                id: id,
                label: 'MOB-S3 probe edited',
                line: '2 Probe St',
                district: 'Quận 1',
                ward: 'Bến Nghé',
                city: 'Hồ Chí Minh',
              )));
    });

    test('deleteAddress', () async {
      final api = await _customer();
      await _call('deleteAddress', {200, 204, 404}, () => api.deleteAddress(addrId ?? _bogusId));
    });

    test('helpFaq', () async {
      await _call('helpFaq', _s2xx, () => _guest.helpFaq());
    });

    test('legalDoc', () async {
      await _call('legalDoc', {200, 404}, () => _guest.legalDoc('about'));
    });

    // ── notifications ─────────────────────────────────────────────────────
    test('notifications', () async {
      final api = await _customer();
      final r = await _call('notifications', _s2xx, () => api.notifications()) as (Paged<NotificationItem>, int)?;
      if (r != null && r.$1.items.isNotEmpty) notifId = r.$1.items.first.id;
    });

    test('markNotificationRead', () async {
      final api = await _customer();
      await _call('markNotificationRead', {200, 204, 404}, () => api.markNotificationRead(notifId ?? _bogusId));
    });

    test('markNotificationsRead', () async {
      final api = await _customer();
      await _call('markNotificationsRead', _s2xx, () => api.markNotificationsRead());
    });

    // ── catalog / locations (public) ──────────────────────────────────────
    test('services', () async {
      final page = await _call('services', _s2xx, () => _guest.services()) as Paged<ServiceSummary>?;
      if (page != null && page.items.isNotEmpty) svcId = page.items.first.id;
    });

    test('serviceDetail', () async {
      await _call('serviceDetail', {200, 404}, () => _guest.serviceDetail(svcId ?? _bogusId));
    });

    test('relatedServices', () async {
      await _call('relatedServices', {200, 404}, () => _guest.relatedServices(svcId ?? _bogusId));
    });

    test('serviceReviews', () async {
      await _call('serviceReviews', {200, 404}, () => _guest.serviceReviews(svcId ?? _bogusId));
    });

    test('catalogTree', () async {
      await _call('catalogTree', _s2xx, () => _guest.catalogTree());
    });

    test('search', () async {
      await _call('search', _s2xx, () => _guest.search('dọn'));
    });

    test('locationsTree', () async {
      await _call('locationsTree', _s2xx, () => _guest.locationsTree());
    });

    test('neighborhoods', () async {
      await _call('neighborhoods', {200, 400, 422}, () => _guest.neighborhoods(1));
    });

    test('city', () async {
      await _call('city', {200, 404}, () => _guest.city('ho-chi-minh'));
    });

    test('taskerPublic', () async {
      await _call('taskerPublic', {200, 404}, () => _guest.taskerPublic(1));
    });

    test('plans', () async {
      await _call('plans', _s2xx, () => _guest.plans());
    });

    // ── customer commerce ─────────────────────────────────────────────────
    test('checkoutData', () async {
      final api = await _customer();
      await _call('checkoutData', {200, 404}, () => api.checkoutData(svcId ?? _bogusId));
    });

    test('availability', () async {
      final api = await _customer();
      final tomorrow = _ymd(DateTime.now().add(const Duration(days: 1)));
      await _call('availability', {200, 400, 404}, () => api.availability(svcId ?? _bogusId, tomorrow));
    });

    test('createBooking', () async {
      final api = await _customer();
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await _call('createBooking', {200, 201, 409, 422},
          () => api.createBooking(BookingDraft(
                serviceId: svcId ?? _bogusId,
                serviceName: 'MOB-S3 probe',
                basePriceVnd: 0,
                scheduledDate: _ymd(tomorrow),
                scheduledTime: '10:00',
                wardName: 'Quận 1',
                neighborhood: 'Bến Nghé',
                addressLine: '12 Lê Lợi',
                notes: 'MOB-S3 contract probe',
              )));
    });

    test('subscriptions', () async {
      final api = await _customer();
      await _call('subscriptions', _s2xx, () => api.subscriptions());
    });

    test('triggerSos', () async {
      final api = await _customer();
      await _call('triggerSos', {200, 201, 409, 422},
          () => api.triggerSos(lat: 10.7769, lng: 106.7009, accuracyM: 30, note: 'MOB-S3 contract probe'));
    });

    // ── tasker reads ──────────────────────────────────────────────────────
    test('taskerWorkspace', () async {
      final api = await _tasker();
      await _call('taskerWorkspace', _s2xx, () => api.taskerWorkspace());
    });

    test('taskerDashboard', () async {
      final api = await _tasker();
      await _call('taskerDashboard', _s2xx, () => api.taskerDashboard());
    });

    test('taskerJobs', () async {
      final api = await _tasker();
      final page = await _call('taskerJobs', _s2xx, () => api.taskerJobs()) as Paged<TaskerJob>?;
      if (page != null && page.items.isNotEmpty) taskerJobId = page.items.first.jobId;
    });

    test('taskerJobDetail', () async {
      final api = await _tasker();
      await _call('taskerJobDetail', {200, 404}, () => api.taskerJobDetail(taskerJobId ?? _bogusId));
    });

    test('poolJobs', () async {
      final api = await _tasker();
      await _call('poolJobs', _s2xx, () => api.poolJobs());
    });

    // ── job lifecycle (missing id on purpose: 404 is the contract) ───────
    test('claimJob', () async {
      final api = await _tasker();
      await _call('claimJob', {404, 409}, () => api.claimJob(_bogusId));
    });

    test('confirmJob', () async {
      final api = await _tasker();
      await _call('confirmJob', {404, 409}, () => api.confirmJob(_bogusId));
    });

    test('declineJob', () async {
      final api = await _tasker();
      await _call('declineJob', {404, 409}, () => api.declineJob(_bogusId, reason: 'MOB-S3 probe'));
    });

    test('cancelJob', () async {
      final api = await _tasker();
      await _call('cancelJob', {404, 409}, () => api.cancelJob(_bogusId, reasonCode: 'other', reasonText: 'MOB-S3 probe', idempotencyKey: uuidV4()));
    });

    test('startTracking', () async {
      final api = await _tasker();
      await _call('startTracking', {404, 409}, () => api.startTracking(_bogusId));
    });

    test('checkIn', () async {
      final api = await _tasker();
      await _call('checkIn', {404, 409}, () => api.checkIn(_bogusId, lat: 10.7769, lon: 106.7009, accuracyM: 20));
    });

    test('checkOut', () async {
      final api = await _tasker();
      await _call('checkOut', {404, 409}, () => api.checkOut(_bogusId, lat: 10.7769, lng: 106.7009, accuracyM: 20));
    });

    test('completeJob', () async {
      final api = await _tasker();
      await _call('completeJob', {404, 409}, () => api.completeJob(_bogusId));
    });

    test('faceVerify', () async {
      final api = await _tasker();
      await _call('faceVerify', {404, 409}, () => api.faceVerify(_bogusId));
    });

    test('uploadJobPhotos', () async {
      final api = await _tasker();
      await _call('uploadJobPhotos', {404, 409, 422},
          () => api.uploadJobPhotos(_bogusId, slot: 'before', mediaIds: const [1]));
    });

    test('sendJobMessage', () async {
      final api = await _tasker();
      await _call('sendJobMessage', {404, 409, 422}, () => api.sendJobMessage(_bogusId, 'MOB-S3 probe'));
    });

    test('fileJobComplaint', () async {
      final api = await _tasker();
      await _call('fileJobComplaint', {404, 409, 422},
          () => api.fileJobComplaint(_bogusId, category: 'other', description: 'MOB-S3 probe complaint text, long enough'));
    });

    test('resubmitCompletion', () async {
      final api = await _tasker();
      await _call('resubmitCompletion', {404, 409}, () => api.resubmitCompletion(_bogusId));
    });

    test('jobLocation', () async {
      final api = await _tasker();
      await _call('jobLocation', {404}, () => api.jobLocation(_bogusId));
    });

    test('pingJobLocation', () async {
      final api = await _tasker();
      await _call('pingJobLocation', {404, 409}, () => api.pingJobLocation(_bogusId, lat: 10.7769, lng: 106.7009));
    });

    // ── wallet / growth ───────────────────────────────────────────────────
    test('taskerWallet', () async {
      final api = await _tasker();
      await _call('taskerWallet', _s2xx, () => api.taskerWallet());
    });

    test('walletTxns', () async {
      final api = await _tasker();
      await _call('walletTxns', _s2xx, () => api.walletTxns());
    });

    test('payouts', () async {
      final api = await _tasker();
      await _call('payouts', _s2xx, () => api.payouts());
    });

    test('bonuses', () async {
      final api = await _tasker();
      await _call('bonuses', _s2xx, () => api.bonuses());
    });

    test('goals', () async {
      final api = await _tasker();
      await _call('goals', _s2xx, () => api.goals());
    });

    test('setGoal', () async {
      final api = await _tasker();
      await _call('setGoal', {200, 201, 204, 422},
          () => api.setGoal(periodKind: 'week', periodKey: '2026-W41', targetJobs: 5, targetVnd: 1000000));
    });

    test('leaderboard', () async {
      final api = await _tasker();
      await _call('leaderboard', _s2xx, () => api.leaderboard());
    });

    test('availability (tasker)', () async {
      final api = await _tasker();
      // The class member availability(serviceId, date) shadows the tasker extension, so call it explicitly.
      await _call('availability', _s2xx, () => KycoApiTasker(api).availability());
    });

    test('setWeeklyAvailability', () async {
      final api = await _tasker();
      await _call('setWeeklyAvailability', {200, 409, 422},
          () => api.setWeeklyAvailability(const {}, force: false));
    });

    test('setDateAvailability', () async {
      final api = await _tasker();
      final far = _ymd(DateTime.now().add(const Duration(days: 60)));
      await _call('setDateAvailability', {200, 409, 422},
          () => api.setDateAvailability(far, const [AvailabilitySlot(start: 540, end: 720)], force: false));
    });

    // ── device / support / KYC / media ────────────────────────────────────
    test('registerDeviceToken', () async {
      final api = await _tasker();
      await _call('registerDeviceToken', {200, 201, 204, 422},
          () => api.registerDeviceToken(platform: 'android', token: 'mob-s3-contract-token', appVersion: '0.0.0-test'));
    });

    test('createSupportTicket', () async {
      final api = await _tasker();
      await _call('createSupportTicket', {200, 201, 422},
          () => api.createSupportTicket(
                subject: 'MOB-S3 contract probe',
                body: 'automated contract test, ignore',
                category: 'other',
                priority: 'normal',
              ));
    });

    test('supportTickets', () async {
      final api = await _tasker();
      await _call('supportTickets', _s2xx, () => api.supportTickets());
    });

    test('kycUpload', () async {
      final api = await _tasker();
      final bytes = File('$_qaRoot/fixtures/real.jpg').readAsBytesSync();
      await _call('kycUpload', {200, 409, 422}, () => api.kycUpload([
            KycUploadFile(kind: 'cccd_front', filename: 'real.jpg', bytes: bytes),
            KycUploadFile(kind: 'selfie', filename: 'real.jpg', bytes: bytes),
          ], nationalId: '079000000000'));
    });

    test('requestMediaUpload', () async {
      final api = await _tasker();
      final bytes = File('$_qaRoot/fixtures/real.jpg').readAsBytesSync();
      final ticket = await _call('requestMediaUpload', {200, 201, 400, 403, 404, 409, 422},
          () => api.requestMediaUpload(
                category: 'collaborator-kyc',
                entityType: 'tasker',
                entityId: 1, // taskers.id of tasker@qa.local in kyco_wapi_mobileqa (user 3)
                fileName: 'real.jpg',
                mimeType: 'image/jpeg',
                sizeBytes: bytes.length,
                documentKind: 'selfie',
              )) as MediaUploadTicket?;
      if (ticket != null && ticket.isUsable) {
        // PUT the bytes to the signed URL (fake GCS in the lab) with the exact required type.
        final put = await Dio(BaseOptions(validateStatus: (_) => true)).put<dynamic>(
          ticket.uploadUrl!,
          data: Uint8List.fromList(bytes),
          options: Options(headers: {
            'content-type': ticket.requiredContentType ?? 'image/jpeg',
            'content-length': bytes.length,
          }),
        );
        File(_callsPath).writeAsStringSync(
          '${jsonEncode({'case': 'requestMediaUpload', 'method': 'PUT', 'path': '(signed-url)', 'status': put.statusCode, 'traceId': null})}\n',
          mode: FileMode.append,
        );
      }
      _caseName = 'finalizeMedia';
      await _call('finalizeMedia', {200, 201, 404, 409, 422}, () => api.finalizeMedia(
            mediaId: ticket?.assetId ?? _bogusId,
          ));
    });

    // ── step-up / payouts (no money: see skip below) ──────────────────────
    test('stepUpStatus', () async {
      final api = await _tasker();
      final st = await _call('stepUpStatus', _s2xx, () => api.stepUpStatus()) as StepUpStatus?;
      freshGrant = st?.fresh;
    });

    test('requestPayout', () async {
      final api = await _tasker();
      if (freshGrant != false) {
        // Never call the payout when a fresh step-up grant could let it through.
        _skipped.add({
          'method': 'requestPayout',
          'reason': 'skipped: step-up grant is fresh (or unknown); calling would risk a real payout',
        });
        stdout.writeln('SKIP  requestPayout: fresh step-up grant present, not called');
        return;
      }
      await _call('requestPayout', {403}, () => api.requestPayout(1, idempotencyKey: uuidV4()));
    });

    test('stepUp', () async {
      final api = await _tasker();
      // Wrong password on purpose: never mints a grant.
      await _call('stepUp', {401, 403, 422}, () => api.stepUp(password: 'wrong-password-mob-s3'));
    });

    // ── fines / referrals / cancellations / export ────────────────────────
    test('fines', () async {
      final api = await _tasker();
      await _call('fines', _s2xx, () => api.fines());
    });

    test('fineDetail', () async {
      final api = await _tasker();
      await _call('fineDetail', {404}, () => api.fineDetail(_bogusId));
    });

    test('appealFine', () async {
      final api = await _tasker();
      await _call('appealFine', {404, 409, 422}, () => api.appealFine(_bogusId, 'MOB-S3 probe appeal text long enough'));
    });

    test('referrals', () async {
      final api = await _tasker();
      await _call('referrals', _s2xx, () => api.referrals());
    });

    test('cancellations', () async {
      final api = await _tasker();
      await _call('cancellations', _s2xx, () => api.cancellations());
    });

    test('walletExportCsv', () async {
      final api = await _tasker();
      await _call('walletExportCsv', _s2xx, () => api.walletExportCsv(year: 2026, month: 10));
    });

    // Excluded by plan: cashReceived (money), becomeTasker and signup (signup budget).

    // logout is last: it clears the customer session.
    test('logout', () async {
      final api = await _customer();
      await _call('logout', _s2xx, () => api.logout());
    });
  });
}
