// Shared harness for the wave-C tests: a scripted HTTP backend behind the REAL
// KycoApiClient/KycoApi (so paths, bodies and envelopes are exercised), plus
// app wrappers.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/launch.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'goldens/_fakes.dart' show InMemoryTokenStore;

/// A scripted /api/v1: register `'METHOD /path'` handlers; every request is logged.
class Backend implements HttpClientAdapter {
  final routes = <String, ({int status, Object? body}) Function(RequestOptions o)>{};
  final log = <RequestOptions>[];

  /// Success envelope helper.
  static ({int status, Object? body}) ok(Object? data, {int status = 200}) =>
      (status: status, body: {'ok': true, 'data': data});

  /// Error envelope helper.
  static ({int status, Object? body}) err(int status, String code, [String message = 'msg']) =>
      (status: status, body: {'ok': false, 'code': code, 'message': message});

  void on(String key, ({int status, Object? body}) Function(RequestOptions o) h) => routes[key] = h;

  Iterable<RequestOptions> calls(String key) =>
      log.where((o) => '${o.method} ${o.path}' == key);

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    log.add(options);
    final h = routes['${options.method} ${options.path}'];
    final r = h == null ? err(404, 'NOT_FOUND') : h(options);
    return ResponseBody.fromString(jsonEncode(r.body), r.status,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

class TestAuth extends AuthController {
  TestAuth(this._initial);
  final AuthState _initial;
  int logouts = 0;
  @override
  AuthState build() => _initial;
  @override
  Future<void> bootstrap() async {}
  @override
  Future<void> logout() async {
    logouts++;
    state = const AuthState(status: AuthStatus.signedOut, explicitLogout: true);
  }
}

AuthState signedInAs(String role, {int id = 7}) =>
    AuthState(status: AuthStatus.signedIn, user: AuthUser(id: id, role: role, name: 'Ngọc Anh'));

class Harness {
  Harness(this.backend, this.tokens, this.overrides);
  final Backend backend;
  final InMemoryTokenStore tokens;
  final List<Override> overrides;
}

/// Builds overrides wiring a real KycoApi onto [backend].
Future<Harness> harness({
  Backend? backend,
  AuthState auth = const AuthState(status: AuthStatus.signedIn, user: AuthUser(id: 7, role: 'customer')),
  TestAuth? authController,
  UrlOpener? opener,
  TextSharer? sharer,
  List<Override> extra = const [],
}) async {
  final b = backend ?? Backend();
  final tokens = InMemoryTokenStore()..save(access: 'a', refresh: 'r');
  final dio = Dio(BaseOptions(baseUrl: '', validateStatus: (_) => true))..httpClientAdapter = b;
  final client = KycoApiClient(tokens: tokens, dio: dio);
  SharedPreferences.setMockInitialValues(const {});
  final prefs = await SharedPreferences.getInstance();
  return Harness(b, tokens, [
    sharedPrefsProvider.overrideWithValue(prefs),
    tokenStoreProvider.overrideWithValue(tokens),
    apiClientProvider.overrideWithValue(client),
    kycoApiProvider.overrideWithValue(KycoApi(client, tokens)),
    authControllerProvider.overrideWith(() => authController ?? TestAuth(auth)),
    if (opener != null) urlOpenerProvider.overrideWithValue(opener),
    if (sharer != null) textSharerProvider.overrideWithValue(sharer),
    ...extra,
  ]);
}

Widget appWith(Harness h, Widget home, {Locale locale = const Locale('vi')}) => ProviderScope(
      overrides: h.overrides,
      child: MaterialApp(
        theme: buildTheme(lightColorScheme),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

/// A router app where every path in [pages] renders its widget and every other
/// path renders a marker Text(route: plus the location).
Widget routerWith(Harness h, String initial, Map<String, Widget Function(GoRouterState)> pages,
    {void Function(GoRouter)? onRouter}) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      for (final e in pages.entries) GoRoute(path: e.key, builder: (_, s) => e.value(s)),
    ],
    errorBuilder: (_, s) => Scaffold(body: Text('route:${s.uri}')),
  );
  onRouter?.call(router);
  return ProviderScope(
    overrides: h.overrides,
    child: MaterialApp.router(
      theme: buildTheme(lightColorScheme),
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

final vi = lookupAppLocalizations(const Locale('vi'));

/// A tall logical surface so long ListViews build every child.
void useTallView(WidgetTester t, {double w = 800, double h = 2400}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}
