import 'package:flutter/material.dart';
import 'package:kyco_mobile/features/bookings/bookings_screen.dart';
import '_harness.dart';

void main() {
  // T1 sweep, light. At pro13 (≥840 && h≥600) the same pump renders two-pane.
  for (final d in GoldenDevice.values) {
    goldenTest('bookings list ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const BookingsScreen(), device: d);
      await expectGolden(t, goldenName('bookings', 'list', d, Brightness.light));
    });
  }
  // two-pane with selection, pro13
  goldenTest('bookings twopane selected pro13', (t) async {
    await pumpGoldenScreen(t, screen: const BookingsScreen(), device: GoldenDevice.pro13, selectedBookingId: 1042);
    await expectGolden(t, goldenName('bookings', 'twopane_selected', GoldenDevice.pro13, Brightness.light));
  });
  // dark {375, 1376}
  for (final d in [GoldenDevice.se, GoldenDevice.pro13]) {
    goldenTest('bookings dark ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const BookingsScreen(), device: d, brightness: Brightness.dark);
      await expectGolden(t, goldenName('bookings', 'list', d, Brightness.dark));
    });
  }
  // x1.3 {375, 320, 1376 two-pane}
  for (final d in [GoldenDevice.se, GoldenDevice.slideOver, GoldenDevice.pro13]) {
    goldenTest('bookings x1.3 ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const BookingsScreen(), device: d, textScale: 1.3);
      await expectGolden(t, goldenName('bookings', 'list', d, Brightness.light, textScale: 1.3));
    });
  }
  // en 393
  goldenTest('bookings en 393', (t) async {
    await pumpGoldenScreen(t, screen: const BookingsScreen(), device: GoldenDevice.iphone16, locale: const Locale('en'));
    await expectGolden(t, goldenName('bookings', 'list', GoldenDevice.iphone16, Brightness.light, locale: const Locale('en')));
  });
}
