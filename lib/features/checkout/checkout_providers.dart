import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';

// Guest checkout is composed ENTIRELY from public reads — never the Bearer-only
// `checkoutData()` — so an anonymous visitor can fill the whole form.

/// The service being booked (public read).
final checkoutServiceProvider =
    FutureProvider.autoDispose.family<ServiceDetail, int>((ref, id) {
  return ref.watch(kycoApiProvider).serviceDetail(id);
});

/// Ward options for the address dropdown, composed from the public locations
/// tree (mirrors the web's active-wards source). Flattened across every active
/// service-area city so the dropdown lists real, bookable wards.
final checkoutWardsProvider =
    FutureProvider.autoDispose<List<ActiveWard>>((ref) async {
  final cities = await ref.watch(kycoApiProvider).locationsTree();
  return [for (final c in cities) ...c.wards];
});

/// Neighborhoods (Khu phố / Tổ dân phố) for the selected ward — the cascade
/// second dropdown. Hidden by the UI when this resolves empty.
final neighborhoodsProvider =
    FutureProvider.autoDispose.family<List<Neighborhood>, int>((ref, wardCode) {
  return ref.watch(kycoApiProvider).neighborhoods(wardCode);
});

// ── /book-now funnel ────────────────────────────────────────────────────────

/// Category grid for step 1 (the megamenu tree).
final bookNowCategoriesProvider =
    FutureProvider.autoDispose<List<CatalogCategory>>((ref) {
  return ref.watch(kycoApiProvider).catalogTree();
});

/// Step-2 services for the active category (null → all). The inline `q` filter
/// is applied client-side in the screen (mirrors the web's contains-filter).
final bookNowServicesProvider =
    FutureProvider.autoDispose.family<List<ServiceSummary>, String?>((ref, category) async {
  final page = await ref
      .watch(kycoApiProvider)
      .services(category: category, limit: 50);
  return page.items;
});
