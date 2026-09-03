import 'package:flutter/material.dart';
import 'package:kyco_mobile/features/auth/login_screen.dart';
import 'package:kyco_mobile/features/auth/signup_screen.dart';
import '_fakes.dart';
import '_harness.dart';

void main() {
  const sizes = [GoldenDevice.se, GoldenDevice.iphone16, GoldenDevice.ipadMini, GoldenDevice.pro13];
  for (final d in sizes) {
    goldenTest('login ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const LoginScreen(), device: d, auth: Fakes.signedOut);
      await expectGolden(t, goldenName('login', 'default', d, Brightness.light));
    });
    goldenTest('signup ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const SignupScreen(), device: d, auth: Fakes.signedOut);
      await expectGolden(t, goldenName('signup', 'default', d, Brightness.light));
    });
  }
  goldenTest('login error 393', (t) async {
    await pumpGoldenScreen(t, screen: const LoginScreen(), device: GoldenDevice.iphone16, auth: Fakes.signedOutError);
    await expectGolden(t, goldenName('login', 'error', GoldenDevice.iphone16, Brightness.light));
  });
  goldenTest('login dark 393', (t) async {
    await pumpGoldenScreen(t, screen: const LoginScreen(), device: GoldenDevice.iphone16, brightness: Brightness.dark, auth: Fakes.signedOut);
    await expectGolden(t, goldenName('login', 'default', GoldenDevice.iphone16, Brightness.dark));
  });
  goldenTest('login x1.3 se', (t) async {
    await pumpGoldenScreen(t, screen: const LoginScreen(), device: GoldenDevice.se, textScale: 1.3, auth: Fakes.signedOut);
    await expectGolden(t, goldenName('login', 'default', GoldenDevice.se, Brightness.light, textScale: 1.3));
  });
  goldenTest('login en 393', (t) async {
    await pumpGoldenScreen(t, screen: const LoginScreen(), device: GoldenDevice.iphone16, locale: const Locale('en'), auth: Fakes.signedOut);
    await expectGolden(t, goldenName('login', 'default', GoldenDevice.iphone16, Brightness.light, locale: const Locale('en')));
  });
}
