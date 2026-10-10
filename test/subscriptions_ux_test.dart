// OCD-008 / OCD-027: no "0₫/tháng", no duplicated duration chip, specific empty copy.
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/subscriptions/subscriptions_screen.dart';

import 'wave_c_support.dart';

Future<void> _pump(WidgetTester t, Backend b, {bool signedIn = false}) async {
  useTallView(t, w: 420, h: 1800);
  final h = await harness(
    backend: b,
    auth: signedIn ? signedInAs('customer') : const AuthState(status: AuthStatus.signedOut),
  );
  await t.pumpWidget(appWith(h, const SubscriptionsScreen()));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('a 0 / missing price shows "Liên hệ", a real price shows per month; no "0₫/tháng"', (t) async {
    final b = Backend()
      ..on('GET /plans', (_) => Backend.ok([
            {'id': 1, 'slug': 'free', 'title': 'Gói tư vấn', 'priceMonthlyVnd': 0, 'durationMonths': 1},
            {'id': 2, 'slug': 'pro', 'title': 'Gói nâng cao', 'priceMonthlyVnd': 900000, 'durationMonths': 3},
          ]));
    await _pump(t, b);
    expect(find.text(vi.contactUs), findsOneWidget);
    expect(find.text(vi.perMonth('900.000₫')), findsOneWidget);
    expect(find.text(vi.perMonth('0₫')), findsNothing);
  });

  testWidgets('the duration chip is dropped when the title already says it, kept otherwise', (t) async {
    final b = Backend()
      ..on('GET /plans', (_) => Backend.ok([
            {'id': 1, 'slug': 'a', 'title': 'Gói 3 tháng', 'priceMonthlyVnd': 500000, 'durationMonths': 3},
            {'id': 2, 'slug': 'b', 'title': 'Gói tiết kiệm', 'priceMonthlyVnd': 400000, 'durationMonths': 6},
          ]));
    await _pump(t, b);
    expect(find.text(vi.monthsCount(3)), findsNothing, reason: 'redundant with the title');
    expect(find.text(vi.monthsCount(6)), findsOneWidget);
  });

  testWidgets('"Gói của tôi" empty state says there is no plan yet, not "no results"', (t) async {
    final b = Backend()
      ..on('GET /plans', (_) => Backend.ok([]))
      ..on('GET /subscriptions', (_) => Backend.ok([]));
    await _pump(t, b, signedIn: true);
    expect(find.text(vi.subscriptionsEmptyMine), findsOneWidget);
    expect(vi.subscriptionsEmptyMine, 'Bạn chưa đăng ký gói nào.');
  });
}
