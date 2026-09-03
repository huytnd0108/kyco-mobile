import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

const _kLocale = 'kyco.locale';

/// User's language choice, persisted. null = follow the device locale.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    final c = ref.read(sharedPrefsProvider).getString(_kLocale);
    return (c == null || c.isEmpty) ? null : Locale(c);
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final p = ref.read(sharedPrefsProvider);
    if (locale == null) {
      await p.remove(_kLocale);
    } else {
      await p.setString(_kLocale, locale.languageCode);
    }
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

/// The language code the backend should serve (`content_translations`): the
/// explicit override if set, else the device locale — 'en' only when English,
/// otherwise 'vi'. Read outside the widget tree (dio interceptor).
String resolvedLocaleCode(Ref ref) {
  final l = ref.read(localeControllerProvider) ??
      PlatformDispatcher.instance.locale;
  return l.languageCode == 'en' ? 'en' : 'vi';
}
