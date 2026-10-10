import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';

/// Public tasker profile (`GET /v1/taskers/:id/public`, anon). Unknown /
/// inactive / unverified taskers 404 identically — the screen maps that to a
/// friendly not-found. Keyed by tasker id.
final taskerPublicProvider =
    FutureProvider.autoDispose.family<TaskerPublicProfile, int>((ref, id) {
  return ref.watch(kycoApiProvider).taskerPublic(id);
});
