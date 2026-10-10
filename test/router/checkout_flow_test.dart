// OCD-013 / OCD-014: checkout success sheet leaves the form alone (no red
// "required" errors behind it) and the sticky total follows the server quote.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/core/locale_controller.dart';
import 'package:kyco_mobile/features/checkout/draft_store.dart';

import '../wave_c_support.dart';

Backend _backend({required int quoteTotal}) => Backend()
  ..on('GET /services/62', (_) => Backend.ok({
        'id': 62, 'slug': 's', 'name': 'Dọn nhà 3 giờ', 'category': 'hourly',
        'basePriceVnd': 240000, 'durationMinutes': 180,
      }))
  ..on('GET /locations/tree', (_) => Backend.ok(<Object>[]))
  ..on('POST /bookings/quote', (_) => Backend.ok({
        'totalVnd': quoteTotal,
        'breakdown': {'baseVnd': 240000, 'surchargesVnd': 30000, 'totalVnd': quoteTotal},
      }))
  ..on('POST /bookings', (_) => Backend.ok(
      {'kind': 'created', 'bookingId': 148, 'totalVnd': quoteTotal, 'confirmationCode': 'ABC123'},
      status: 201));

Future<(ProviderContainer, GoRouter)> _open(WidgetTester t, Backend b) async {
  useTallView(t, w: 420, h: 1800);
  final h = await harness(backend: b, auth: signedInAs('customer'));
  final c = ProviderContainer(overrides: h.overrides);
  addTearDown(c.dispose);
  await c.read(localeControllerProvider.notifier).set(const Locale('vi'));
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KycoApp()));
  await t.pumpAndSettle();
  final router = c.read(routerProvider);
  unawaited(router.push<Object?>('/checkout/62'));
  await t.pumpAndSettle();
  return (c, router);
}

void _fill(ProviderContainer c) {
  final d = c.read(draftControllerProvider(62).notifier);
  d.setDate('2099-01-05');
  d.setTime('09:00');
  d.setWard(26734, 'Phường Bến Thành');
  d.setAddressLine('12 Lê Lợi');
}

void main() {
  testWidgets('OCD-014: the sticky total switches from the base estimate to the server quote', (t) async {
    final b = _backend(quoteTotal: 270000);
    final (c, _) = await _open(t, b);
    expect(find.text(vi.moneyEstimateLabel), findsOneWidget);
    expect(find.text('240.000₫'), findsWidgets);

    _fill(c);
    await t.pump();
    // Debounce (500 ms) then the POST /bookings/quote round trip.
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();

    expect(b.calls('POST /bookings/quote'), isNotEmpty);
    expect(find.text(vi.moneyQuoteLabel), findsOneWidget);
    expect(find.text('270.000₫'), findsWidgets);
    expect(find.text(vi.moneyEstimateLabel), findsNothing);
  });

  testWidgets('OCD-013: after a successful create no "required" errors appear behind the sheet',
      (t) async {
    final b = _backend(quoteTotal: 270000);
    final (c, router) = await _open(t, b);

    // Provoke the inline errors first (the real-life path: the user tapped
    // Confirm once before filling everything in).
    await t.tap(find.text(vi.confirmBooking));
    await t.pumpAndSettle();
    expect(find.text(vi.cust2Required), findsWidgets);

    _fill(c);
    await t.pumpAndSettle();
    expect(find.text(vi.cust2Required), findsNothing);

    await t.tap(find.text(vi.confirmBooking));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(seconds: 1));

    expect(b.calls('POST /bookings'), hasLength(1));
    // Success sheet is up ...
    expect(find.text(vi.bookingCreated(148)), findsOneWidget);
    // ... the form behind it is untouched and shows no validation errors.
    expect(find.text(vi.cust2Required), findsNothing);
    expect(c.read(draftControllerProvider(62)), isNotNull);
    expect(c.read(draftControllerProvider(62))!.addressLine, '12 Lê Lợi');

    // Leaving through the sheet clears the draft and opens the booking.
    await t.tap(find.text(vi.viewDetails));
    await t.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/bookings/148');
    expect(c.read(draftControllerProvider(62)), isNull);
  });

  testWidgets('OCD-013: swiping the sheet away still leaves for the booking, without error flashes',
      (t) async {
    final b = _backend(quoteTotal: 270000);
    final (c, router) = await _open(t, b);
    _fill(c);
    await t.pumpAndSettle();
    await t.tap(find.text(vi.confirmBooking));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(seconds: 1));
    expect(find.text(vi.bookingCreated(148)), findsOneWidget);

    // Dismiss by tapping the scrim (same path as a swipe: route popped w/o result).
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/bookings/148');
    expect(find.text(vi.cust2Required), findsNothing);
    expect(c.read(draftControllerProvider(62)), isNull);
  });
}
