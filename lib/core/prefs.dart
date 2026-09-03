import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the loaded instance so every controller reads it
/// synchronously. Never used for secrets — tokens stay in flutter_secure_storage.
final sharedPrefsProvider =
    Provider<SharedPreferences>((_) => throw UnimplementedError('override in main()'));
