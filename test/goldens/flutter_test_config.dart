import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Directory-scoped test config: applies ONLY to tests under test/goldens/, so
/// the unit tests in test/ are untouched. Loads real fonts (so text renders as
/// glyphs, not Ahem boxes) + vi date symbols. Golden PNGs are Linux-canonical
/// (see tool/update_goldens.sh); goldenTest() skips off-Linux.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadRoboto();
  await _loadFontManifest();
  await initializeDateFormatting();
  await testMain();
}

Future<void> _loadRoboto() async {
  final loader = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    final bytes = File('test/goldens/fonts/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// MaterialIcons (and any bundled font) from the test asset bundle, so icons
/// render as glyphs in goldens.
Future<void> _loadFontManifest() async {
  try {
    final manifest = await rootBundle.loadString('FontManifest.json');
    for (final entry in (json.decode(manifest) as List).cast<Map<String, dynamic>>()) {
      final family = (entry['family'] as String).replaceFirst(RegExp(r'packages/[^/]+/'), '');
      final loader = FontLoader(family);
      for (final font in (entry['fonts'] as List)) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  } catch (_) {
    // No FontManifest in the test bundle → icons fall back; layout still valid.
  }
}
