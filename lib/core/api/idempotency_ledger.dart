import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../format.dart';
import 'problem.dart';

/// Client half of the backend's money idempotency contract (MQA-36/MQA-70: every
/// money POST carries an `Idempotency-Key` HEADER; the server runs it at most
/// once per (user, route, key), replays the stored 2xx on a retry, and FORGETS
/// the key when the call fails so a retry re-executes).
///
/// One key per user ACTION, identified by a [fingerprint] that encodes what is
/// asked for (e.g. `payout:100000`, `job-cancel:42:<reason tag>`):
///  - the same action retried (timeout, network loss, 5xx, 409 in-progress,
///    429, app restart) reuses the key, so a request whose response was lost
///    is replayed — never executed twice;
///  - a different action (other amount / target / reason) gets a fresh key, so
///    the server never sees one key with two bodies;
///  - after a DEFINITIVE outcome the key is dropped: a 2xx (done) or any other
///    4xx (the server stored nothing). The next confirmation is a new action.
///
/// Pending keys are persisted (Keychain/Keystore) so a retry after the app was
/// killed mid-request still replays. Keys only ever leave the device as the
/// header; they are never logged. Entries expire after [ttl].
abstract class PendingKeyStore {
  Future<String?> read();
  Future<void> write(String? json);
}

class SecurePendingKeyStore implements PendingKeyStore {
  SecurePendingKeyStore([FlutterSecureStorage? s])
      : _s = s ??
            const FlutterSecureStorage(
                iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock));
  final FlutterSecureStorage _s;
  static const _k = 'kyco.idempotency.pending';
  @override
  Future<String?> read() => _s.read(key: _k);
  @override
  Future<void> write(String? json) => json == null ? _s.delete(key: _k) : _s.write(key: _k, value: json);
}

class MemoryPendingKeyStore implements PendingKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? json) async => value = json;
}

class IdempotencyLedger {
  IdempotencyLedger({PendingKeyStore? store, this.ttl = const Duration(hours: 12), DateTime Function()? now})
      : _store = store ?? MemoryPendingKeyStore(),
        _now = now ?? DateTime.now;

  final PendingKeyStore _store;
  final Duration ttl;
  final DateTime Function() _now;
  final Map<String, ({String key, DateTime at})> _keys = {};
  Future<void>? _loaded;

  Future<void> _ensureLoaded() => _loaded ??= () async {
        try {
          final raw = await _store.read();
          if (raw == null) return;
          final m = jsonDecode(raw);
          if (m is! Map<String, dynamic>) return;
          m.forEach((fp, v) {
            final at = DateTime.tryParse('${(v as Map)['at']}');
            final key = v['key'];
            if (at != null && key is String && _now().difference(at) < ttl) {
              _keys[fp] = (key: key, at: at);
            }
          });
        } catch (_) {
          // Unreadable store → start empty (a new key at worst; the server's
          // business guards still block a second in-flight payout/cancel).
        }
      }();

  Future<void> _persist() async {
    try {
      await _store.write(_keys.isEmpty
          ? null
          : jsonEncode({
              for (final e in _keys.entries) e.key: {'key': e.value.key, 'at': e.value.at.toIso8601String()},
            }));
    } catch (_) {/* best effort */}
  }

  /// The key for [fingerprint]: the pending one if the same action is being
  /// retried, else a fresh RFC-4122 v4 from `Random.secure` ([uuidV4]).
  Future<String> keyFor(String fingerprint) async {
    await _ensureLoaded();
    final hit = _keys[fingerprint];
    if (hit != null && _now().difference(hit.at) < ttl) return hit.key;
    final key = uuidV4();
    _keys[fingerprint] = (key: key, at: _now());
    await _persist(); // persisted BEFORE the request leaves the device
    return key;
  }

  Future<void> forget(String fingerprint) async {
    await _ensureLoaded();
    if (_keys.remove(fingerprint) != null) await _persist();
  }

  /// Runs [call] with the action's key and applies the retention rules above.
  Future<T> run<T>(String fingerprint, Future<T> Function(String key) call) async {
    final key = await keyFor(fingerprint);
    try {
      final out = await call(key);
      await forget(fingerprint);
      return out;
    } on ApiException catch (e) {
      if (!keepAfter(e)) await forget(fingerprint);
      rethrow;
    } catch (_) {
      // Unknown client-side failure: the request may have left — keep the key.
      rethrow;
    }
  }

  /// True when the server may have executed (or still be executing) the call,
  /// so a retry must reuse the same key.
  static bool keepAfter(ApiException e) {
    if (e.isNetwork) return true;
    // A stale 'pending' key the server will never finish (crash mid-request)
    // is DEFINITIVE: drop it; the screen refreshes and the user re-checks.
    if (e.code == 'IDEMPOTENCY_STALE') return false;
    final s = e.status ?? 0;
    return s == 0 || s >= 500 || s == 408 || s == 409 || s == 429;
  }

  /// Stable, non-reversible tag for free text inside a fingerprint (FNV-1a,
  /// stable across app restarts — String.hashCode is not).
  static String textTag(String? s) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode((s ?? '').trim())) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }
}

/// App-wide ledger: a retry from a re-opened sheet/screen — or after an app
/// restart — reuses the pending key for the same action.
final idempotencyLedgerProvider =
    Provider<IdempotencyLedger>((_) => IdempotencyLedger(store: SecurePendingKeyStore()));
