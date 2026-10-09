import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart';

/// Public marketing plan cards (`GET /v1/plans`, anon). Guest-browsable.
final plansProvider = FutureProvider.autoDispose<List<PlanCard>>((ref) {
  return ref.watch(kycoApiProvider).plans();
});

/// The signed-in customer's own subscriptions (`GET /v1/subscriptions`, Bearer).
/// Only watched once signed in — the screen guards on auth before reading it.
final mySubscriptionsProvider =
    FutureProvider.autoDispose<List<SubscriptionItem>>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(kycoApiProvider).subscriptions();
});
