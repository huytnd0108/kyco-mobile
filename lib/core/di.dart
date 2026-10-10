import 'package:dio/dio.dart' show Dio;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/kyco_api.dart';
import 'api/token_store.dart';
import 'locale_controller.dart';
import '../features/auth/auth_controller.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

/// Test seam: a pre-built [Dio] (e.g. with a fake adapter). null = production Dio.
final apiDioProvider = Provider<Dio?>((ref) => null);

final apiClientProvider = Provider<KycoApiClient>((ref) {
  return KycoApiClient(
    dio: ref.watch(apiDioProvider),
    tokens: ref.watch(tokenStoreProvider),
    // Refresh failed / session revoked → force the app to sign out.
    onAuthLost: () => ref.read(authControllerProvider.notifier).markSignedOut(),
    // Backend returns content_translations in this language.
    acceptLanguage: () => resolvedLocaleCode(ref),
  );
});

final kycoApiProvider = Provider<KycoApi>((ref) {
  // Depend on the locale: every provider that `ref.watch`es the API (home,
  // catalogue, services, detail, notifications, FAQ ...) is rebuilt - and so
  // refetched in the new Accept-Language - when the language changes. The
  // (stateful) client itself is not rebuilt.
  ref.watch(appLocaleCodeProvider);
  return KycoApi(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider));
});
