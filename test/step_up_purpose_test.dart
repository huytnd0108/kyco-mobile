// OCD-051 / OCD-054: the step-up sheet explains the ACTION being confirmed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/features/tasker_wallet/step_up_sheet.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import 'wave_c_support.dart';

Future<void> _open(WidgetTester t, StepUpPurpose purpose, {required bool password, Locale locale = const Locale('vi')}) async {
  final h = await harness();
  await t.pumpWidget(appWith(
    h,
    Scaffold(body: StepUpSheet(hasUsablePassword: password, purpose: purpose)),
    locale: locale,
  ));
  await t.pumpAndSettle();
}

void main() {
  const wd = 'rút tiền';
  for (final p in StepUpPurpose.values) {
    testWidgets('password path copy: $p', (t) async {
      await _open(t, p, password: true);
      final text = stepUpPasswordCopy(vi, p);
      expect(find.text(text), findsOneWidget);
      if (p == StepUpPurpose.withdraw) {
        expect(text, contains(wd));
      } else {
        expect(text, isNot(contains(wd)), reason: '$p must not talk about withdrawing');
      }
    });
  }

  testWidgets('delete account and change phone say so, in VI and EN', (t) async {
    expect(stepUpPasswordCopy(vi, StepUpPurpose.deleteAccount), contains('xóa tài khoản'));
    expect(stepUpPasswordCopy(vi, StepUpPurpose.changePhone), contains('đổi số điện thoại'));
    final en = lookupAppLocalizations(const Locale('en'));
    expect(stepUpPasswordCopy(en, StepUpPurpose.deleteAccount).toLowerCase(), contains('deleting your account'));
    expect(stepUpPasswordCopy(en, StepUpPurpose.changePhone).toLowerCase(), contains('phone number'));
    for (final p in [StepUpPurpose.deleteAccount, StepUpPurpose.changePhone, StepUpPurpose.generic]) {
      expect(stepUpPasswordCopy(en, p).toLowerCase(), isNot(contains('withdraw')));
      expect(stepUpOtpCopy(en, p).toLowerCase(), isNot(contains('withdraw')));
      expect(stepUpOtpCopy(vi, p), isNot(contains(wd)));
    }
  });

  testWidgets('the default (no purpose) is the generic copy, never the withdrawal one', (t) async {
    final h = await harness();
    await t.pumpWidget(appWith(h, const Scaffold(body: StepUpSheet(hasUsablePassword: true))));
    await t.pumpAndSettle();
    expect(find.text(vi.stepUpPasswordGeneric), findsOneWidget);
    expect(find.text(vi.provWalletStepUpPassword), findsNothing);
  });
}
