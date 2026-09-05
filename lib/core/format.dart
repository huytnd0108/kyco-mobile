import 'dart:math';

import 'package:intl/intl.dart';

final NumberFormat _vndFormat = NumberFormat('#,###', 'vi_VN');

/// Formats a VND amount the way the web does: grouped thousands + a trailing
/// đồng sign, e.g. `480000` → `480.000₫`. Tolerant of negatives / zero.
String formatVnd(int vnd) => '${_vndFormat.format(vnd)}₫';

final Random _rng = Random.secure();

/// Mints an RFC-4122 v4 UUID without pulling in a new dependency (used as the
/// booking idempotency key). Cryptographically-random via [Random.secure].
String uuidV4() {
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 10xx
  String hex(int start, int end) {
    final sb = StringBuffer();
    for (var i = start; i < end; i++) {
      sb.write(b[i].toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
