import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/locale_controller.dart';
import '../auth/auth_controller.dart';

/// Live identity for the signed-in My-account card — the real `me()` read
/// (dualAuth Bearer). Consumed as an AsyncValue so the card is loading/error
/// tolerant: on a miss it falls back to the cached auth user and NEVER blocks
/// the settings (theme / language) rendered below it. autoDispose so a
/// sign-out / tab-away drops the request.
final accountMeProvider = FutureProvider.autoDispose<AuthUser>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(kycoApiProvider).me();
});

/// Referral counts (`GET /v1/invites/stats`) — user-scoped.
final inviteStatsProvider = FutureProvider.autoDispose<InviteStats>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(kycoApiProvider).inviteStats();
});

/// The user's invite code (`POST /v1/invites/code`, idempotent allocate).
final inviteCodeProvider = FutureProvider.autoDispose<String>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(kycoApiProvider).inviteCode();
});

/// Saved addresses (`GET /v1/addresses`) — user-scoped.
final addressesProvider = FutureProvider.autoDispose<List<SavedAddress>>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(kycoApiProvider).addresses();
});


/// Public customer FAQ (`GET /v1/help`).
final helpFaqProvider = FutureProvider.autoDispose<List<ContentSection>>((ref) {
  ref.watch(localeControllerProvider); // refetch in the new language
  return ref.watch(kycoApiProvider).helpFaq();
});

/// Public curated legal/company doc (`GET /v1/legal/{doc}`: about | contact).
final legalDocProvider = FutureProvider.autoDispose.family<ContentSection, String>((ref, doc) {
  ref.watch(localeControllerProvider);
  return ref.watch(kycoApiProvider).legalDoc(doc);
});
