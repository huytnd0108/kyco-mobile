import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/features/auth/auth_controller.dart';
import 'package:kyco_mobile/features/auth/login_screen.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/theme/color_schemes.dart';

/// Records the phone-login calls; first login answers TOTP_REQUIRED.
class _FakeAuth extends AuthController {
  final otpRequests = <String>[];
  final logins = <(String, String, String?)>[];
  @override
  AuthState build() => const AuthState(status: AuthStatus.signedOut);
  @override
  Future<void> bootstrap() async {}
  @override
  Future<Object?> requestLoginOtp(String phone) async {
    otpRequests.add(phone);
    return null;
  }

  @override
  Future<bool> loginWithOtp({required String phone, required String code, String? totpCode}) async {
    logins.add((phone, code, totpCode));
    if (totpCode == null) {
      state = state.copyWith(failure: ApiException('TOTP_REQUIRED', 'x', status: 401));
      return false;
    }
    return false; // stay on screen (no router in this harness)
  }
}

void main() {
  testWidgets('phone mode: send OTP → code field → login; TOTP_REQUIRED reveals the 2FA field', (t) async {
    t.view.physicalSize = const Size(430, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    final fake = _FakeAuth();
    await t.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith(() => fake)],
      child: MaterialApp(
        theme: buildTheme(lightColorScheme),
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LoginScreen(),
      ),
    ));
    final l = lookupAppLocalizations(const Locale('vi'));
    await t.tap(find.text(l.cust2LoginModePhone));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-otp')), findsNothing);

    await t.enterText(find.byKey(const ValueKey('login-phone')), '0901110002');
    await t.tap(find.byKey(const ValueKey('login-send-otp')));
    await t.pumpAndSettle();
    expect(fake.otpRequests, ['0901110002']);
    expect(find.byKey(const ValueKey('login-otp')), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('login-otp')), '1234567');
    await t.tap(find.byKey(const ValueKey('login-submit')));
    await t.pumpAndSettle();
    expect(fake.logins.single, ('0901110002', '1234567', null));
    expect(find.byKey(const ValueKey('login-totp')), findsOneWidget);
    expect(find.text(l.cust2ErrTotpRequired), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('login-totp')), '654321');
    await t.ensureVisible(find.byKey(const ValueKey('login-submit')));
    await t.tap(find.byKey(const ValueKey('login-submit')));
    await t.pumpAndSettle();
    expect(fake.logins.last, ('0901110002', '1234567', '654321'));
  });
}
