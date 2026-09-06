// Provider (/api/v1/provider) API surface — a same-library part of kyco_api.dart
// so the extension can reuse the private `_c` client + `_tokens` and the shared
// Paged/Envelope patterns. Every method here is Bearer (auth:true, the client
// default). Money is server-derived: no method sends a computed amount — the one
// user-supplied figure is [requestPayout]'s amount, validated server-side.
//
// The "new-route" methods (requestPayout, stepUp*, fines*, appealFine, referrals,
// cancellations, supportTickets, providerJobDetail, poolJobs, availability,
// walletExportCsv) target backend routes that land with Section A — they are
// defined now and start returning data once those routes deploy (503 until then,
// per the api_mobile_v1_enabled flag).

part of 'kyco_api.dart';

/// One CCCD / selfie capture for the multipart KYC upload.
class KycUploadFile {
  const KycUploadFile({required this.kind, required this.filename, required this.bytes});

  /// One of ALLOWED_DOC_KINDS (e.g. 'cccd_front', 'cccd_back', 'selfie') —
  /// confirm the exact strings from @kyco/core/onboarding/kyc-validate.
  final String kind;
  final String filename;
  final List<int> bytes;
}

extension KycoApiProvider on KycoApi {
  // ── home / dashboard (existing) ────────────────────────────────────────────
  Future<ProviderWorkspace> providerWorkspace() async {
    final data = await _c.get('/provider/workspace');
    return ProviderWorkspace.fromJson(data as Map<String, dynamic>);
  }

  Future<ProviderDashboard> providerDashboard() async {
    final data = await _c.get('/provider/dashboard');
    return ProviderDashboard.fromJson(data as Map<String, dynamic>);
  }

  // ── jobs (existing) ────────────────────────────────────────────────────────
  Future<Paged<ProviderJob>> providerJobs({String? status, String? cursor, int limit = 20}) async {
    final env = await _c.getWithMeta('/provider/jobs', query: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final items = (env.data is List ? env.data as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(ProviderJob.fromJson)
        .toList(growable: false);
    return Paged.of(items, env.meta);
  }

  /// GET /provider/jobs/[id] — the lifecycle-hub read (A8).
  Future<ProviderJobDetail> providerJobDetail(int id) async {
    final data = await _c.get('/provider/jobs/$id');
    return ProviderJobDetail.fromJson(data as Map<String, dynamic>);
  }

  /// GET /provider/jobs/pool — pool + assigned pipeline + claim gate (A9).
  Future<PoolView> poolJobs() async {
    final data = await _c.get('/provider/jobs/pool');
    return PoolView.fromJson(data as Map<String, dynamic>);
  }

  // ── job lifecycle mutations (existing) — server-derived amounts ────────────
  Future<Map<String, dynamic>> claimJob(int id) => _postMap('/provider/jobs/$id/claim');
  Future<Map<String, dynamic>> confirmJob(int id) => _postMap('/provider/jobs/$id/confirm');

  Future<Map<String, dynamic>> declineJob(int id, {String? reason}) =>
      _postMap('/provider/jobs/$id/decline', body: {'reason': ?reason});

  Future<Map<String, dynamic>> cancelJob(int id, {String reasonCode = 'other', String? reasonText}) =>
      _postMap('/provider/jobs/$id/cancel', body: {
        'reasonCode': reasonCode,
        'reasonText': ?reasonText,
      });

  Future<StartTrackingResult> startTracking(int id) async {
    final data = await _c.post('/provider/jobs/$id/start-tracking');
    return StartTrackingResult.fromJson(data as Map<String, dynamic>);
  }

  /// POST check-in — NOTE the body key is `lon` (asymmetric with check-out's
  /// `lng`, mirroring the backend). Never send fabricated coordinates.
  Future<CheckInResult> checkIn(int id,
      {required double lat, required double lon, double? accuracyM, String? deviceFingerprint}) async {
    final data = await _c.post('/provider/jobs/$id/check-in', body: {
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
    final data = await _c.post('/provider/jobs/$id/check-out', body: {
      'lat': lat,
      'lng': lng,
      'accuracyM': ?accuracyM,
      'note': ?note,
    });
    return CheckOutResult.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> completeJob(int id) => _postMap('/provider/jobs/$id/complete');
  Future<Map<String, dynamic>> faceVerify(int id) => _postMap('/provider/jobs/$id/face-verify');

  Future<Map<String, dynamic>> uploadJobPhotos(int id,
          {required String slot, List<int>? mediaIds, List<String>? urls}) =>
      _postMap('/provider/jobs/$id/photos', body: {
        'slot': slot,
        'mediaIds': ?mediaIds,
        'urls': ?urls,
      });

  Future<Map<String, dynamic>> sendJobMessage(int id, String body) =>
      _postMap('/provider/jobs/$id/message', body: {'body': body});

  Future<Map<String, dynamic>> fileJobComplaint(int id,
          {String category = 'other', String? description}) =>
      _postMap('/provider/jobs/$id/complaint', body: {
        'category': category,
        'description': ?description,
      });

  Future<Map<String, dynamic>> resubmitCompletion(int bookingId) =>
      _postMap('/provider/bookings/$bookingId/resubmit-completion');

  /// POST cash-received (20% commission debit is server-side). 💰
  Future<Map<String, dynamic>> cashReceived(int bookingId) =>
      _postMap('/provider/bookings/$bookingId/cash-received');

  /// GET the provider's own live position feed for a job (used by W3's live
  /// panel). Returns the raw map — shape is bound by the consuming unit.
  Future<Map<String, dynamic>> jobLocation(int id) async {
    final data = await _c.get('/jobs/$id/location');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  // ── wallet (existing) ──────────────────────────────────────────────────────
  Future<WalletSummary> providerWallet() async {
    final data = await _c.get('/provider/wallet');
    return WalletSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<Paged<WalletTxn>> walletTxns({String? cursor, int limit = 20}) async {
    final env = await _c.getWithMeta('/provider/wallet/transactions', query: {
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
    final env = await _c.getWithMeta('/provider/payouts', query: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final items = (env.data is List ? env.data as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(Payout.fromJson)
        .toList(growable: false);
    return Paged.of(items, env.meta);
  }

  // ── growth (existing) ──────────────────────────────────────────────────────
  Future<ProviderBonuses> bonuses() async {
    final data = await _c.get('/provider/bonuses');
    return ProviderBonuses.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Goal>> goals() async {
    final data = await _c.get('/provider/goals');
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(Goal.fromJson)
        .toList(growable: false);
  }

  Future<void> setGoal(
      {String periodKind = 'week', String periodKey = '', int targetJobs = 0, int targetVnd = 0}) async {
    await _c.put('/provider/goals', body: {
      'periodKind': periodKind,
      'periodKey': periodKey,
      'targetJobs': targetJobs,
      'targetVnd': targetVnd,
    });
  }

  Future<LeaderboardView> leaderboard({String scope = 'week', String? district}) async {
    final data = await _c.get('/provider/leaderboard', query: {
      'scope': scope,
      if (district != null && district.isNotEmpty) 'district': district,
    });
    return LeaderboardView.fromJson(data as Map<String, dynamic>);
  }

  // ── availability (existing PUTs + A10 GET) ─────────────────────────────────
  /// GET /provider/availability (A10).
  Future<AvailabilityWeek> availability() async {
    final data = await _c.get('/provider/availability');
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
    final data = await _c.put('/provider/availability/weekly', body: body);
    return SaveAvailabilityResult.fromJson(data as Map<String, dynamic>);
  }

  Future<SaveAvailabilityResult> setDateAvailability(
      String date, List<AvailabilitySlot> slots, {bool force = false}) async {
    final data = await _c.put('/provider/availability/date', body: {
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

  /// GET /provider/support — the provider's own tickets (A7). The mobile app
  /// CREATES tickets via [createSupportTicket] (existing POST /support/tickets).
  Future<List<SupportTicket>> supportTickets() async {
    final data = await _c.get('/provider/support');
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['rows'] is List ? data['rows'] as List : const []);
    return list.whereType<Map<String, dynamic>>().map(SupportTicket.fromJson).toList(growable: false);
  }

  /// Multipart KYC upload (owner = Bearer subject; 8MB/file cap server-side).
  Future<Map<String, dynamic>> kycUpload(List<KycUploadFile> files) async {
    final form = FormData();
    for (final f in files) {
      form.files.add(MapEntry(
        f.kind,
        MultipartFile.fromBytes(f.bytes, filename: f.filename),
      ));
    }
    final data = await _c.post('/kyc/upload', body: form);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// POST /media/request-upload — presigned-upload ticket for a job photo.
  Future<Map<String, dynamic>> requestMediaUpload(
          {required String contentType, int? sizeBytes, String? purpose}) =>
      _postMap('/media/request-upload', body: {
        'contentType': contentType,
        'sizeBytes': ?sizeBytes,
        'purpose': ?purpose,
      });

  /// POST /media/finalize — commit an uploaded object.
  Future<Map<String, dynamic>> finalizeMedia({required String key, int? mediaId}) =>
      _postMap('/media/finalize', body: {
        'key': key,
        'mediaId': ?mediaId,
      });

  // ── new routes (Section A — defined now, live when A deploys) ──────────────
  /// POST /provider/payouts (A1) 💰 — the only user-supplied amount; validated +
  /// balance-checked server-side. Requires a fresh step-up grant (see [stepUp]).
  Future<PayoutRequestResult> requestPayout(int amountVnd) async {
    final data = await _c.post('/provider/payouts', body: {'amountVnd': amountVnd});
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

  /// GET /provider/fines (A3) 💰.
  Future<FinesView> fines() async {
    final data = await _c.get('/provider/fines');
    return FinesView.fromJson(data as Map<String, dynamic>);
  }

  /// GET /provider/fines/[id] (A4) — fine + existing appeal.
  Future<FineDetailView> fineDetail(int id) async {
    final data = await _c.get('/provider/fines/$id');
    return FineDetailView.fromJson(data as Map<String, dynamic>);
  }

  /// POST /provider/fines/[id]/appeal (A4) 💰 — body ≥20 chars; 409 if one exists.
  Future<Map<String, dynamic>> appealFine(int id, String body) =>
      _postMap('/provider/fines/$id/appeal', body: {'body': body});

  /// GET /provider/referrals (A5).
  Future<ReferralsView> referrals() async {
    final data = await _c.get('/provider/referrals');
    return ReferralsView.fromJson(data as Map<String, dynamic>);
  }

  /// GET /provider/cancellations (A6).
  Future<CancellationsView> cancellations() async {
    final data = await _c.get('/provider/cancellations');
    return CancellationsView.fromJson(data as Map<String, dynamic>);
  }

  /// GET /provider/wallet/export?year&month (A11) 💰 — raw text/csv bytes for the
  /// OS share sheet. Bearer-only credentialed ledger read.
  Future<List<int>> walletExportCsv({required int year, required int month}) =>
      _c.getBytes('/provider/wallet/export', query: {'year': year, 'month': month});

  // ── helpers ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _postMap(String path, {Object? body}) async {
    final data = await _c.post(path, body: body);
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }
}
