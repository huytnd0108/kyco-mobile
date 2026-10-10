import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/error_reporter.dart';
import 'core/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandling();
  // Run both in parallel but still await them BOTH before runApp: DateFormat
  // throws LocaleDataException if the vi_VN symbols are not loaded when the
  // first frame formats a date, so this cannot be deferred past runApp.
  final (prefs, _) = await (SharedPreferences.getInstance(), initializeDateFormatting()).wait;
  runApp(ProviderScope(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    child: const KycoApp(),
  ));
}
