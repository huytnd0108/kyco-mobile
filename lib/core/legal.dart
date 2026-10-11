import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di.dart';
import 'locale_controller.dart';
import 'models.dart';

/// `GET /v1/legal` cached PER LOCALE (the server returns locale-specific
/// document URLs). Resolves to null on a 404 (older backend, cached: it will not
/// change within a session). A transport failure surfaces as an error state and
/// is NOT cached beyond that; [resolveLegal] retries it.
final legalForLocaleProvider = FutureProvider.family<LegalInfo?, String>((ref, code) {
  return ref.read(kycoApiProvider).legal();
});

/// The legal info for the active app language.
final legalProvider = FutureProvider<LegalInfo?>((ref) {
  return ref.watch(legalForLocaleProvider(ref.watch(appLocaleCodeProvider)).future);
});

/// Resolve the server's consent support at submit time. Returns the
/// [LegalInfo] only when `/v1/legal` answered 200; null for a 404 OR when the
/// server is unreachable (after one retry), in which case the request must go
/// out WITHOUT a `consent` key — never to a server that did not advertise it.
Future<LegalInfo?> resolveLegal(WidgetRef ref) async {
  final code = ref.read(appLocaleCodeProvider);
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      return await ref.read(legalProvider.future);
    } catch (_) {
      ref.invalidate(legalForLocaleProvider(code));
    }
  }
  return null;
}
