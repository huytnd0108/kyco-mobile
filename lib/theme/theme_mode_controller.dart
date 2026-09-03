import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs.dart';

const _kThemeMode = 'kyco.themeMode';

/// User's theme choice, persisted in shared_preferences. Default = follow OS.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final s = ref.read(sharedPrefsProvider).getString(_kThemeMode);
    return ThemeMode.values.asNameMap()[s ?? ''] ?? ThemeMode.system;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(sharedPrefsProvider).setString(_kThemeMode, mode.name);
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
