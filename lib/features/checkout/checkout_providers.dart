import 'dart:convert';

import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di.dart';
import '../../core/models.dart';
import 'draft_store.dart';

// Guest checkout is composed ENTIRELY from public reads — never the Bearer-only
// `checkoutData()` — so an anonymous visitor can fill the whole form.

/// The service being booked (public read).
final checkoutServiceProvider =
    FutureProvider.autoDispose.family<ServiceDetail, int>((ref, id) {
  return ref.watch(kycoApiProvider).serviceDetail(id);
});

/// True once the guest tried to confirm with required fields missing: the
/// checkout fields then show their inline "required" errors.
final checkoutShowErrorsProvider =
    StateProvider.autoDispose.family<bool, int>((ref, serviceId) => false);

/// Keys of the required checkout fields, so a failed confirm can scroll the
/// first missing one into view.
class CheckoutFieldKeys {
  final date = GlobalKey();
  final time = GlobalKey();
  final ward = GlobalKey();
  final street = GlobalKey();
}

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

// ── server quote (POST /bookings/quote, read-only) ──────────────────────────

/// True when every required checkout field is filled (the quote needs a
/// complete create body).
bool isDraftQuotable(BookingDraft? d) =>
    d != null &&
    (d.scheduledDate ?? '').isNotEmpty &&
    (d.scheduledTime ?? '').isNotEmpty &&
    (d.wardName ?? '').isNotEmpty &&
    d.addressLine.trim().isNotEmpty;

/// Stable signature of the quote inputs (no idempotency key, no amounts).
String quoteSignature(BookingDraft d) => jsonEncode(d.toCreateBody()..remove('idempotencyKey'));

/// The SERVER total for the current draft, or null when none is available
/// (draft incomplete, older backend answering 404, any error): the checkout
/// then keeps the labelled base-price estimate. Debounced so typing does not
/// fire a request per keystroke. Never computed locally.
final checkoutQuoteProvider =
    FutureProvider.autoDispose.family<BookingQuote?, ({int serviceId, String sig})>((ref, args) async {
  var disposed = false;
  ref.onDispose(() => disposed = true);
  await Future<void>.delayed(const Duration(milliseconds: 500));
  final draft = ref.read(draftControllerProvider(args.serviceId));
  if (disposed || !isDraftQuotable(draft)) return null;
  try {
    return await ref.read(kycoApiProvider).quoteBooking(draft!);
  } catch (_) {
    return null; // 404 on an old backend, offline, ...: advisory only
  }
});
