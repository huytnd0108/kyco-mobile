// OCD-059 (pending_tasker sees a review state), OCD-067 (customer -> upgrade
// route; the public door's 409 tells a signed-out user to sign in first) and
// OCD-060 (role refresh), driven through the real router.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/core/locale_controller.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/become_tasker/become_tasker_screen.dart';

import '../wave_c_support.dart';

Future<(ProviderContainer, GoRouter, Backend)> _open(
  WidgetTester t, {
  required AuthState auth,
  Backend? backend,
}) async {
  useTallView(t, w: 420, h: 2200);
  final b = backend ?? Backend();
  final h = await harness(backend: b, auth: auth, extra: [
    kycPhotoPickerProvider.overrideWithValue(
        () async => XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'shot.jpg', mimeType: 'image/jpeg')),
  ]);
  final c = ProviderContainer(overrides: h.overrides);
  addTearDown(c.dispose);
  await c.read(localeControllerProvider.notifier).set(const Locale('vi'));
  await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KycoApp()));
  await t.pumpAndSettle();
  final router = c.read(routerProvider);
  unawaited(router.push<Object?>('/become-tasker'));
  await t.pumpAndSettle();
  return (c, router, b);
}

String _loc(GoRouter r) => r.routerDelegate.currentConfiguration.last.matchedLocation;

Future<void> _captureAll(WidgetTester t) async {
  for (final label in [vi.provTaskerKycFront, vi.provTaskerKycBack, vi.provTaskerKycSelfie]) {
    await t.tap(find.text(label));
    await t.pumpAndSettle();
  }
  // Consent (UX-M06) is required before submit, except for a KYC re-upload.
  final consent = find.byKey(const ValueKey('consent-checkbox'));
  if (consent.evaluate().isNotEmpty) {
    await t.ensureVisible(consent);
    await t.tap(consent);
    await t.pumpAndSettle();
  }
}

void main() {
  group('OCD-059 pending_tasker', () {
    testWidgets('sees "Hồ sơ đang được duyệt" and what happens next, not the upload form', (t) async {
      await _open(t, auth: signedInAs('pending_tasker'));
      expect(find.byKey(const ValueKey('tasker-pending-review')), findsOneWidget);
      expect(find.text(vi.taskerReviewTitle), findsOneWidget);
      expect(vi.taskerReviewTitle, 'Hồ sơ đang được duyệt');
      expect(find.text(vi.taskerReviewNext1), findsOneWidget);
      expect(find.text(vi.taskerReviewNext2), findsOneWidget);
      expect(find.text(vi.provTaskerCaptureDocsTitle), findsNothing);
    });

    testWidgets('"Chụp lại giấy tờ" reveals the re-upload form', (t) async {
      await _open(t, auth: signedInAs('pending_tasker'));
      await t.tap(find.byKey(const ValueKey('tasker-review-reupload')));
      await t.pumpAndSettle();
      expect(find.text(vi.provTaskerCaptureDocsTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-pending-review')), findsNothing);
    });

    testWidgets('refresh: still pending -> message; approved -> opens the workspace', (t) async {
      var role = 'pending_tasker';
      final b = Backend()..on('GET /me', (_) => Backend.ok({'id': 7, 'role': role, 'name': 'Ngọc Anh'}));
      final (_, router, _) = await _open(t, auth: signedInAs('pending_tasker'), backend: b);
      await t.tap(find.byKey(const ValueKey('tasker-review-refresh')));
      await t.pumpAndSettle();
      expect(find.text(vi.taskerReviewStillPending), findsOneWidget);
      expect(_loc(router), '/become-tasker');

      await t.pump(const Duration(seconds: 6)); // snackbar gone
      role = 'tasker';
      await t.tap(find.byKey(const ValueKey('tasker-review-refresh')));
      await t.pumpAndSettle();
      expect(_loc(router), '/p');
    });
  });

  group('OCD-067 customer / guest doors', () {
    testWidgets('a signed-in customer skips OTP and submits to /become-tasker/upgrade', (t) async {
      final b = Backend()
        ..on('POST /become-tasker/upgrade', (_) => Backend.ok({'userId': 7}, status: 201))
        ..on('GET /me', (_) => Backend.ok({'id': 7, 'role': 'pending_tasker', 'name': 'Ngọc Anh'}));
      await _open(t, auth: signedInAs('customer'), backend: b);
      expect(find.byKey(const ValueKey('tasker-upgrade-intro')), findsOneWidget);
      expect(find.text(vi.provSendOtp), findsNothing, reason: 'no phone / OTP step for a signed-in user');
      expect(find.text(vi.provTaskerCaptureDocsTitle), findsOneWidget);

      await t.enterText(find.widgetWithText(TextField, vi.provTaskerDistrict), 'Quận 1');
      await _captureAll(t);
      await t.tap(find.text(vi.provTaskerSubmit));
      await t.pumpAndSettle();

      expect(b.calls('POST /become-tasker/upgrade'), hasLength(1));
      expect(b.calls('POST /become-tasker'), isEmpty, reason: 'never the public door');
      expect(b.calls('POST /auth/otp/request'), isEmpty);
      expect(find.text(vi.provTaskerDoneTitle), findsOneWidget);
      expect(b.calls('GET /me'), isNotEmpty, reason: 'the role is refreshed after applying');
    });

    Future<void> guestFillAndSubmit(WidgetTester t) async {
      await t.enterText(find.widgetWithText(TextField, vi.provPhoneLabel), '0912345678');
      await t.tap(find.text(vi.provSendOtp));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, vi.provOtpLabel), '1234567');
      await t.tap(find.text(vi.provTaskerContinue));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, vi.provTaskerFullName), 'Lan');
      await t.enterText(find.widgetWithText(TextField, vi.provTaskerDistrict), 'Quận 1');
      await _captureAll(t);
      // OCD-057: a captured document says "Đã chụp", never the temp file name.
      expect(find.text('shot.jpg'), findsNothing);
      expect(find.text(vi.provTaskerCaptured), findsNWidgets(3));
      await t.tap(find.text(vi.provTaskerSubmit));
      await t.pumpAndSettle();
    }

    testWidgets('OCD-058: a guest who applied is told how to track the application (sign in by phone)',
        (t) async {
      final b = Backend()
        ..on('POST /auth/otp/request', (_) => Backend.ok({}))
        ..on('POST /become-tasker', (_) => Backend.ok({'userId': 31}, status: 201));
      await _open(t, auth: const AuthState(status: AuthStatus.signedOut), backend: b);
      await guestFillAndSubmit(t);
      expect(find.text(vi.provTaskerDoneTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-done-signin-hint')), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-done-login')), findsOneWidget);
    });

    testWidgets('signed out: a 409 on the public door says to sign in first, with a sign-in button',
        (t) async {
      final b = Backend()
        ..on('POST /auth/otp/request', (_) => Backend.ok({}))
        ..on('POST /become-tasker',
            (_) => Backend.err(409, 'CONFLICT', 'Phone already registered. Please sign in or use a different number.'));
      await _open(t, auth: const AuthState(status: AuthStatus.signedOut), backend: b);
      await guestFillAndSubmit(t);

      expect(b.calls('POST /become-tasker'), hasLength(1));
      expect(find.text(vi.taskerPhoneExistsLogin), findsOneWidget);
      expect(find.byKey(const ValueKey('tasker-login-first')), findsOneWidget);
    });
  });

  testWidgets('OCD-060: returning to the app re-reads /me, so an approval shows up without a cold start',
      (t) async {
    final b = Backend()
      ..on('GET /me', (_) => Backend.ok({'id': 7, 'role': 'tasker', 'name': 'Ngọc Anh'}));
    final (c, _, _) = await _open(t, auth: signedInAs('pending_tasker'), backend: b);
    expect(c.read(authControllerProvider).user?.role, 'pending_tasker');
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(b.calls('GET /me'), isNotEmpty);
    expect(c.read(authControllerProvider).user?.role, 'tasker');
  });
}
