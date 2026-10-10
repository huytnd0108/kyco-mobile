// UX-M06 / web FE-47: explicit terms+privacy consent before account creation
// (signup + public become-tasker), and perf: list/grid network images decode at
// layout size (cacheWidth) instead of full size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/ui/media_image.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/auth/signup_screen.dart';
import 'package:kyco_mobile/features/become_tasker/become_tasker_screen.dart';

import 'wave_c_support.dart';

FilledButton _submit(WidgetTester t, String label) =>
    t.widget<FilledButton>(find.ancestor(of: find.text(label), matching: find.byType(FilledButton)));

void main() {
  group('signup consent', () {
    testWidgets('submit disabled until the box is checked; links open legal web pages', (t) async {
      useTallView(t);
      final opened = <Uri>[];
      final h = await harness(
        auth: const AuthState(status: AuthStatus.signedOut),
        opener: (u) async {
          opened.add(u);
          return true;
        },
      );
      await t.pumpWidget(appWith(h, const SignupScreen()));
      await t.pumpAndSettle();

      expect(find.text(vi.consentAgree), findsOneWidget);
      expect(_submit(t, vi.createAccount).onPressed, isNull);

      await t.tap(find.byKey(const ValueKey('consent-checkbox')));
      await t.pump();
      expect(_submit(t, vi.createAccount).onPressed, isNotNull);
      expect(find.byKey(const ValueKey('consent-error')), findsNothing);

      // Unchecking again shows the error and disables submit.
      await t.tap(find.byKey(const ValueKey('consent-checkbox')));
      await t.pump();
      expect(find.text(vi.consentRequired), findsOneWidget);
      expect(_submit(t, vi.createAccount).onPressed, isNull);

      await t.tap(find.byKey(const ValueKey('consent-terms-link')));
      await t.tap(find.byKey(const ValueKey('consent-privacy-link')));
      expect(opened.map((u) => u.path), ['/vi/legal/terms', '/vi/legal/privacy']);
    });

    testWidgets('accessible: checkbox is a labeled semantics node', (t) async {
      useTallView(t);
      final handle = t.ensureSemantics();
      final h = await harness(auth: const AuthState(status: AuthStatus.signedOut));
      await t.pumpWidget(appWith(h, const SignupScreen()));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel(vi.consentAgree), findsOneWidget);
      expect(
        t.getSemantics(find.byType(Checkbox)),
        isSemantics(hasCheckedState: true, isChecked: false, hasEnabledState: true, isEnabled: true),
      );
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('english copy + /en/ links', (t) async {
      useTallView(t);
      final opened = <Uri>[];
      final h = await harness(
        auth: const AuthState(status: AuthStatus.signedOut),
        opener: (u) async {
          opened.add(u);
          return true;
        },
      );
      await t.pumpWidget(appWith(h, const SignupScreen(), locale: const Locale('en')));
      await t.pumpAndSettle();
      expect(find.text('I agree to the Terms of Service and Privacy Policy'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('consent-terms-link')));
      expect(opened.single.path, '/en/legal/terms');
    });
  });

  group('become-tasker consent', () {
    testWidgets('guest: consent box present on the profile step, signed-in pending_tasker re-upload has none', (t) async {
      useTallView(t);
      final h = await harness(auth: signedInAs('pending_tasker'));
      await t.pumpWidget(appWith(h, const BecomeTaskerScreen()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('consent-checkbox')), findsNothing);

      await t.pumpWidget(const SizedBox());
      final g = await harness(auth: signedInAs('customer', id: 9));
      await t.pumpWidget(appWith(g, const BecomeTaskerScreen()));
      await t.pumpAndSettle();
      // Customer upgrade skips phone/OTP and lands on the profile step.
      expect(find.byKey(const ValueKey('consent-checkbox')), findsOneWidget);
      final btn = find.widgetWithText(FilledButton, vi.provTaskerSubmit);
      expect(t.widget<FilledButton>(btn).onPressed, isNull);
      await t.ensureVisible(find.byKey(const ValueKey('consent-checkbox')));
      await t.tap(find.byKey(const ValueKey('consent-checkbox')));
      await t.pump();
      expect(t.widget<FilledButton>(btn).onPressed, isNotNull);
    });
  });

  group('image decode size', () {
    testWidgets('SizedNetworkImage passes cacheWidth = layout width x devicePixelRatio', (t) async {
      t.view.physicalSize = const Size(800, 1200);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(devicePixelRatio: 2.0),
          child: Center(child: SizedBox(width: 150, height: 100, child: SizedNetworkImage('https://x.test/a.jpg'))),
        ),
      ));
      final img = t.widget<Image>(find.byType(Image));
      expect(img.image, isA<ResizeImage>());
      expect((img.image as ResizeImage).width, 300);
    });
  });
}
