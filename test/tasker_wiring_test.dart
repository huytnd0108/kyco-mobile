import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/api/token_store.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/tasker_job_detail/native_capture.dart';
import 'package:kyco_mobile/features/tasker_job_detail/tasker_job_detail_data.dart';
import 'package:kyco_mobile/features/tasker_jobs/tasker_jobs_providers.dart';
import 'package:kyco_mobile/features/tasker_wallet/step_up_sheet.dart';

class _Tokens implements TokenStore {
  @override
  Future<String?> get accessToken async => 'tok';
  @override
  Future<String?> get refreshToken async => 'ref';
  @override
  Future<void> save({required String access, required String refresh}) async {}
  @override
  Future<void> setAccess(String access) async {}
  @override
  Future<void> clear() async {}
  @override
  Future<bool> get hasSession async => true;
}

/// Records each request with its fully-drained body bytes.
class _Recorder implements HttpClientAdapter {
  _Recorder(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final List<(RequestOptions, List<int>)> calls = [];
  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final body = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    calls.add((options, body));
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok(Object data, {int status = 200}) => ResponseBody.fromString(
      jsonEncode({'ok': true, 'data': data}),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

KycoApi _api(_Recorder r) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1', validateStatus: (_) => true));
  dio.httpClientAdapter = r;
  return KycoApi(KycoApiClient(tokens: _Tokens(), dio: dio), _Tokens());
}

void main() {
  group('job photo upload contract (lib/media/access-write.ts)', () {
    test('request-upload body matches UploadIntentSchema; PUT + finalize follow', () async {
      final apiRec = _Recorder((o) {
        if (o.path.endsWith('/media/request-upload')) {
          return _ok({
            'assetId': 77,
            'uploadUrl': 'https://storage.googleapis.com/b/checkout/9/x.jpg?X-Goog-Signature=abc',
            'objectPath': 'checkout/9/x.jpg',
            'requiredContentType': 'image/jpeg',
            'expiresInSeconds': 3600,
          }, status: 201);
        }
        if (o.path.endsWith('/media/finalize')) return _ok({'mediaId': 77, 'sizeBytes': 4});
        return _ok({});
      });
      final putRec = _Recorder((o) => ResponseBody.fromString('', 200));
      final uploader = Dio()..httpClientAdapter = putRec;

      final res = await PhotoCaptureService(_api(apiRec), uploader: uploader).uploadBytes(
        bookingId: 9,
        slotWire: 'after',
        bytes: [1, 2, 3, 4],
        fileName: 'image_picker_1.jpg',
      );

      expect(res.isOk, isTrue);
      expect(res.mediaId, 77);

      final req = apiRec.calls[0];
      expect(req.$1.path, endsWith('/media/request-upload'));
      expect(jsonDecode(utf8.decode(req.$2)), {
        'category': 'checkout',
        'entityType': 'booking',
        'entityId': 9,
        'fileName': 'image_picker_1.jpg',
        'mimeType': 'image/jpeg',
        'sizeBytes': 4,
      });

      final put = putRec.calls.single;
      expect(put.$1.method, 'PUT');
      expect(put.$1.uri.host, 'storage.googleapis.com');
      expect(put.$1.headers[Headers.contentTypeHeader], 'image/jpeg');
      expect(put.$2, [1, 2, 3, 4]);
      expect(put.$1.headers.containsKey('authorization'), isFalse);

      final fin = apiRec.calls[1];
      expect(fin.$1.path, endsWith('/media/finalize'));
      expect(jsonDecode(utf8.decode(fin.$2)), {'mediaId': 77});
    });

    test('a failed PUT never finalizes', () async {
      final apiRec = _Recorder((o) => _ok({
            'assetId': 5,
            'uploadUrl': 'https://storage.googleapis.com/b/o',
            'requiredContentType': 'image/png',
          }, status: 201));
      final putRec = _Recorder((o) => ResponseBody.fromString('denied', 403));
      final res = await PhotoCaptureService(_api(apiRec), uploader: Dio()..httpClientAdapter = putRec)
          .uploadBytes(bookingId: 1, slotWire: 'before', bytes: [1], fileName: 'a.png');
      expect(res.isOk, isFalse);
      expect(apiRec.calls.length, 1);
      expect(jsonDecode(utf8.decode(apiRec.calls.single.$2))['category'], 'checkin');
    });

    test('slot → category mirrors job-photos-write.ts', () {
      expect(mediaCategoryForSlot('before'), 'checkin');
      expect(mediaCategoryForSlot('mid'), 'checkout');
      expect(mediaCategoryForSlot('after'), 'checkout');
    });

    test('relative upload URLs resolve against the API origin', () {
      expect(resolveUploadUrl('/api/media/local/x', apiBase: 'http://10.0.2.2:3088/api/v1').toString(),
          'http://10.0.2.2:3088/api/media/local/x');
      expect(resolveUploadUrl('https://storage.googleapis.com/b/o').host, 'storage.googleapis.com');
    });
  });

  group('KYC multipart', () {
    test('every part carries an allowlisted content type + national_id when given', () async {
      final rec = _Recorder((o) => _ok({
            'ok': true,
            'results': [
              {'ok': true, 'docKind': 'cccd_front'},
              {'ok': false, 'docKind': 'selfie', 'reason': 'mime'},
            ],
          }));
      final out = await _api(rec).kycUpload([
        const KycUploadFile(kind: 'cccd_front', filename: 'front', bytes: [1]),
        const KycUploadFile(kind: 'selfie', filename: 's.png', bytes: [2]),
      ], nationalId: ' 012345678901 ');
      final body = utf8.decode(rec.calls.single.$2, allowMalformed: true);
      expect(body, contains('name="national_id"'));
      expect(body, contains('012345678901'));
      expect(body, contains('filename="front.jpg"'));
      expect(body.toLowerCase(), contains('content-type: image/jpeg'));
      expect(body.toLowerCase(), contains('content-type: image/png'));
      expect(body.toLowerCase(), isNot(contains('text/plain')));
      expect(out.allOk(['cccd_front', 'selfie']), isFalse);
      expect(out.failed, {'selfie': 'mime'});
    });

    test('every allowlisted mime maps to a real part content type', () {
      for (final m in ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'application/pdf']) {
        final part = KycUploadFile(kind: 'selfie', filename: 'x', bytes: const [1], mimeType: m).toMultipart();
        expect(part.contentType.toString(), m);
      }
    });

    test('public become-tasker posts the web field names without a Bearer', () async {
      final rec = _Recorder((o) => _ok({'userId': 42}));
      final id = await _api(rec).becomeTasker(
        phone: '0912345678',
        otpCode: '1234567',
        name: 'A',
        city: 'hcm',
        district: 'Q1',
        referralCode: '',
        files: const [KycUploadFile(kind: 'cccd_front', filename: 'f.jpg', bytes: [1])],
      );
      expect(id, 42);
      final (opts, bytes) = rec.calls.single;
      expect(opts.path, endsWith('/become-tasker'));
      expect(opts.headers.containsKey('authorization'), isFalse);
      expect(opts.headers[Headers.contentLengthHeader], isNotNull);
      final body = utf8.decode(bytes, allowMalformed: true);
      for (final f in ['phone', 'otp_code', 'name', 'city', 'district', 'cccd_front']) {
        expect(body, contains('name="$f"'));
      }
      expect(body, isNot(contains('name="referral_code"')));
    });
  });

  test('claim error surfaces the server reason, generic for transport', () {
    expect(claimErrorMessage(ApiException('JOB_TIME_CONFLICT', 'Trùng lịch', status: 409), 'x'), 'Trùng lịch');
    expect(claimErrorMessage(ApiException('network', 'Network error'), 'x'), 'x');
    expect(claimErrorMessage(ApiException('MAINTENANCE', 'down', status: 503), 'x'), 'x');
    expect(claimErrorMessage(StateError('boom'), 'x'), 'x');
  });

  test('awaitingResubmit mirrors resubmit-write.ts gate', () {
    TaskerJobDetail d(Map<String, dynamic> b) =>
        TaskerJobDetail(job: const {'status': 'closed'}, booking: {'status': 'AWAITING_CUSTOMER_CONFIRMATION', ...b});
    expect(awaitingResubmit(d({})), isFalse);
    expect(awaitingResubmit(d({'customerDisputedAt': '2026-10-10T01:00:00Z'})), isTrue);
    expect(
        awaitingResubmit(d({
          'customerDisputedAt': '2026-10-10T01:00:00Z',
          'taskerResubmittedAt': '2026-10-10T02:00:00Z',
        })),
        isFalse);
  });

  test('maskPhone keeps only the last 3 digits', () {
    expect(maskPhone('0912345678'), '•••••••678');
    expect(maskPhone('12'), '12');
  });

  test('Z2 pool row: distanceKm parsed, pre-claim rows carry no address/notes', () {
    final j = PoolJob.fromJson({
      'jobId': 1, 'ward': 'Đa Kao', 'district': 'Quận 1', 'distanceKm': 2.4, 'totalVnd': 900000,
    });
    expect(j.distanceKm, 2.4);
    expect(PoolJob.fromJson({'jobId': 4, 'taskerNetVnd': 720000}).taskerNetVnd, 720000);
    expect(j.addressLine, isNull);
    expect(j.notes, isNull);
    expect(PoolJob.fromJson({'jobId': 2, 'distanceKm': 3}).distanceKm, 3.0);
    expect(PoolJob.fromJson({'jobId': 3}).distanceKm, isNull);
  });
}
