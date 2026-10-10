import 'package:dio/dio.dart' show FormData, MultipartFile;

import '../models.dart';
import 'api_client.dart';
import 'token_store.dart';

// Tasker (/api/v1/tasker) methods live in a same-library part so the
// `extension KycoApiTasker on KycoApi` can reuse the private `_c` client and
// the shared Paged/Envelope patterns. See kyco_api_tasker.dart.
part 'kyco_api_tasker.dart';

/// Typed facade over the kyco /api/v1 endpoints the app uses.
class KycoApi {
  KycoApi(this._c, this._tokens);
  final KycoApiClient _c;
  final TokenStore _tokens;

  // ── auth ────────────────────────────────────────────────────────────────
  Future<AuthResult> login({required String email, required String password, String? totpCode}) async {
    final data = await _c.post('/auth/login', auth: false, body: {
      'email': email,
      'password': password,
      if (totpCode != null && totpCode.isNotEmpty) 'totpCode': totpCode,
    });
    final result = AuthResult.fromJson(data as Map<String, dynamic>);
    await _tokens.save(access: result.accessToken, refresh: result.refreshToken);
    return result;
  }

  /// Request a phone OTP (`purpose: 'login'` for phone sign-in). The server
  /// returns `{expiresAt, channel}`; the code itself is never returned.
  Future<void> requestOtp({required String phone, String purpose = 'login'}) =>
      _c.post('/auth/otp/request', body: {'phone': phone, 'purpose': purpose}, auth: false);

  /// Phone + OTP sign-in (`POST /auth/login {phone, code}`). An account with
  /// TOTP enabled answers 401 `TOTP_REQUIRED` until [totpCode] is supplied.
  Future<AuthResult> loginWithOtp({required String phone, required String code, String? totpCode}) async {
    final data = await _c.post('/auth/login', auth: false, body: {
      'phone': phone,
      'code': code,
      if (totpCode != null && totpCode.isNotEmpty) 'totpCode': totpCode,
    });
    final result = AuthResult.fromJson(data as Map<String, dynamic>);
    await _tokens.save(access: result.accessToken, refresh: result.refreshToken);
    return result;
  }

  Future<AuthResult> signup({required String email, required String password, String? name, String? refCode}) async {
    final data = await _c.post('/auth/signup', auth: false, body: {
      'email': email,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
      if (refCode != null && refCode.isNotEmpty) 'refCode': refCode,
    });
    final result = AuthResult.fromJson(data as Map<String, dynamic>);
    await _tokens.save(access: result.accessToken, refresh: result.refreshToken);
    return result;
  }

  Future<void> logout() async {
    // Best-effort server revoke; always clear locally.
    final refresh = await _tokens.refreshToken;
    if (refresh != null) {
      try {
        await _c.post('/auth/logout', body: {'refreshToken': refresh}, auth: false);
      } catch (_) {/* ignore — clearing locally is what matters */}
    }
    await _tokens.clear();
  }

  // ── reads ───────────────────────────────────────────────────────────────
  /// Public composite (webBff) — no auth required.
  Future<HomeComposite> home() async {
    final data = await _c.get('/home', auth: false);
    return HomeComposite.fromJson(data as Map<String, dynamic>);
  }

  /// Current user (dualAuth Bearer read).
  Future<AuthUser> me() async {
    final data = await _c.get('/me');
    return AuthUser.fromJson(data as Map<String, dynamic>);
  }

  /// Verified phone-number change (dualAuth Bearer mutation).
  /// `code` is the OTP the caller first requested to the NEW number via
  /// `/auth/otp/request` with `purpose: 'phone_change'`. The server requires a
  /// fresh step-up grant: a missing one comes back as 403 `STEP_UP_REQUIRED`.
  /// Also surfaces 422 VALIDATION (`fields.phone` / `fields.code`) and 409
  /// CONFLICT (phone already in use) as [ApiException] — handled by the caller.
  Future<void> changePhone({required String phone, required String code}) =>
      _c.post('/me/phone', body: {'phone': phone, 'code': code});

  Future<List<Booking>> bookings() async => (await bookingsPage()).items;

  /// Keyset-paged bookings (`meta.nextCursor` / `meta.hasMore`, id DESC).
  Future<Paged<Booking>> bookingsPage({String? cursor, int limit = 20}) async {
    final env = await _c.getWithMeta('/bookings', query: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final data = env.data;
    // data may be a bare list OR a legacy `{ items: [...] }` wrapper.
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['items'] is List ? data['items'] as List : const []);
    final items = list.whereType<Map<String, dynamic>>().map(Booking.fromJson).toList(growable: false);
    return Paged.of(items, env.meta);
  }

  /// Booking detail via the `/bookings/{id}/page` BFF composite (owner-scoped;
  /// another user's id is a 404). Richer than `/bookings/{id}`: job timeline,
  /// assigned tasker, `hasReview`.
  Future<BookingDetail> bookingDetail(int id) async {
    final data = await _c.get('/bookings/$id/page');
    return BookingDetail.fromPage(data as Map<String, dynamic>);
  }

  /// Customer review of a completed booking (non-money). 409 CONFLICT when the
  /// booking is not settled / has no tasker / is already reviewed.
  Future<void> createReview({required int bookingId, required int rating, String? comment}) =>
      _c.post('/reviews', body: {
        'bookingId': bookingId,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      });

  // ── account: invites / addresses / content ───────────────────────────────
  Future<InviteStats> inviteStats() async {
    final data = await _c.get('/invites/stats');
    return InviteStats.fromJson(data is Map<String, dynamic> ? data : const {});
  }

  /// Idempotent: returns the existing invite code or allocates one.
  Future<String> inviteCode() async {
    final data = await _c.post('/invites/code');
    return (data is Map<String, dynamic> ? data['code'] as String? : null) ?? '';
  }

  Future<List<SavedAddress>> addresses() async {
    final data = await _c.get('/addresses');
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(SavedAddress.fromJson)
        .toList(growable: false);
  }

  Future<void> createAddress(SavedAddress a) => _c.post('/addresses', body: a.toWriteBody());

  /// Always the FULL object (MQA-2: the PATCH wipes omitted columns).
  Future<void> updateAddress(SavedAddress a) => _c.patch('/addresses/${a.id}', body: a.toWriteBody());

  Future<void> deleteAddress(int id) => _c.delete('/addresses/$id');

  /// Public curated FAQ (`{faq, taskerFaq}`); the customer list is returned.
  /// The server resolves the Accept-Language into `titleVi`/`bodyVi`.
  Future<List<ContentSection>> helpFaq() async {
    final data = await _c.get('/help', auth: false);
    final faq = data is Map<String, dynamic> ? data['faq'] : null;
    return (faq is List ? faq : const [])
        .whereType<Map<String, dynamic>>()
        .map(ContentSection.fromJson)
        .toList(growable: false);
  }

  /// Public curated legal/company doc (`about`, `contact`). 404 when unseeded.
  Future<ContentSection> legalDoc(String doc) async {
    final data = await _c.get('/legal/$doc', auth: false);
    return ContentSection.fromJson(data as Map<String, dynamic>);
  }

  /// Mark ONE notification read (`POST /notifications/{id}/read`).
  Future<void> markNotificationRead(int id) => _c.post('/notifications/$id/read');

  // ── catalog / services (all public/anon) ─────────────────────────────────
  /// Cursor-paged service list. `cursor` is an opaque base64url token — round
  /// it back verbatim, never construct one.
  Future<Paged<ServiceSummary>> services({String? category, String? cursor, int limit = 20}) async {
    final env = await _c.getWithMeta('/services', auth: false, query: {
      if (category != null && category.isNotEmpty) 'category': category,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      'limit': '$limit',
    });
    final items = (env.data is List ? env.data as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(ServiceSummary.fromJson)
        .toList(growable: false);
    return Paged.of(items, env.meta);
  }

  Future<ServiceDetail> serviceDetail(int id) async {
    final data = await _c.get('/services/$id', auth: false);
    return ServiceDetail.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ServiceSummary>> relatedServices(int id) async {
    final data = await _c.get('/services/$id/related', auth: false);
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(ServiceSummary.fromJson)
        .toList(growable: false);
  }

  Future<ReviewPage> serviceReviews(int id, {int? cursor, int limit = 20}) async {
    final data = await _c.get('/services/$id/reviews', auth: false, query: {
      'cursor': ?cursor,
      'limit': limit,
    });
    return ReviewPage.fromJson(data as Map<String, dynamic>);
  }

  Future<List<CatalogCategory>> catalogTree() async {
    final data = await _c.get('/catalog/tree', auth: false);
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(CatalogCategory.fromJson)
        .toList(growable: false);
  }

  /// Search. The web has no /search page — callers mirror that and route hits
  /// to /services. Returns the `hits` array.
  Future<List<SearchHit>> search(String q, {int limit = 20}) async {
    final data = await _c.get('/search', auth: false, query: {'q': q, 'limit': limit});
    final hits = data is Map<String, dynamic> ? data['hits'] : null;
    return (hits is List ? hits : const [])
        .whereType<Map<String, dynamic>>()
        .map(SearchHit.fromJson)
        .toList(growable: false);
  }

  // ── locations (public/anon) ──────────────────────────────────────────────
  Future<List<ActiveCity>> locationsTree() async {
    final data = await _c.get('/locations/tree', auth: false);
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(ActiveCity.fromJson)
        .toList(growable: false);
  }

  Future<List<Neighborhood>> neighborhoods(int wardCode) async {
    final data = await _c.get('/locations/neighborhoods', auth: false, query: {'wardCode': wardCode});
    final list = data is Map<String, dynamic> ? data['neighborhoods'] : null;
    return (list is List ? list : const [])
        .whereType<Map<String, dynamic>>()
        .map(Neighborhood.fromJson)
        .toList(growable: false);
  }

  Future<CityLanding> city(String slug) async {
    final data = await _c.get('/city/$slug', auth: false);
    return CityLanding.fromJson(data as Map<String, dynamic>);
  }

  Future<TaskerPublicProfile> taskerPublic(int id) async {
    final data = await _c.get('/taskers/$id/public', auth: false);
    return TaskerPublicProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<List<PlanCard>> plans() async {
    final data = await _c.get('/plans', auth: false);
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(PlanCard.fromJson)
        .toList(growable: false);
  }

  // ── authed (Bearer) ──────────────────────────────────────────────────────
  /// Signed-in checkout enhancement ONLY — guests must never call this (Bearer
  /// requireUser). Returns the raw map; the guest path composes from public reads.
  Future<Map<String, dynamic>> checkoutData(int serviceId) async {
    final data = await _c.get('/checkout/$serviceId');
    return data is Map<String, dynamic> ? data : <String, dynamic>{};
  }

  /// Optional authed slot suggestions. Guests use free date/time inputs (web
  /// parity). Tolerant of a bare string list or a list of `{time|slot}` maps.
  Future<List<String>> availability(int serviceId, String date) async {
    final data = await _c.get('/availability', query: {'serviceId': serviceId, 'date': date});
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['slots'] is List ? data['slots'] as List : const []);
    return list
        .map((e) {
          if (e is String) return e;
          if (e is Map) return (e['time'] ?? e['slot'] ?? e['label'] ?? '').toString();
          return '';
        })
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// Cash-only booking creation (the body carries NO amount key). Defined here
  /// for U4 — never invoked from a stub screen.
  Future<CreateBookingResult> createBooking(BookingDraft draft) async {
    final data = await _c.post('/bookings', body: draft.toCreateBody());
    return CreateBookingResult.fromJson(data as Map<String, dynamic>);
  }

  Future<List<SubscriptionItem>> subscriptions() async {
    final data = await _c.get('/subscriptions');
    return (data is List ? data : const [])
        .whereType<Map<String, dynamic>>()
        .map(SubscriptionItem.fromJson)
        .toList(growable: false);
  }

  /// The signed-in customer's notifications + the unread count from `meta.unread`.
  Future<(Paged<NotificationItem>, int)> notifications({String? cursor}) async {
    final env = await _c.getWithMeta('/notifications', query: {
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    });
    final items = (env.data is List ? env.data as List : const [])
        .whereType<Map<String, dynamic>>()
        .map(NotificationItem.fromJson)
        .toList(growable: false);
    final unread = (env.meta['unread'] as num?)?.toInt() ?? 0;
    return (Paged.of(items, env.meta), unread);
  }

  /// Mark all notifications read (POST /notifications).
  Future<void> markNotificationsRead() => _c.post('/notifications');

  /// Emergency SOS (POST /v1/sos — MQA-26). Customer or tasker; the server
  /// checks booking/job ownership, pages ops on every channel and dedups
  /// repeat presses. Every field is optional (location-only SOS is valid).
  Future<Map<String, dynamic>> triggerSos({
    int? bookingId,
    int? jobId,
    double? lat,
    double? lng,
    double? accuracyM,
    String category = 'safety',
    String? note,
  }) async {
    final data = await _c.post('/sos', body: {
      'bookingId': ?bookingId,
      'jobId': ?jobId,
      'lat': ?lat,
      'lng': ?lng,
      'accuracyM': ?accuracyM,
      'category': category,
      'note': ?note,
    });
    return (data as Map?)?.cast<String, dynamic>() ?? const {};
  }
}
