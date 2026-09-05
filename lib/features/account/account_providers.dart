import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';

/// Live identity for the signed-in My-account card — the real `me()` read
/// (dualAuth Bearer). Consumed as an AsyncValue so the card is loading/error
/// tolerant: on a miss it falls back to the cached auth user and NEVER blocks
/// the settings (theme / language) rendered below it. autoDispose so a
/// sign-out / tab-away drops the request.
final accountMeProvider = FutureProvider.autoDispose<AuthUser>((ref) {
  return ref.watch(kycoApiProvider).me();
});
