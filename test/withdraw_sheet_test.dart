// OCD-062 (human-approved 2026-10-10): the withdraw amount field starts EMPTY;
// the tasker types the amount and exactly that amount is returned (and sent).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/features/tasker_wallet/withdraw_sheet.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import 'wave_c_support.dart';

Future<int?> _open(WidgetTester t, {int balance = 500000, String? typed}) async {
  int? result;
  var done = false;
  await t.pumpWidget(MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (ctx) => TextButton(
        onPressed: () async {
          result = await showModalBottomSheet<int>(
            context: ctx,
            isScrollControlled: true,
            builder: (_) => WithdrawSheet(balanceVnd: balance),
          );
          done = true;
        },
        child: const Text('open'),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  if (typed != null) {
    await t.enterText(find.byType(TextField), typed);
    await t.tap(find.text(vi.provWalletContinue));
    await t.pumpAndSettle();
  }
  return done ? result : null;
}

String _fieldText(WidgetTester t) =>
    t.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('opens with an EMPTY field (no balance prefill, no fill-max control)', (t) async {
    await _open(t, balance: 500000);
    expect(_fieldText(t), isEmpty);
    // Only the Continue action; nothing that auto-fills the amount.
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('the typed amount is returned unchanged', (t) async {
    expect(await _open(t, typed: '120000'), 120000);
  });

  testWidgets('empty submit is rejected locally (nothing returned)', (t) async {
    await _open(t);
    await t.tap(find.text(vi.provWalletContinue));
    await t.pumpAndSettle();
    expect(find.byType(WithdrawSheet), findsOneWidget);
  });

  testWidgets('above the shown balance is rejected locally; the sheet stays open', (t) async {
    await _open(t, balance: 500000, typed: '600000');
    expect(find.byType(WithdrawSheet), findsOneWidget);
    expect(find.text(vi.provWalletWithdrawInvalidAmount), findsOneWidget);
  });
}
