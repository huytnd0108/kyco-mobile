import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';

/// Public home composite (no auth). Auto-disposes; refreshable via ref.invalidate.
final homeProvider = FutureProvider.autoDispose<HomeComposite>((ref) {
  return ref.watch(kycoApiProvider).home();
});

/// The signed-in customer's bookings (Bearer read).
final bookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) {
  return ref.watch(kycoApiProvider).bookings();
});
