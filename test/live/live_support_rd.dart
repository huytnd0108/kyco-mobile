// QA-only support for the live (lab) tests against the release-d backend.
// Never imported by app code. Lab only: every helper refuses a base URL that
// is not 127.0.0.1:4142.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/token_store.dart';

const bool kLive = bool.fromEnvironment('LIVE_CONTRACT');
const String kApiBase = String.fromEnvironment('LIVE_API_BASE');
const String kQaRoot = String.fromEnvironment('QA_ROOT');

const String kCustEmail = 'demo@demo.local';
const String kCustPw = 'demo12345';
const String kTaskerEmail = 'tasker@qa.local';
const String kTaskerPw = 'TaskerQa12345!';
const int kBogusId = 99999999;

const String _pgContainer = 'appdroid-pg';
const String _pgDb = 'kyco_wapi_mobileqa';

void guardLab() {
  if (!kApiBase.contains('127.0.0.1:4142')) {
    throw StateError('abort: LIVE_API_BASE must match 127.0.0.1:4142 (got "$kApiBase")');
  }
  if (kQaRoot.isEmpty) throw StateError('abort: QA_ROOT is not set');
}

/// Lab SQL via docker psql (same as flows.mjs). Returns trimmed stdout.
String sql(String q) {
  final r = Process.runSync('docker', [
    'exec', '-e', 'PGOPTIONS=-csearch_path=kycore,public', _pgContainer,
    'psql', '-U', 'postgres', '-d', _pgDb, '-v', 'ON_ERROR_STOP=1', '-tAc', q,
  ]);
  if (r.exitCode != 0) throw StateError('sql failed: ${r.stderr}\n$q');
  return (r.stdout as String).trim();
}

int sqlInt(String q) => int.tryParse(sql(q).split('\n').first.trim()) ?? 0;

class InMemoryTokenStore implements TokenStore {
  String? _a;
  String? _r;
  DateTime? _exp;
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
  Future<DateTime?> get accessExpiresAt async => _exp;
  @override
  Future<void> setAccessExpiresAt(DateTime? at) async => _exp = at;
  @override
  Future<void> clear() async {
    _a = null;
    _r = null;
  }

  @override
  Future<bool> get hasSession async => _a != null;
}

/// One recorded HTTP exchange.
class Call {
  Call(this.method, this.path, this.status, this.traceId, this.replayed, this.reqKeys, this.idemKey,
      this.respBody);
  final String method;
  final String path;
  final int? status;
  final String? traceId;
  final String? replayed;
  final List<String> reqKeys;
  final String? idemKey;
  final dynamic respBody;
}

/// Recorder + optional "lost response" injector. When [dropPaths] has a count
/// for a request path, the server still executes the request but the client
/// never sees the response (DioException.connectionError), exactly what a
/// network drop after send looks like to the ledger.
class Recorder extends Interceptor {
  Recorder({this.jsonlPath, this.caseName});
  final String? jsonlPath;
  String Function()? caseName;
  final List<Call> calls = [];
  final Map<String, int> dropPaths = {};
  void Function(Call)? onCall;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final b = options.data;
    options.extra['reqKeys'] = b is Map ? b.keys.map((e) => e.toString()).toList() : <String>[];
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final o = response.requestOptions;
    final c = Call(
      o.method,
      o.uri.path,
      response.statusCode,
      response.headers.value('x-trace-id'),
      response.headers.value('idempotent-replayed'),
      (o.extra['reqKeys'] as List?)?.cast<String>() ?? const [],
      o.headers['Idempotency-Key']?.toString(),
      response.data,
    );
    calls.add(c);
    onCall?.call(c);
    if (jsonlPath != null) {
      File(jsonlPath!).writeAsStringSync(
        '${jsonEncode({
              'case': caseName?.call(),
              'method': c.method,
              'path': c.path,
              'status': c.status,
              'traceId': c.traceId,
              'replayed': c.replayed,
            })}\n',
        mode: FileMode.append,
      );
    }
    final left = dropPaths[o.uri.path] ?? 0;
    if (left > 0) {
      dropPaths[o.uri.path] = left - 1;
      handler.reject(DioException.connectionError(requestOptions: o, reason: 'QA: response lost after send'));
      return;
    }
    handler.next(response);
  }
}

class LiveClient {
  LiveClient(this.api, this.rec, this.store);
  final KycoApi api;
  final Recorder rec;
  final InMemoryTokenStore store;
}

LiveClient newClient({String? jsonlPath, String Function()? caseName}) {
  guardLab();
  final store = InMemoryTokenStore();
  final rec = Recorder(jsonlPath: jsonlPath, caseName: caseName);
  final dio = Dio(BaseOptions(
    baseUrl: kApiBase,
    validateStatus: (_) => true,
    headers: {'accept': 'application/json'},
  ))
    ..interceptors.add(rec);
  return LiveClient(KycoApi(KycoApiClient(tokens: store, dio: dio), store), rec, store);
}

DateTime? _lastLogin;

/// Logins are limited to 5/min/IP: keep >= 13 s between them (per process).
Future<void> paceLogin() async {
  final last = _lastLogin;
  if (last != null) {
    final wait = const Duration(seconds: 13) - DateTime.now().difference(last);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
  }
  _lastLogin = DateTime.now();
}

Future<LiveClient> loginClient(String email, String pw, {String? jsonlPath, String Function()? caseName}) async {
  await paceLogin();
  final c = newClient(jsonlPath: jsonlPath, caseName: caseName);
  await c.api.login(email: email, password: pw);
  return c;
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final _rnd = Random();

/// A fresh tomorrow slot (10:00..19:00 hour + random minute) so repeated runs
/// never collide on tasker availability.
String randomTime() {
  final h = 10 + _rnd.nextInt(9);
  final m = _rnd.nextInt(60);
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String mask(String? k) => k == null ? 'null' : '${k.substring(0, min(8, k.length))}...';

/// Pretty JSON writer.
void writeJson(String path, Object o) {
  File(path).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(o));
}

/// Lab fixture: the customer cancel budget is 3 per VN day (CANCEL_RATE_LIMIT_EXCEEDED) and a booking made within 24h of a
/// customer cancel carries a 24h cancel lock. The lab customer already cancelled today in earlier runs, so shift those
/// cancellation rows back 2 days (ids appended to state/cancel-shifted-ids.txt; restored by the orchestrator at the very end).
void shiftCancelQuota() {
  final out = sql("update cancellations set created_at = created_at - interval '2 days' "
      "where cancelled_by_user_id=(select id from users where email='$kCustEmail') and cancelled_by_role='customer' "
      "and created_at > now() - interval '30 hours' returning id");
  final ids = out.split('\n').where((l) => RegExp(r'^\d+$').hasMatch(l.trim())).toList();
  if (ids.isNotEmpty) {
    File('$kQaRoot/state/cancel-shifted-ids.txt').writeAsStringSync('${ids.join('\n')}\n', mode: FileMode.append);
  }
}
