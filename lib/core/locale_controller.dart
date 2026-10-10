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

/// The device (system) locale, kept current by [KycoApp] on
/// `didChangeLocales` so "follow system" users also trigger a refetch.
final deviceLocaleProvider = StateProvider<Locale>((ref) => PlatformDispatcher.instance.locale);

/// The language code the backend should serve and the UI shows: the explicit
/// override if set, else the device locale ('en' only when English, otherwise
/// 'vi' — the same rule the MaterialApp resolution callback applies). This is
/// the SINGLE source for both the Accept-Language header and the UI locale, and
/// every locale-dependent provider depends on it (via [kycoApiProvider]) so a
/// language switch refetches instead of keeping the old-language payload.
final appLocaleCodeProvider = Provider<String>((ref) {
  final Locale l = ref.watch(localeControllerProvider) ?? ref.watch(deviceLocaleProvider);
  return l.languageCode == 'en' ? 'en' : 'vi';
});

/// Non-reactive read for the dio interceptor (always the current code).
String resolvedLocaleCode(Ref ref) => ref.read(appLocaleCodeProvider);
