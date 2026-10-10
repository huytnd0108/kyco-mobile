// UX-M49 (gate mob-q-a11y): WCAG / platform accessibility guidelines as test
// failures, not review notes. Uses the golden fakes (no network, no storage).
//   - androidTapTargetGuideline  (>= 48 x 48 dp)
//   - iOSTapTargetGuideline      (>= 44 x 44 pt)
//   - labeledTapTargetGuideline  (every tappable has a semantic label)
//   - textContrastGuideline      (WCAG AA over the rendered pixels)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/features/auth/login_screen.dart';
import 'package:kyco_mobile/features/bookings/booking_detail_screen.dart';
import 'package:kyco_mobile/features/bookings/bookings_screen.dart';
import 'package:kyco_mobile/features/home/home_screen.dart';

import '../goldens/_cust2_fakes.dart';
import '../goldens/_fakes.dart';
import '../goldens/_harness.dart';
import '../goldens/checkout_golden_test.dart' show pumpCheckout;
import '../goldens/service_detail_golden_test.dart' show pumpServiceDetail;
import '../goldens/services_golden_test.dart' show pumpServices;
import '../goldens/tasker_home_golden_test.dart' show pumpTaskerHome;
import '../goldens/tasker_jobs_golden_test.dart' show pumpTaskerJobs;
import '../goldens/tasker_wallet_golden_test.dart' show pumpTaskerWallet;

typedef _Pump = Future<void> Function(WidgetTester t, Brightness b);

const _device = GoldenDevice.iphone16;

final Map<String, _Pump> _screens = {
  'home': (t, b) => pumpGoldenScreen(t, screen: const HomeScreen(), device: _device, brightness: b),
  'services': (t, b) => pumpServices(t, device: _device, brightness: b),
  'service detail': (t, b) => pumpServiceDetail(t, device: _device, brightness: b),
  'checkout': (t, b) => pumpCheckout(t, device: _device, auth: Fakes.signedIn, brightness: b),
  'bookings': (t, b) => pumpGoldenScreen(t,
      screen: withFakeBookingDetail(const BookingsScreen()), device: _device, brightness: b),
  'booking detail': (t, b) => pumpGoldenScreen(t,
      screen: withFakeBookingDetail(const BookingDetailScreen(id: 1042)), device: _device, brightness: b),
  'login': (t, b) => pumpGoldenScreen(t,
      screen: const LoginScreen(), device: _device, brightness: b, auth: Fakes.signedOut),
  'tasker home': (t, b) => pumpTaskerHome(t, device: _device, brightness: b),
  'tasker jobs': (t, b) => pumpTaskerJobs(t, device: _device, brightness: b),
  'wallet': (t, b) => pumpTaskerWallet(t, device: _device, brightness: b),
};

void main() {
  for (final e in _screens.entries) {
    group('a11y ${e.key}', () {
      testWidgets('tap targets (Android 48dp, iOS 44pt) + labeled targets', (t) async {
        final handle = t.ensureSemantics();
        await e.value(t, Brightness.light);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      for (final b in Brightness.values) {
        testWidgets('text contrast (${b.name})', (t) async {
          final handle = t.ensureSemantics();
          await e.value(t, b);
          await expectLater(t, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    });
  }
}
