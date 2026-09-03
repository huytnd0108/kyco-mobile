import 'package:flutter/material.dart';
import 'package:kyco_mobile/features/bookings/booking_detail_screen.dart';
import '_harness.dart';

void main() {
  // Pushed detail on sizes < 840 (≥840 self-ejects into the two-pane, covered by bookings).
  for (final d in [GoldenDevice.se, GoldenDevice.iphone16, GoldenDevice.ipadMini]) {
    goldenTest('detail ${d.name}', (t) async {
      await pumpGoldenScreen(t, screen: const BookingDetailScreen(id: 1042), device: d);
      await expectGolden(t, goldenName('detail', 'pushed', d, Brightness.light));
    });
  }
  goldenTest('detail dark 393', (t) async {
    await pumpGoldenScreen(t, screen: const BookingDetailScreen(id: 1042), device: GoldenDevice.iphone16, brightness: Brightness.dark);
    await expectGolden(t, goldenName('detail', 'pushed', GoldenDevice.iphone16, Brightness.dark));
  });
  goldenTest('detail x1.3 se', (t) async {
    await pumpGoldenScreen(t, screen: const BookingDetailScreen(id: 1042), device: GoldenDevice.se, textScale: 1.3);
    await expectGolden(t, goldenName('detail', 'pushed', GoldenDevice.se, Brightness.light, textScale: 1.3));
  });
}
