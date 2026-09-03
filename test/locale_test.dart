import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kyco_mobile/core/locale_controller.dart';
import 'package:kyco_mobile/core/prefs.dart';

final _codeProvider = Provider<String>((ref) => resolvedLocaleCode(ref));

Future<ProviderContainer> _container(Map<String, Object> seed) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
}

void main() {
  test('persisted en → Locale(en) and code en', () async {
    final c = await _container({'kyco.locale': 'en'});
    expect(c.read(localeControllerProvider), const Locale('en'));
    expect(c.read(_codeProvider), 'en');
    c.dispose();
  });

  test('persisted vi → Locale(vi) and code vi', () async {
    final c = await _container({'kyco.locale': 'vi'});
    expect(c.read(localeControllerProvider), const Locale('vi'));
    expect(c.read(_codeProvider), 'vi');
    c.dispose();
  });

  test('unknown persisted language resolves to vi (fallback)', () async {
    final c = await _container({'kyco.locale': 'fr'});
    expect(c.read(_codeProvider), 'vi');
    c.dispose();
  });
}
