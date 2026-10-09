import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/ui/error_text.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/bookings/bookings_providers.dart';
import 'package:kyco_mobile/features/checkout/draft_store.dart';
import 'package:kyco_mobile/features/home/home_providers.dart';
import 'package:kyco_mobile/features/notifications/notifications_providers.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore;

class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);
  final ResponseBody Function(RequestOptions o) handler;
  final List<RequestOptions> requests = [];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add(o);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

(KycoApi, _Adapter, InMemoryTokenStore) _api(ResponseBody Function(RequestOptions o) h) {
  final adapter = _Adapter(h);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1', validateStatus: (_) => true))
    ..httpClientAdapter = adapter;
  final tokens = InMemoryTokenStore();
  return (KycoApi(KycoApiClient(tokens: tokens, dio: dio), tokens), adapter, tokens);
}

Map<String, dynamic> _body(RequestOptions o) =>
    o.data is String ? jsonDecode(o.data as String) as Map<String, dynamic> : o.data as Map<String, dynamic>;

class _MutableAuth extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.signedIn, user: AuthUser(id: 1, role: 'customer'));
  void set(AuthState s) => state = s;
  @override
  Future<void> bootstrap() async {}
}

void main() {
  final vi = lookupAppLocalizations(const Locale('vi'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('ApiException parsing (MQA-1)', () {
    test('non-envelope 429 {"error":...} → RATE_LIMIT', () {
      final e = ApiException.fromEnvelope({'error': 'Too many requests'}, 429);
      expect(e.code, 'RATE_LIMIT');
      expect(e.isRateLimited, isTrue);
    });
    test('429 with no body → RATE_LIMIT', () {
      expect(ApiException.fromEnvelope(null, 429).code, 'RATE_LIMIT');
    });
    test('envelope code wins', () {
      expect(ApiException.fromEnvelope({'code': 'VALIDATION', 'message': 'x'}, 422).code, 'VALIDATION');
    });
    test('client maps a middleware 429 to RATE_LIMIT', () async {
      final (api, _, _) = _api((o) => _json({'error': 'Too many requests'}, 429));
      await expectLater(api.home(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'RATE_LIMIT')));
    });
  });

  group('apiErrorText — never toString(), localized', () {
    test('network vi/en', () {
      final e = ApiException('network', 'DioException [connection error]: SocketException');
      expect(apiErrorText(vi, e), vi.cust2ErrNetwork);
      expect(apiErrorText(en, e), en.cust2ErrNetwork);
      expect(apiErrorText(vi, e), isNot(contains('Dio')));
    });
    test('codes map', () {
      expect(apiErrorText(vi, ApiException('RATE_LIMIT', 'x', status: 429)), vi.cust2ErrRateLimit);
      expect(apiErrorText(vi, ApiException('MAINTENANCE', 'x', status: 503)), vi.cust2ErrMaintenance);
      expect(apiErrorText(vi, ApiException('NOT_FOUND', 'x', status: 404)), vi.cust2ErrNotFound);
      expect(apiErrorText(vi, ApiException('VALIDATION', 'x', status: 422)), vi.cust2ErrValidation);
      expect(apiErrorText(vi, ApiException('http_500', 'Request failed', status: 500)), vi.cust2ErrServer);
      expect(apiErrorText(vi, ApiException('AUTH_REQUIRED', 'x', status: 401)), vi.cust2ErrSessionExpired);
      expect(apiErrorText(vi, ApiException('AUTH_REQUIRED', 'x', status: 401), authText: 'bad'), 'bad');
      expect(apiErrorText(vi, ApiException('TOTP_REQUIRED', 'x', status: 401)), vi.cust2ErrTotpRequired);
    });
    test('domain code → server (Accept-Language) message', () {
      expect(apiErrorText(vi, ApiException('CONFLICT', 'Đơn này đã được đánh giá.', status: 409)),
          'Đơn này đã được đánh giá.');
    });
    test('non-API error → generic', () {
      expect(apiErrorText(vi, StateError('boom')), vi.genericError);
    });
  });

  group('phone OTP login', () {
    test('requestOtp sends purpose login; loginWithOtp posts {phone, code, totpCode} and saves tokens', () async {
      final (api, adapter, tokens) = _api((o) {
        if (o.path.endsWith('/auth/otp/request')) {
          return _json({'ok': true, 'data': {'expiresAt': 'x', 'channel': 'stub'}}, 200);
        }
        return _json({
          'ok': true,
          'data': {
            'accessToken': 'a', 'refreshToken': 'r', 'expiresIn': 900,
            'user': {'id': 9, 'role': 'provider', 'name': 'P'},
          },
        }, 200);
      });
      await api.requestOtp(phone: '0901110002');
      expect(_body(adapter.requests.last), {'phone': '0901110002', 'purpose': 'login'});
      expect(adapter.requests.last.headers['authorization'], isNull);
      final res = await api.loginWithOtp(phone: '0901110002', code: '1234567', totpCode: '123456');
      expect(_body(adapter.requests.last), {'phone': '0901110002', 'code': '1234567', 'totpCode': '123456'});
      expect(res.user?.role, 'provider');
      expect(await tokens.accessToken, 'a');
    });
    test('TOTP_REQUIRED surfaces as a typed code', () async {
      final (api, _, _) = _api((o) => _json(
          {'ok': false, 'code': 'TOTP_REQUIRED', 'message': 'm', 'retryable': false}, 401));
      await expectLater(api.loginWithOtp(phone: '1', code: '2'),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'TOTP_REQUIRED')));
    });
  });

  group('bookings', () {
    test('bookingsPage forwards the opaque cursor and reads meta', () async {
      final (api, adapter, _) = _api((o) => _json({
            'ok': true,
            'data': [
              {'id': 5, 'status': 'CLOSED', 'serviceName': 'S'},
            ],
            'meta': {'nextCursor': 'abc', 'hasMore': true},
          }, 200));
      final p = await api.bookingsPage(cursor: 'zzz');
      expect(adapter.requests.last.queryParameters['cursor'], 'zzz');
      expect(p.nextCursor, 'abc');
      expect(p.hasMore, isTrue);
      expect(p.items.single.status, 'CLOSED');
    });

    test('BookingDetail.fromPage reads the composite + timeline; canReview gates', () {
      final d = BookingDetail.fromPage({
        'booking': {
          'id': 60, 'status': 'CLOSED', 'totalVnd': 37, 'paymentMethod': 'cash',
          'createdAt': '2026-08-11 18:36:16.52+00', 'scheduledAt': '2026-08-12 09:00:00+00',
          'addressLine': '1 A', 'completedAt': '2026-08-12 11:00:00+00', 'settledAt': null,
        },
        'service': {'id': 3, 'name': 'Tổng vệ sinh'},
        'job': {'providerId': 4, 'startedAt': '2026-08-12 09:05:00+00', 'earningsVnd': 999},
        'provider': {'id': 4, 'name': 'Chị Lan', 'bankAccountNumber': 'SECRET'},
        'hasReview': false,
      });
      expect(d.serviceName, 'Tổng vệ sinh');
      expect(d.providerName, 'Chị Lan');
      expect(d.totalVnd, 37);
      expect(d.timeline.map((e) => e.kind), ['created', 'scheduled', 'started', 'completed']);
      expect(d.canReview, isTrue);
      expect(BookingDetail.fromPage({'booking': {'id': 1, 'status': 'ACTIVE'}, 'provider': {'id': 2}}).canReview,
          isFalse);
      expect(BookingDetail.fromPage({'booking': {'id': 1, 'status': 'SETTLED'}, 'hasReview': true, 'provider': {'id': 2}})
          .canReview, isFalse);
    });

    test('all 15 FSM statuses have a localized label (vi + en)', () {
      expect(kBookingStatuses, hasLength(15));
      for (final s in kBookingStatuses) {
        expect(bookingStatusLabel(vi, s), isNot(s), reason: s);
        expect(bookingStatusLabel(en, s), isNot(s), reason: s);
      }
    });

    test('review body carries no amount', () async {
      final (api, adapter, _) = _api((o) => _json({'ok': true, 'data': {'id': 1}}, 201));
      await api.createReview(bookingId: 60, rating: 5, comment: ' ok ');
      expect(_body(adapter.requests.last), {'bookingId': 60, 'rating': 5, 'comment': 'ok'});
    });
  });

  group('addresses — full object on update (MQA-2)', () {
    test('PATCH sends every field', () async {
      final (api, adapter, _) = _api((o) => _json({'ok': true, 'data': {'id': 3, 'updated': true}}, 200));
      await api.updateAddress(const SavedAddress(id: 3, label: 'Nhà', line: '', district: 'Q1', ward: 'BN', city: 'HCM'));
      final o = adapter.requests.last;
      expect(o.method, 'PATCH');
      expect(o.path, endsWith('/addresses/3'));
      expect(_body(o).keys.toSet(), {'label', 'line', 'district', 'ward', 'city', 'isDefault'});
    });
  });

  group('redirects / links', () {
    test('resumeAfterLogin drops /p* for non-provider roles', () {
      expect(resumeAfterLogin('/p/wallet', 'customer'), '/');
      expect(resumeAfterLogin('/p', null), '/');
      expect(resumeAfterLogin('/p/wallet', 'provider'), '/p/wallet');
      expect(resumeAfterLogin('/p', 'admin'), '/p');
      expect(resumeAfterLogin('/providers/7', 'customer'), '/providers/7');
      expect(resumeAfterLogin(null, 'customer'), '/');
    });
    test('appRedirect on /login with a /p from', () {
      expect(appRedirect(status: AuthStatus.signedIn, role: 'customer', loc: '/login', from: '/p/jobs'), '/');
      expect(appRedirect(status: AuthStatus.signedIn, role: 'provider', loc: '/login', from: '/p/jobs'), '/p/jobs');
      expect(appRedirect(status: AuthStatus.signedIn, role: 'customer', loc: '/login', from: '/bookings'), '/bookings');
    });
    test('notification links → in-app routes', () {
      expect(inAppRouteForLink('/bookings/12?action=confirm'), '/bookings/12');
      expect(inAppRouteForLink('/bookings/12#review'), '/bookings/12');
      expect(inAppRouteForLink('/bookings/12/dispute/3'), '/bookings/12');
      expect(inAppRouteForLink('/vi/bookings/12'), '/bookings/12');
      expect(inAppRouteForLink('https://kyco.vn/en/services/5?suggested_date=x'), '/services/5');
      expect(inAppRouteForLink('/provider/jobs/available'), '/p/jobs');
      expect(inAppRouteForLink('/provider/jobs/44'), '/p/jobs/44');
      expect(inAppRouteForLink('/provider/wallet'), '/p/wallet');
      expect(inAppRouteForLink('/subscriptions/3'), '/subscriptions');
      expect(inAppRouteForLink('/admin/sos/1'), isNull);
      expect(inAppRouteForLink('/settings/security'), isNull);
      expect(inAppRouteForLink('https://evil.example/bookings/1'), isNull);
      expect(inAppRouteForLink(null), isNull);
    });
  });

  test('clearAllCheckoutDrafts removes only draft:* keys', () async {
    SharedPreferences.setMockInitialValues({'draft:1': '{}', 'draft:22': '{}', 'kyco.locale': 'vi'});
    final prefs = await SharedPreferences.getInstance();
    await clearAllCheckoutDrafts(prefs);
    expect(prefs.getKeys(), {'kyco.locale'});
  });

  test('bookingsProvider is user-scoped: account switch refetches, sign-out drops without a call', () async {
    var calls = 0;
    final (api, _, _) = _api((o) {
      calls++;
      return _json({'ok': true, 'data': [{'id': calls, 'status': 'PENDING'}], 'meta': {'hasMore': false}}, 200);
    });
    final c = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_MutableAuth.new),
      kycoApiProvider.overrideWithValue(api),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(bookingsProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(bookingsProvider.future)).single.id, 1);
    (c.read(authControllerProvider.notifier) as _MutableAuth)
        .set(const AuthState(status: AuthStatus.signedIn, user: AuthUser(id: 2, role: 'customer')));
    expect((await c.read(bookingsProvider.future)).single.id, 2);
    (c.read(authControllerProvider.notifier) as _MutableAuth)
        .set(const AuthState(status: AuthStatus.signedOut, explicitLogout: true));
    expect(await c.read(bookingsProvider.future), isEmpty);
    expect(calls, 2);
  });
}
