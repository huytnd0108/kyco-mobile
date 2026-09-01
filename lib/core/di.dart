import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'api/kyco_api.dart';
import 'api/token_store.dart';
import '../features/auth/auth_controller.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<KycoApiClient>((ref) {
  return KycoApiClient(
    tokens: ref.watch(tokenStoreProvider),
    // Refresh failed / session revoked → force the app to sign out.
    onAuthLost: () => ref.read(authControllerProvider.notifier).markSignedOut(),
  );
});

final kycoApiProvider = Provider<KycoApi>(
  (ref) => KycoApi(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)),
);
