// Tasker (/api/v1/tasker) API surface — a same-library part of kyco_api.dart
// so the extension can reuse the private `_c` client + `_tokens` and the shared
// Paged/Envelope patterns. Every method here is Bearer (auth:true, the client
// default). Money is server-derived: no method sends a computed amount — the one
// user-supplied figure is [requestPayout]'s amount, validated server-side.
//
// The "new-route" methods (requestPayout, stepUp*, fines*, appealFine, referrals,
// cancellations, supportTickets, taskerJobDetail, poolJobs, availability,
// walletExportCsv) target backend routes that land with Section A — they are
// defined now and start returning data once those routes deploy (503 until then,
// per the api_mobile_v1_enabled flag).

part of 'kyco_api.dart';

/// One CCCD / selfie capture for the multipart KYC upload.
class KycUploadFile {
  const KycUploadFile({
    required this.kind,
    required this.filename,
    required this.bytes,
    this.mimeType,
  });

  /// One of ALLOWED_DOC_KINDS (`cccd_front`, `cccd_back`, `selfie`, `passport`,
  /// `driver_license` — @kyco/core/onboarding/kyc-validate).
  final String kind;
  final String filename;
  final List<int> bytes;

  /// Explicit part content type; when null it is inferred from [filename].
  final String? mimeType;

  /// The part's content type — always one of the KYC allowlist values the
  /// server accepts (jpeg/png/heic/heif/webp/pdf), never octet-stream.
  String get contentType => mimeType ?? mimeForFileName(filename);

  /// [filename] normalized so its extension agrees with [contentType] (the
  /// public signup derives the storage-key extension from the name).
  String get partFilename {
    final ext = extForMime(contentType);
    final dot = filename.lastIndexOf('.');
    final stem = dot > 0 ? filename.substring(0, dot) : (filename.isEmpty ? kind : filename);
    return '$stem.$ext';
  }

  // The part's content type is set explicitly (via Dio's own mime lookup on a
  // canonical extension, since this part file only sees FormData/MultipartFile)
  // — MultipartFile.fromBytes otherwise defaults an unknown name to text/plain,
  // which the server's KYC allowlist rejects per file.
  MultipartFile toMultipart() => MultipartFile.fromBytes(
        bytes,
        filename: partFilename,
        contentType: MultipartFile.lookupMediaType('file.${extForMime(contentType)}'),
      );
}

/// Best-effort mime for a captured file name. image_picker camera shots are
/// JPEG unless the name says otherwise.
String mimeForFileName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.heif')) return 'image/heif';
  if (n.endsWith('.pdf')) return 'application/pdf';
  return 'image/jpeg';
}

/// Canonical file extension for an allowlisted KYC/media mime type.
String extForMime(String mime) => switch (mime.toLowerCase()) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      'application/pdf' => 'pdf',
      _ => 'jpg',
    };

/// `/kyc/upload` result: `{ok, uploadedCount, attemptedCount, results:[{ok,
/// docKind, reason?}], verdict?}`. The envelope is ok even when a file failed.
class KycUploadOutcome {
  const KycUploadOutcome({
    this.ok = false,
    this.results = const [],
    this.verdict,
  });

  final bool ok;
  final List<Map<String, dynamic>> results;
  final String? verdict;

  /// Doc kinds the server stored.
  Set<String> get uploadedKinds => {
        for (final r in results)
          if (r['ok'] == true && r['docKind'] is String) r['docKind'] as String,
      };

  /// Doc kinds the server refused (validation / storage / db), with reasons.
  Map<String, String> get failed => {
        for (final r in results)
          if (r['ok'] != true && r['docKind'] is String)
            r['docKind'] as String: (r['reason'] ?? '').toString(),
      };

  /// True only when every one of [required] kinds landed.
  bool allOk(Iterable<String> required) => ok && required.every(uploadedKinds.contains);

  factory KycUploadOutcome.fromJson(Map<String, dynamic> j) => KycUploadOutcome(
        ok: j['ok'] == true,
        results: [
          for (final r in (j['results'] is List ? j['results'] as List : const []))
            if (r is Map<String, dynamic>) r,
        ],
        verdict: j['verdict'] as String?,
      );
}

/// The exact `/media/request-upload` JSON body (UploadIntentSchema). Pure so the
/// contract is unit-testable without a client.
Map<String, dynamic> mediaUploadIntentBody({
  required String category,
  required String entityType,
  required int entityId,
  required String fileName,
  required String mimeType,
  required int sizeBytes,
  String? documentKind,
}) =>
    {
      'category': category,
      'entityType': entityType,
      'entityId': entityId,
      'fileName': fileName,
      'mimeType': mimeType,
      'sizeBytes': sizeBytes,
      'documentKind': ?documentKind,
    };

/// `/media/request-upload` 201 data: `{assetId, uploadUrl, objectPath,
/// requiredContentType, expiresInSeconds}`. The PUT to [uploadUrl] MUST carry
/// exactly [requiredContentType] (it is part of the V4 signature).
class MediaUploadTicket {
  const MediaUploadTicket({
    this.assetId,
    this.uploadUrl,
    this.objectPath,
    this.requiredContentType,
    this.expiresInSeconds,
  });

  final int? assetId;
  final String? uploadUrl;
  final String? objectPath;
  final String? requiredContentType;
  final int? expiresInSeconds;

  bool get isUsable => assetId != null && (uploadUrl ?? '').isNotEmpty;

  factory MediaUploadTicket.fromJson(Map<String, dynamic> j) {
    final id = j['assetId'] ?? j['mediaId'];
    final ttl = j['expiresInSeconds'];
    return MediaUploadTicket(
      assetId: id is num ? id.toInt() : null,
      uploadUrl: j['uploadUrl'] as String?,
      objectPath: j['objectPath'] as String?,
      requiredContentType: j['requiredContentType'] as String?,
      expiresInSeconds: ttl is num ? ttl.toInt() : null,
    );
  }
}

extension KycoApiTasker on KycoApi {
  // ── home / dashboard (existing) ────────────────────────────────────────────
  Future<TaskerWorkspace> taskerWorkspace() async {
    final data = await _c.get('/tasker/workspace');
    return TaskerWorkspace.fromJson(data as Map<String, dynamic>);
  }

  Future<TaskerDashboard> taskerDashboard() async {
    final data = await _c.get('/tasker/dashboard');
    return TaskerDashboard.fromJson(data as Map<String, dynamic>);
  }

  // ── jobs (existing) ────────────────────────────────────────────────────────
  Future<Paged<TaskerJob>> taskerJobs({String? status, String? cursor, int limit = 20}) async {
    final env = await _c.getWithMeta('/tasker/jobs', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final items = (env.data is List ? env.data as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(TaskerJob.fromJson)
        .toList(growable: false);
    return Paged.of(items, env.meta);
  }

  /// GET /tasker/jobs/[id] — the lifecycle-hub read (A8).
  Future<TaskerJobDetail> taskerJobDetail(int id) async {
    final data = await _c.get('/tasker/jobs/$id');
    return TaskerJobDetail.fromJson(data as Map<String, dynamic>);
  }

  /// GET /tasker/jobs/pool — pool + assigned pipeline + claim gate (A9).
  Future<PoolView> poolJobs() async {
    final data = await _c.get('/tasker/jobs/pool');
    return PoolView.fromJson(data as Map<String, dynamic>);
  }

  // ── job lifecycle mutations (existing) — server-derived amounts ────────────
  Future<Map<String, dynamic>> claimJob(int id) => _postMap('/tasker/jobs/$id/claim');
  Future<Map<String, dynamic>> confirmJob(int id) => _postMap('/tasker/jobs/$id/confirm');

  Future<Map<String, dynamic>> declineJob(int id, {String? reason}) =>
      _postMap('/tasker/jobs/$id/decline', body: {'reason': ?reason});

  /// 💰 May levy a cancellation fine server-side → money POST: requires the
  /// action's [idempotencyKey] (IdempotencyLedger, MQA-36).
  Future<Map<String, dynamic>> cancelJob(int id,
          {String reasonCode = 'other', String? reasonText, required String idempotencyKey}) =>
      _postMap('/tasker/jobs/$id/cancel',
          body: {
            'reasonCode': reasonCode,
            'reasonText': ?reasonText,
          },
          idempotencyKey: idempotencyKey);

  Future<StartTrackingResult> startTracking(int id) async {
    final data = await _c.post('/tasker/jobs/$id/start-tracking');
    return StartTrackingResult.fromJson(data as Map<String, dynamic>);
  }

  /// POST check-in — NOTE the body key is `lon` (asymmetric with check-out's
  /// `lng`, mirroring the backend). Never send fabricated coordinates.
  Future<CheckInResult> checkIn(int id,
      {required double lat, required double lon, double? accuracyM, String? deviceFingerprint}) async {
    final data = await _c.post('/tasker/jobs/$id/check-in', body: {
      'lat': lat,
      'lon': lon,
      'accuracyM': ?accuracyM,
      'deviceFingerprint': ?deviceFingerprint,
    });
    return CheckInResult.fromJson(data as Map<String, dynamic>);
  }

  /// POST check-out — NOTE the body key is `lng` (see [checkIn]).
  Future<CheckOutResult> checkOut(int id,
      {required double lat, required double lng, double? accuracyM, String? note}) async {
    final data = await _c.post('/tasker/jobs/$id/check-out', body: {
      'lat': lat,
      'lng': lng,
      'accuracyM': ?accuracyM,
      'note': ?note,
    });
    return CheckOutResult.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> completeJob(int id) => _postMap('/tasker/jobs/$id/complete');
  Future<Map<String, dynamic>> faceVerify(int id) => _postMap('/tasker/jobs/$id/face-verify');

  /// Attach finalized assets (own media store only — `urls` is refused, MQA-43).
  Future<Map<String, dynamic>> uploadJobPhotos(int id,
          {required String slot, required List<int> mediaIds}) =>
      _postMap('/tasker/jobs/$id/photos', body: {
        'slot': slot,
        'mediaIds': mediaIds,
      });

  Future<Map<String, dynamic>> sendJobMessage(int id, String body) =>
      _postMap('/tasker/jobs/$id/message', body: {'body': body});

  Future<Map<String, dynamic>> fileJobComplaint(int id,
          {String category = 'other', String? description}) =>
      _postMap('/tasker/jobs/$id/complaint', body: {
        'category': category,
        'description': ?description,
      });

  Future<Map<String, dynamic>> resubmitCompletion(int bookingId) =>
      _postMap('/tasker/bookings/$bookingId/resubmit-completion');

  /// POST cash-received (20% commission debit is server-side). 💰
  /// 💰 Charges the commission server-side → requires [idempotencyKey] (MQA-36).
  Future<Map<String, dynamic>> cashReceived(int bookingId, {required String idempotencyKey}) =>
      _postMap('/tasker/bookings/$bookingId/cash-received', idempotencyKey: idempotencyKey);

  /// GET the tasker's own live position feed for a job (used by W3's live
  /// panel). Returns the raw map — shape is bound by the consuming unit.
  Future<Map<String, dynamic>> jobLocation(int id) async {
    final data = await _c.get('/jobs/$id/location');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// POST /jobs/{id}/location — one live-location ping from the ASSIGNED
  /// tasker while en route (Bearer accepted; dualAuth+csrf only gates the
  /// cookie path). Server requires job `active` + an open tracking session
  /// (409 TRACKING_SESSION_NOT_FOUND until start-tracking). GPS only — no money.
  Future<Map<String, dynamic>> pingJobLocation(int id,
          {required double lat, required double lng, double? accuracy, double? heading, double? speed}) =>
      _postMap('/jobs/$id/location', body: {
        'lat': lat,
        'lng': lng,
        'accuracy': ?accuracy,
        'heading': ?heading,
        'speed': ?speed,
      });

  // ── wallet (existing) ──────────────────────────────────────────────────────
  Future<WalletSummary> taskerWallet() async {
    final data = await _c.get('/tasker/wallet');
    return WalletSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<Paged<WalletTxn>> walletTxns({String? cursor, int limit = 20}) async {
    final env = await _c.getWithMeta('/tasker/wallet/transactions', query: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final items = (env.data is List ? env.data as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(WalletTxn.fromJson)
        .toList(growable: false);
    return Paged.of(items, env.meta);
  }

  Future<Paged<Payout>> payouts({String? cursor, int limit = 20}) async {
    final env = await _c.getWithMeta('/tasker/payouts', query: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final items = (env.data is List ? env.data as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(Payout.fromJson)
        .toList(growable: false);
    return Paged.of(items, env.meta);
  }

  /// GET /tasker/payout-requests (MQA-69) — own withdrawal requests, newest first.
  Future<Paged<PayoutRequest>> payoutRequests({String? cursor, int limit = 20}) async {
    final env = await _c.getWithMeta('/tasker/payout-requests', query: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final items = (env.data is List ? env.data as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(PayoutRequest.fromJson)
        .toList(growable: false);
    return Paged.of(items, env.meta);
  }

  /// GET /tasker/payout-requests/{id} — foreign or missing id → 404.
  Future<PayoutRequest> payoutRequest(int id) async {
    final data = await _c.get('/tasker/payout-requests/$id');
    return PayoutRequest.fromJson(data as Map<String, dynamic>);
  }

  // ── growth (existing) ──────────────────────────────────────────────────────
  Future<TaskerBonuses> bonuses() async {
    final data = await _c.get('/tasker/bonuses');
    return TaskerBonuses.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Goal>> goals() async {
    final data = await _c.get('/tasker/goals');
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(Goal.fromJson)
        .toList(growable: false);
  }

  Future<void> setGoal(
      {String periodKind = 'week', String periodKey = '', int targetJobs = 0, int targetVnd = 0}) async {
    await _c.put('/tasker/goals', body: {
      'periodKind': periodKind,
      'periodKey': periodKey,
      'targetJobs': targetJobs,
      'targetVnd': targetVnd,
    });
  }

  Future<LeaderboardView> leaderboard({String scope = 'week', String? district}) async {
    final data = await _c.get('/tasker/leaderboard', query: {
      'scope': scope,
      if (district != null && district.isNotEmpty) 'district': district,
    });
    return LeaderboardView.fromJson(data as Map<String, dynamic>);
  }

  // ── availability (existing PUTs + A10 GET) ─────────────────────────────────
  /// GET /tasker/availability (A10).
  Future<AvailabilityWeek> availability() async {
    final data = await _c.get('/tasker/availability');
    return AvailabilityWeek.fromJson(data as Map<String, dynamic>);
  }

  /// PUT weekly grid — `days` maps dow('0'..'6') → list of `{start,end}` minutes.
  Future<SaveAvailabilityResult> setWeeklyAvailability(
      Map<int, List<AvailabilitySlot>> days, {bool force = false}) async {
    final body = {
      'force': force,
      'days': {
        for (final e in days.entries)
          '${e.key}': [for (final s in e.value) s.toJson()],
      },
    };
    final data = await _c.put('/tasker/availability/weekly', body: body);
    return SaveAvailabilityResult.fromJson(data as Map<String, dynamic>);
  }

  Future<SaveAvailabilityResult> setDateAvailability(
      String date, List<AvailabilitySlot> slots, {bool force = false}) async {
    final data = await _c.put('/tasker/availability/date', body: {
      'date': date,
      'force': force,
      'slots': [for (final s in slots) s.toJson()],
    });
    return SaveAvailabilityResult.fromJson(data as Map<String, dynamic>);
  }

  // ── device tokens / support / KYC / media (existing) ───────────────────────
  Future<void> registerDeviceToken(
      {required String platform, required String token, String? appVersion}) async {
    await _c.post('/device-tokens', body: {
      'platform': platform,
      'token': token,
      'appVersion': ?appVersion,
    });
  }

  Future<Map<String, dynamic>> createSupportTicket(
          {required String subject, String? body, String? category, String? priority}) =>
      _postMap('/support/tickets', body: {
        'subject': subject,
        'body': ?body,
        'category': ?category,
        'priority': ?priority,
      });

  /// GET /tasker/support — the tasker's own tickets (A7). The mobile app
  /// CREATES tickets via [createSupportTicket] (existing POST /support/tickets).
  Future<List<SupportTicket>> supportTickets() async {
    final data = await _c.get('/tasker/support');
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['rows'] is List ? data['rows'] as List : const []);
    return list.whereType<Map<String, dynamic>>().map(SupportTicket.fromJson).toList(growable: false);
  }

  /// POST /kyc/upload — multipart KYC upload for a SIGNED-IN account (owner =
  /// Bearer subject; 8 MB/file cap server-side). One part per doc kind, each
  /// with an explicit contentType (the server validates `File.type` against the
  /// KYC mime allowlist — an octet-stream part is rejected per file). The route
  /// answers 200 even when individual files fail: check [KycUploadOutcome.allOk].
  Future<KycUploadOutcome> kycUpload(List<KycUploadFile> files, {String? nationalId}) async {
    final form = FormData();
    final id = nationalId?.trim();
    if (id != null && id.isNotEmpty) form.fields.add(MapEntry('national_id', id));
    for (final f in files) {
      form.files.add(MapEntry(f.kind, f.toMultipart()));
    }
    final data = await _c.post('/kyc/upload', body: form);
    return KycUploadOutcome.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  /// POST /become-tasker — PUBLIC (no Bearer) tasker self-signup: OTP verify
  /// (purpose `register`) → pending_tasker account → KYC docs, in one
  /// multipart call. Field names mirror the web form. Returns the new user id.
  Future<int?> becomeTasker({
    required String phone,
    required String otpCode,
    required String name,
    required String city,
    required String district,
    String? referralCode,
    required List<KycUploadFile> files,
  }) async {
    final ref = referralCode?.trim();
    final form = FormData.fromMap({
      'phone': phone,
      'otp_code': otpCode,
      'name': name,
      'city': city,
      'district': district,
      if (ref != null && ref.isNotEmpty) 'referral_code': ref,
    });
    for (final f in files) {
      form.files.add(MapEntry(f.kind, f.toMultipart()));
    }
    final data = await _c.post('/become-tasker', body: form, auth: false);
    final id = data is Map<String, dynamic> ? data['userId'] : null;
    return id is num ? id.toInt() : null;
  }

  /// POST /media/request-upload — signed-URL upload ticket (lib/media/
  /// access-write.ts::UploadIntentSchema). The server builds the object path and
  /// runs canUpload: for job photos `category` is `checkin` (slot before) or
  /// `checkout` (mid/after), `entityType` `booking`, `entityId` the BOOKING id.
  Future<MediaUploadTicket> requestMediaUpload({
    required String category,
    required String entityType,
    required int entityId,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    String? documentKind,
  }) async {
    final data = await _c.post('/media/request-upload', body: mediaUploadIntentBody(
      category: category,
      entityType: entityType,
      entityId: entityId,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      documentKind: documentKind,
    ));
    return MediaUploadTicket.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  /// POST /media/finalize — flip the pending asset to ready once the bytes are
  /// in storage (server HEADs the object). Body `{mediaId, contentSha256?}`.
  Future<Map<String, dynamic>> finalizeMedia({required int mediaId, String? contentSha256}) =>
      _postMap('/media/finalize', body: {
        'mediaId': mediaId,
        'contentSha256': ?contentSha256,
      });

  // ── new routes (Section A — defined now, live when A deploys) ──────────────
  /// POST /tasker/payouts (A1) 💰 — the only user-supplied amount; validated +
  /// balance-checked server-side. Requires a fresh step-up grant (see [stepUp]).
  /// The user-typed [amountVnd] is sent unchanged; [idempotencyKey] makes a
  /// retried request replay instead of creating a second payout (MQA-36).
  Future<PayoutRequestResult> requestPayout(int amountVnd, {required String idempotencyKey}) async {
    final data = await _c.post('/tasker/payouts',
        body: {'amountVnd': amountVnd}, idempotencyKey: idempotencyKey);
    return PayoutRequestResult.fromJson(data as Map<String, dynamic>);
  }

  /// GET /auth/step-up (A2) — is a fresh grant present + can the account use a
  /// password (else OTP)? Never cache "fresh" beyond a UX hint; the server gates.
  Future<StepUpStatus> stepUpStatus() async {
    final data = await _c.get('/auth/step-up');
    return StepUpStatus.fromJson(data as Map<String, dynamic>);
  }

  /// POST /auth/step-up (A2) — mint a step-up grant with password OR OTP code.
  Future<Map<String, dynamic>> stepUp({String? password, String? otpCode}) {
    assert(password != null || otpCode != null, 'step-up needs a password or an OTP code');
    return _postMap('/auth/step-up', body: password != null
        ? {'method': 'password', 'password': password}
        : {'method': 'otp', 'code': otpCode});
  }

  /// GET /tasker/fines (A3) 💰.
  Future<FinesView> fines() async {
    final data = await _c.get('/tasker/fines');
    return FinesView.fromJson(data as Map<String, dynamic>);
  }

  /// GET /tasker/fines/[id] (A4) — fine + existing appeal.
  Future<FineDetailView> fineDetail(int id) async {
    final data = await _c.get('/tasker/fines/$id');
    return FineDetailView.fromJson(data as Map<String, dynamic>);
  }

  /// POST /tasker/fines/[id]/appeal (A4) 💰 — body ≥20 chars; 409 if one exists.
  Future<Map<String, dynamic>> appealFine(int id, String body) =>
      _postMap('/tasker/fines/$id/appeal', body: {'body': body});

  /// GET /tasker/referrals (A5).
  Future<ReferralsView> referrals() async {
    final data = await _c.get('/tasker/referrals');
    return ReferralsView.fromJson(data as Map<String, dynamic>);
  }

  /// GET /tasker/cancellations (A6).
  Future<CancellationsView> cancellations() async {
    final data = await _c.get('/tasker/cancellations');
    return CancellationsView.fromJson(data as Map<String, dynamic>);
  }

  /// GET /tasker/wallet/export?year&month (A11) 💰 — raw text/csv bytes for the
  /// OS share sheet. Bearer-only credentialed ledger read.
  Future<List<int>> walletExportCsv({required int year, required int month}) =>
      _c.getBytes('/tasker/wallet/export', query: {'year': year, 'month': month});

  // ── helpers ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _postMap(String path, {Object? body, String? idempotencyKey}) async {
    final data = await _c.post(path, body: body, idempotencyKey: idempotencyKey);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }
}
