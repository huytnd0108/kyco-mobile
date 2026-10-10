// UX-M46: no fixed height may clip or overflow when the user raises the font
// size (Android "Font size", iOS "Larger Text"). Each key screen is pumped at
// textScaler 1.6 and 2.0 on a phone and on the narrowest canary width; a
// RenderFlex overflow surfaces as a test exception.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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

typedef _Pump = Future<void> Function(WidgetTester t, GoldenDevice d, double scale);

/// Helpers that build their own MaterialApp pick the scale up from the
/// platform; [pumpGoldenScreen] has an explicit `textScale` instead.
Future<void> _withPlatformScale(
    WidgetTester t, double scale, Future<void> Function() pump) async {
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await pump();
}

final Map<String, _Pump> _screens = {
  'home': (t, d, s) =>
      pumpGoldenScreen(t, screen: const HomeScreen(), device: d, textScale: s),
  'services': (t, d, s) =>
      _withPlatformScale(t, s, () => pumpServices(t, device: d)),
  'service detail': (t, d, s) =>
      _withPlatformScale(t, s, () => pumpServiceDetail(t, device: d)),
  'checkout': (t, d, s) => _withPlatformScale(
      t, s, () => pumpCheckout(t, device: d, auth: Fakes.signedIn)),
  'bookings': (t, d, s) => pumpGoldenScreen(t,
      screen: withFakeBookingDetail(const BookingsScreen()), device: d, textScale: s),
  'booking detail': (t, d, s) => pumpGoldenScreen(t,
      screen: withFakeBookingDetail(const BookingDetailScreen(id: 1042)),
      device: d,
      textScale: s),
  'login': (t, d, s) => pumpGoldenScreen(t,
      screen: const LoginScreen(), device: d, textScale: s, auth: Fakes.signedOut),
  'tasker home': (t, d, s) => _withPlatformScale(t, s, () => pumpTaskerHome(t, device: d)),
  'tasker jobs': (t, d, s) => _withPlatformScale(t, s, () => pumpTaskerJobs(t, device: d)),
  'wallet': (t, d, s) => _withPlatformScale(t, s, () => pumpTaskerWallet(t, device: d)),
};

void main() {
  for (final e in _screens.entries) {
    for (final scale in const [1.6, 2.0]) {
      for (final d in const [GoldenDevice.iphone16, GoldenDevice.slideOver]) {
        testWidgets('${e.key}: no overflow at ${scale}x on ${d.size.width.toInt()}dp', (t) async {
          await e.value(t, d, scale);
          expect(t.takeException(), isNull);
        });
      }
    }
  }

  // OCD-022: booking rows reflow at big text. A date or an amount is ONE token:
  // the layout may move it to the next line but must give it room to fit - it
  // may never be split ("10/10/2\n026", "3.630.0\n00 đ"). For every Text on the
  // screen, each digit-bearing token must be narrower than the Text's box.
  for (final scale in const [1.6, 2.0]) {
    for (final d in const [GoldenDevice.iphone16, GoldenDevice.slideOver]) {
      testWidgets('bookings rows never break a date/price mid-token at ${scale}x on ${d.size.width.toInt()}dp',
          (t) async {
        await pumpGoldenScreen(t,
            screen: withFakeBookingDetail(const BookingsScreen()), device: d, textScale: scale);
        expect(t.takeException(), isNull);
        var checked = 0;
        for (final f in find.byType(Text).evaluate()) {
          final data = (f.widget as Text).data;
          if (data == null) continue;
          final ro = f.renderObject as RenderParagraph;
          for (final token in data.split(RegExp(r'\s+'))) {
            if (!RegExp(r'\d{2,}').hasMatch(token)) continue;
            final tp = TextPainter(
              text: TextSpan(text: token, style: ro.text.style),
              textDirection: TextDirection.ltr,
              textScaler: ro.textScaler,
            )..layout();
            expect(tp.width, lessThanOrEqualTo(ro.size.width + 0.5),
                reason: 'token "$token" of "$data" is wider than its box -> breaks mid-token');
            checked++;
          }
        }
        expect(checked, greaterThan(3), reason: 'the rows must render date/price tokens');
      });
    }
  }
}
