import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';

/// Public provider profile (`GET /v1/providers/:id/public`, anon). Unknown /
/// inactive / unverified providers 404 identically — the screen maps that to a
/// friendly not-found. Keyed by provider id.
final providerPublicProvider =
    FutureProvider.autoDispose.family<ProviderPublicProfile, int>((ref, id) {
  return ref.watch(kycoApiProvider).providerPublic(id);
});
