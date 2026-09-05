import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/breakpoints.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// Active service-area cities (public `GET /v1/locations/tree`). Auto-disposes;
/// refresh via `ref.invalidate(locationsTreeProvider)`.
final locationsTreeProvider = FutureProvider.autoDispose<List<ActiveCity>>((ref) {
  return ref.watch(kycoApiProvider).locationsTree();
});

/// City landing composite (public `GET /v1/city/:slug`), keyed by slug. Throws
/// an [ApiException] with status 404 on an unknown/inactive slug — the screen
/// turns that into a friendly not-found.
final cityProvider =
    FutureProvider.autoDispose.family<CityLanding, String>((ref, slug) {
  return ref.watch(kycoApiProvider).city(slug);
});

/// Cross-axis column count for the responsive card grids (city list + city
/// service preview), a function of the WINDOW size class.
int locationsGridColumns(WindowSize size) => switch (size) {
      WindowSize.compact => 2,
      WindowSize.medium => 3,
      WindowSize.expanded => 4,
    };
