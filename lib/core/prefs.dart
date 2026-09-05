import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Overridden in main() with the loaded instance so every controller reads it
/// synchronously. Never used for secrets — tokens stay in flutter_secure_storage.
final sharedPrefsProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError('override in main()'));

/// Persistence for the guest checkout draft — the app's mirror of the web's
/// per-service sessionStorage form. Keyed `draft:<serviceId>` so a guest can
/// have an in-flight draft per service and get it back after sign-in.
class DraftStore {
  const DraftStore(this._prefs);
  final SharedPreferences _prefs;

  static String _key(int serviceId) => 'draft:$serviceId';

  BookingDraft? read(int serviceId) {
    final raw = _prefs.getString(_key(serviceId));
    if (raw == null || raw.isEmpty) return null;
    try {
      return BookingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(BookingDraft draft) =>
      _prefs.setString(_key(draft.serviceId), jsonEncode(draft.toJson()));

  Future<void> clear(int serviceId) => _prefs.remove(_key(serviceId));
}

final draftStoreProvider =
    Provider<DraftStore>((ref) => DraftStore(ref.watch(sharedPrefsProvider)));
