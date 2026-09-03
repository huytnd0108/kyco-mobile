import 'package:flutter/material.dart';
import 'package:kyco_mobile/features/home/home_screen.dart';
import '_fakes.dart';
import '_harness.dart';

void main() {
  // T1 full size sweep, light
  for (final d in GoldenDevice.values) {
    goldenTest('home data ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const HomeScreen(), device: d);
      await expectGolden(t, goldenName('home', 'data', d, Brightness.light));
    });
  }
  // empty {393, 820}
  for (final d in [GoldenDevice.iphone16, GoldenDevice.ipadAir]) {
    goldenTest('home empty ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const HomeScreen(), device: d, home: Fakes.homeEmpty());
      await expectGolden(t, goldenName('home', 'empty', d, Brightness.light));
    });
  }
  // dark {375, 1376}
  for (final d in [GoldenDevice.se, GoldenDevice.pro13]) {
    goldenTest('home dark ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const HomeScreen(), device: d, brightness: Brightness.dark);
      await expectGolden(t, goldenName('home', 'data', d, Brightness.dark));
    });
  }
  // x1.3 se
  goldenTest('home x1.3 se', (t) async {
    await pumpGoldenScreen(t, screen: const HomeScreen(), device: GoldenDevice.se, textScale: 1.3);
    await expectGolden(t, goldenName('home', 'data', GoldenDevice.se, Brightness.light, textScale: 1.3));
  });
  // en 393
  goldenTest('home en 393', (t) async {
    await pumpGoldenScreen(t, screen: const HomeScreen(), device: GoldenDevice.iphone16, locale: const Locale('en'));
    await expectGolden(t, goldenName('home', 'data', GoldenDevice.iphone16, Brightness.light, locale: const Locale('en')));
  });
}
