// Wave C - UX-M08 account deletion, restore, UX-M16 tasker settings entry.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/account/delete_account_screen.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/tasker_shell/tasker_more_screen.dart';
import 'package:kyco_mobile/features/tasker_shell/tasker_settings_screen.dart';

import 'wave_c_support.dart';

Backend _backend({bool stepUpFresh = true}) {
  final b = Backend();
  b.on('GET /me/account/deletion', (_) => Backend.ok({'state': 'active', 'requestedAt': null, 'scheduledFor': null}));
  b.on('GET /auth/step-up', (_) => Backend.ok({'fresh': stepUpFresh, 'hasUsablePassword': true}));
  b.on('POST /me/account/deletion',
      (_) => Backend.ok({'state': 'pending', 'scheduledFor': '2026-11-09T12:00:00.000Z'}));
  b.on('POST /data-export', (_) => Backend.ok({'id': 3}, status: 201));
  b.on('POST /auth/logout', (_) => Backend.ok({}));
  return b;
}

Future<void> _type(WidgetTester t, String word) async {
  await t.enterText(find.byKey(const ValueKey('delete-confirm-field')), word);
  await t.pump();
}

void main() {
  group('DeletionStatus parsing', () {
    test('GET shape and POST shape', () {
      final a = DeletionStatus.fromJson({'state': 'pending', 'requestedAt': 'x', 'scheduledFor': '2026-11-09T00:00:00Z'});
      expect(a.pending, isTrue);
      expect(a.scheduledFor, '2026-11-09T00:00:00Z');
      expect(DeletionStatus.fromJson({'state': 'active', 'scheduledFor': null}).pending, isFalse);
      expect(DeletionStatus.fromJson(const {}).pending, isFalse);
    });
  });

  group('UX-M08 delete account', () {
    testWidgets('explains consequences + grace, confirm needs the typed word', (t) async {
      useTallView(t);
      final h = await harness(backend: _backend());
      await t.pumpWidget(routerWith(h, '/d', {'/d': (_) => const DeleteAccountScreen()}));
      await t.pumpAndSettle();
      expect(find.text(vi.deleteAccountIntro), findsOneWidget);
      expect(find.textContaining('30 ngày'), findsWidgets);
      final submit = find.byKey(const ValueKey('delete-submit'));
      expect(t.widget<FilledButton>(submit).onPressed, isNull, reason: 'disabled until confirmed');
      await _type(t, 'xoa');
      expect(t.widget<FilledButton>(submit).onPressed, isNull, reason: 'wrong word');
      await _type(t, 'xóa'); // case-insensitive match of XÓA
      expect(t.widget<FilledButton>(submit).onPressed, isNotNull);
    });

    testWidgets('request -> POST {confirm:true} -> sign out -> restore screen with date', (t) async {
      useTallView(t);
      final b = _backend();
      final auth = TestAuth(signedInAs('customer'));
      final h = await harness(backend: b, authController: auth);
      await t.pumpWidget(routerWith(h, '/delete-account', {
        '/delete-account': (_) => const DeleteAccountScreen(),
        '/restore-account': (s) => RestoreAccountScreen(scheduledFor: s.uri.queryParameters['scheduled']),
      }));
      await t.pumpAndSettle();
      await _type(t, 'XÓA');
      await t.tap(find.byKey(const ValueKey('delete-submit')));
      await t.pumpAndSettle();

      final post = b.calls('POST /me/account/deletion').toList();
      expect(post, hasLength(1));
      expect(post.single.data, {'confirm': true});
      expect(auth.logouts, 1, reason: 'signed out after the server accepted');
      expect(find.byType(RestoreAccountScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('restore-pending-body')), findsOneWidget);
      expect(find.textContaining('2026'), findsWidgets, reason: 'scheduled date shown (VN)');
    });

    testWidgets('a stale step-up is detected first; the POST is not sent when the user backs out', (t) async {
      useTallView(t);
      final b = _backend(stepUpFresh: false);
      final auth = TestAuth(signedInAs('customer'));
      final h = await harness(backend: b, authController: auth);
      await t.pumpWidget(routerWith(h, '/d', {'/d': (_) => const DeleteAccountScreen()}));
      await t.pumpAndSettle();
      await _type(t, 'XÓA');
      await t.tap(find.byKey(const ValueKey('delete-submit')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600)); // sheet animation (field blinks forever)
      expect(find.text(vi.provWalletStepUpTitle), findsOneWidget, reason: 'step-up sheet shown');
      // Dismiss the sheet (tap the barrier).
      await t.tapAt(const Offset(10, 10));
      await t.pump(const Duration(milliseconds: 600));
      await t.pump(const Duration(milliseconds: 600));
      expect(b.calls('POST /me/account/deletion'), isEmpty);
      expect(auth.logouts, 0);
    });

    testWidgets('open bookings -> server 409 text shown, NOT signed out', (t) async {
      useTallView(t);
      final b = _backend();
      b.on('POST /me/account/deletion',
          (_) => Backend.err(409, 'CONFLICT', 'Bạn còn 2 đơn chưa hoàn tất.'));
      final auth = TestAuth(signedInAs('customer'));
      final h = await harness(backend: b, authController: auth);
      await t.pumpWidget(routerWith(h, '/d', {'/d': (_) => const DeleteAccountScreen()}));
      await t.pumpAndSettle();
      await _type(t, 'XÓA');
      await t.tap(find.byKey(const ValueKey('delete-submit')));
      await t.pumpAndSettle();
      expect(find.text('Bạn còn 2 đơn chưa hoàn tất.'), findsOneWidget);
      expect(auth.logouts, 0);
    });

    testWidgets('data export first: POST /data-export once', (t) async {
      useTallView(t);
      final b = _backend();
      final h = await harness(backend: b);
      await t.pumpWidget(routerWith(h, '/d', {'/d': (_) => const DeleteAccountScreen()}));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('delete-export')));
      await t.tap(find.byKey(const ValueKey('delete-export')));
      await t.pumpAndSettle();
      expect(b.calls('POST /data-export'), hasLength(1));
      expect(find.text(vi.deleteExportRequested), findsOneWidget);
    });

    testWidgets('tasker cannot self-delete: support guidance, no form', (t) async {
      useTallView(t);
      final b = _backend();
      final h = await harness(backend: b, auth: signedInAs('tasker'));
      await t.pumpWidget(routerWith(h, '/d', {'/d': (_) => const DeleteAccountScreen()}));
      await t.pumpAndSettle();
      expect(find.text(vi.deleteSupportOnly), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-confirm-field')), findsNothing);
      expect(find.byKey(const ValueKey('delete-contact-support')), findsOneWidget);
    });

    testWidgets('server says pending -> pending state with cancel action', (t) async {
      useTallView(t);
      final b = _backend();
      b.on('GET /me/account/deletion',
          (_) => Backend.ok({'state': 'pending', 'requestedAt': 'x', 'scheduledFor': '2026-11-09T12:00:00Z'}));
      final h = await harness(backend: b);
      await t.pumpWidget(routerWith(h, '/d', {'/d': (_) => const DeleteAccountScreen()}));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-pending-cancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('delete-confirm-field')), findsNothing);
    });
  });

  group('restore (cancel deletion)', () {
    testWidgets('POSTs email+password to the public cancel route, then offers sign-in', (t) async {
      useTallView(t);
      final b = _backend();
      b.on('POST /auth/account-deletion/cancel', (_) => Backend.ok({'restored': true}));
      final h = await harness(backend: b, auth: const AuthState(status: AuthStatus.signedOut));
      await t.pumpWidget(appWith(h, const RestoreAccountScreen(scheduledFor: '2026-11-09T12:00:00Z')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('restore-email')), 'a@b.vn');
      await t.enterText(find.byKey(const ValueKey('restore-password')), 'pw-123456');
      await t.tap(find.byKey(const ValueKey('restore-submit')));
      await t.pumpAndSettle();
      final call = b.calls('POST /auth/account-deletion/cancel').single;
      expect(call.data, {'email': 'a@b.vn', 'password': 'pw-123456'});
      expect(call.headers.containsKey('authorization'), isFalse, reason: 'public route: no Bearer');
      expect(find.byKey(const ValueKey('restore-success')), findsOneWidget);
    });

    testWidgets('generic 401 -> friendly failure copy, form stays', (t) async {
      useTallView(t);
      final b = _backend();
      b.on('POST /auth/account-deletion/cancel', (_) => Backend.err(401, 'AUTH_REQUIRED'));
      final h = await harness(backend: b, auth: const AuthState(status: AuthStatus.signedOut));
      await t.pumpWidget(appWith(h, const RestoreAccountScreen()));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('restore-email')), 'a@b.vn');
      await t.enterText(find.byKey(const ValueKey('restore-password')), 'wrong');
      await t.tap(find.byKey(const ValueKey('restore-submit')));
      await t.pumpAndSettle();
      expect(find.text(vi.restoreFailed), findsOneWidget);
      expect(find.byKey(const ValueKey('restore-submit')), findsOneWidget);
    });
  });

  group('UX-M16 tasker shell reaches settings + deletion guidance', () {
    testWidgets('More lists the settings row', (t) async {
      useTallView(t);
      final h = await harness(auth: signedInAs('tasker'));
      await t.pumpWidget(appWith(h, const TaskerMoreScreen()));
      await t.pumpAndSettle();
      expect(find.text(vi.settingsAndAccountTitle), findsOneWidget);
    });

    testWidgets('settings has notifications, theme, language and the delete row', (t) async {
      useTallView(t);
      final h = await harness(auth: signedInAs('tasker'));
      String? pushed;
      await t.pumpWidget(routerWith(h, '/p/settings', {
        '/p/settings': (_) => const TaskerSettingsScreen(),
        '/notifications': (_) => const Scaffold(body: Text('NOTIF')),
        '/delete-account': (_) => const Scaffold(body: Text('DEL')),
      }, onRouter: (r) => r.routerDelegate.addListener(() => pushed = r.state.uri.path)));
      await t.pumpAndSettle();
      expect(find.text(vi.notificationsTitle), findsOneWidget);
      expect(find.text(vi.appearance), findsOneWidget);
      expect(find.text(vi.language), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('tasker-settings-delete')));
      await t.pumpAndSettle();
      expect(find.text('DEL'), findsOneWidget);
      expect(pushed, '/delete-account');
      expect(GoRouter.of(t.element(find.text('DEL'))).state.uri.path, '/delete-account');
    });
  });
}
