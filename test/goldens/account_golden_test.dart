import 'package:flutter/material.dart';
import 'package:kyco_mobile/features/account/account_screen.dart';
import '_fakes.dart';
import '_harness.dart';

void main() {
  // T1 signed-in sweep, light
  for (final d in GoldenDevice.values) {
    goldenTest('account in ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const AccountScreen(), device: d);
      await expectGolden(t, goldenName('account', 'in', d, Brightness.light));
    });
  }
  // signed-out {320 canary, 393}
  for (final d in [GoldenDevice.slideOver, GoldenDevice.iphone16]) {
    goldenTest('account out ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const AccountScreen(), device: d, auth: Fakes.signedOut);
      await expectGolden(t, goldenName('account', 'out', d, Brightness.light));
    });
  }
  // dark 393
  goldenTest('account dark 393', (t) async {
    await pumpGoldenScreen(t, screen: const AccountScreen(), device: GoldenDevice.iphone16, brightness: Brightness.dark);
    await expectGolden(t, goldenName('account', 'in', GoldenDevice.iphone16, Brightness.dark));
  });
  // x1.3 chip-wrap canaries: 320 Slide Over + 375
  for (final d in [GoldenDevice.slideOver, GoldenDevice.se]) {
    goldenTest('account x1.3 ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const AccountScreen(), device: d, textScale: 1.3);
      await expectGolden(t, goldenName('account', 'in', d, Brightness.light, textScale: 1.3));
    });
  }
  // en 393
  goldenTest('account en 393', (t) async {
    await pumpGoldenScreen(t, screen: const AccountScreen(), device: GoldenDevice.iphone16, locale: const Locale('en'));
    await expectGolden(t, goldenName('account', 'in', GoldenDevice.iphone16, Brightness.light, locale: const Locale('en')));
  });
}
