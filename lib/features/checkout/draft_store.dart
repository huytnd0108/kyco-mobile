import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models.dart';
import '../../core/prefs.dart';

/// Live editor for a guest checkout draft, keyed by service id. Backed by the
/// frozen [DraftStore] (core/prefs.dart): every mutation persists to prefs under
/// `draft:<serviceId>` — the app's mirror of the web's sessionStorage form —
/// so a guest who fills the form, signs in, and returns keeps every field.
///
/// State is `null` until a draft is either restored from prefs or seeded from
/// the loaded [ServiceDetail] (see [ensureSeeded]).
class DraftController extends FamilyNotifier<BookingDraft?, int> {
  DraftStore get _store => ref.read(draftStoreProvider);

  @override
  BookingDraft? build(int serviceId) => _store.read(serviceId);

  /// Whether a persisted draft existed on entry (used to surface "draft
  /// restored"). Read straight from prefs so it is meaningful before seeding.
  bool get hadPersistedDraft => _store.read(arg) != null;

  /// Seed a fresh draft from the loaded service when none is persisted yet.
  /// Idempotent — a restored draft is left untouched so returning users keep
  /// their data. Never overwrites an existing draft.
  void ensureSeeded(ServiceDetail service) {
    if (state != null) return;
    _apply(BookingDraft(
      serviceId: service.id,
      serviceName: service.name,
      basePriceVnd: service.basePriceVnd,
    ));
  }

  void _apply(BookingDraft next) {
    state = next;
    _store.save(next);
  }

  void setDate(String value) {
    final d = state;
    if (d != null) _apply(d.copyWith(scheduledDate: value));
  }

  void setTime(String value) {
    final d = state;
    if (d != null) _apply(d.copyWith(scheduledTime: value));
  }

  /// Selecting a ward resets the neighborhood — the old value belongs to the
  /// previous ward (mirrors the web's cascade reset).
  void setWard(int code, String name) {
    final d = state;
    if (d != null) {
      _apply(d.copyWith(wardCode: code, wardName: name, neighborhood: ''));
    }
  }

  void setNeighborhood(String value) {
    final d = state;
    if (d != null) _apply(d.copyWith(neighborhood: value));
  }

  void setAddressLine(String value) {
    final d = state;
    if (d != null) _apply(d.copyWith(addressLine: value));
  }

  /// Prefill the address block from a saved address in ONE persisted write.
  /// [wardCode]/[wardName] are null when the saved ward could not be matched to
  /// a bookable ward - the ward/neighborhood then stay as they were and the user
  /// picks the ward; the street is still applied.
  void applySavedAddress({required String line, int? wardCode, String? wardName, String? neighborhood}) {
    final d = state;
    if (d == null) return;
    _apply(d.copyWith(
      addressLine: line,
      wardCode: wardCode,
      wardName: wardName,
      neighborhood: wardCode == null ? null : (neighborhood ?? ''),
    ));
  }

  void setNotes(String value) {
    final d = state;
    if (d != null) _apply(d.copyWith(notes: value));
  }

  /// Clear the persisted draft after a successful booking.
  Future<void> clear() async {
    await _store.clear(arg);
    state = null;
  }
}

/// Per-service draft editor. `.family` keyed by serviceId so each in-flight
/// checkout has its own draft.
final draftControllerProvider =
    NotifierProvider.family<DraftController, BookingDraft?, int>(DraftController.new);

/// Remove EVERY persisted checkout draft (`draft:*` prefs keys) and reset the
/// live editors. Called on sign-out so a draft (address, notes) never leaks to
/// the next person using the device.
Future<void> clearAllCheckoutDrafts(SharedPreferences prefs) async {
  for (final k in prefs.getKeys().where((k) => k.startsWith('draft:')).toList()) {
    await prefs.remove(k);
  }
}

/// Widget-side helper: wipe persisted drafts and invalidate the editors.
void clearCheckoutDrafts(WidgetRef ref) {
  clearAllCheckoutDrafts(ref.read(sharedPrefsProvider));
  ref.invalidate(draftControllerProvider);
}
