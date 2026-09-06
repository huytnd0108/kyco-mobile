import 'package:dio/dio.dart' show FormData, MultipartFile;

import '../models.dart';
import 'api_client.dart';
import 'token_store.dart';

// Provider (/api/v1/provider) methods live in a same-library part so the
// `extension KycoApiProvider on KycoApi` can reuse the private `_c` client and
// the shared Paged/Envelope patterns. See kyco_api_provider.dart.
part 'kyco_api_provider.dart';

/// Typed facade over the kyco /api/v1 endpoints the app uses.
class KycoApi {
  KycoApi(this._c, this._tokens);
  final KycoApiClient _c;
  final TokenStore _tokens;

  // ── auth ────────────────────────────────────────────────────────────────
  Future<AuthResult> login({required String email, required String password}) async {
    final data = await _c.post('/auth/login', body: {'email': email, 'password': password}, auth: false);
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

  Future<List<Booking>> bookings() async {
    final data = await _c.get('/bookings');
    // data may be a bare list OR a paginated envelope { items: [...], meta }.
    final list = data is List
        ? data
        : (data is Map<String, dynamic> && data['items'] is List ? data['items'] as List : const []);
    return list.whereType<Map<String, dynamic>>().map(Booking.fromJson).toList(growable: false);
  }

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

  Future<ProviderPublicProfile> providerPublic(int id) async {
    final data = await _c.get('/providers/$id/public', auth: false);
    return ProviderPublicProfile.fromJson(data as Map<String, dynamic>);
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
}
