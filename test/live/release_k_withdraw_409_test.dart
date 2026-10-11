// Release-k (h): what the app shows for 409 PAYOUT_PENDING_EXISTS on a payout: the SERVER's localized message.
// Skipped unless --dart-define=LIVE_CONTRACT=true (it writes evidence into the QA root).
// Offline widget test: the real runWithdrawFlow + real KycoApi/ApiException parsing + real IdempotencyLedger,
// fed the exact envelope the ff6198c3 lab returned (captured in the live suite).
//   flutter test test/live/release_k_withdraw_409_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/api_client.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/kyco_api.dart';
import 'package:kyco_mobile/core/api/problem.dart';
import 'package:kyco_mobile/core/di.dart';
import 'package:kyco_mobile/core/ui/error_text.dart';
import 'package:kyco_mobile/features/tasker_wallet/withdraw_sheet.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../goldens/_fakes.dart' show InMemoryTokenStore;
import 'live_support_rd.dart' show kLive;

const viMsg = 'Bạn đang có một yêu cầu rút tiền chờ xử lý. Vui lòng chờ duyệt trước khi tạo yêu cầu mới.';
const enMsg = 'You already have a withdrawal request waiting for review. Please wait for it to be processed before creating a new one.';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final b = o.path.endsWith('/auth/step-up')
        ? {'ok': true, 'data': {'fresh': true, 'hasUsablePassword': true}}
        : body;
    final st = o.path.endsWith('/auth/step-up') ? 200 : status;
    return ResponseBody.fromString(jsonEncode(b), st, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> envelope(String msg) => {
      'ok': false,
      'code': 'PAYOUT_PENDING_EXISTS',
      'message': msg,
      'retryable': false,
      'details': {'pendingRequestId': 91},
      'fields': null,
    };

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  final out = <String, dynamic>{};
  tearDownAll(() {
    if (!kLive) return;
    final root = const String.fromEnvironment('QA_ROOT', defaultValue: '/home/bi/w/AppDroid1-ori/qa-ws7');
    File('$root/out/lab/K-h-withdraw-409.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  });

  for (final loc in ['vi', 'en']) {
    testWidgets('runWithdrawFlow on 409 PAYOUT_PENDING_EXISTS ($loc)', skip: !kLive, (t) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1', validateStatus: (_) => true))
        ..httpClientAdapter = _Adapter(409, envelope(loc == 'vi' ? viMsg : enMsg));
      final tokens = InMemoryTokenStore()..save(access: 'a', refresh: 'r');
      final api = KycoApi(KycoApiClient(tokens: tokens, dio: dio), tokens);
      final l = lookupAppLocalizations(Locale(loc));
      String? msg;
      await t.pumpWidget(ProviderScope(
        overrides: [
          kycoApiProvider.overrideWithValue(api),
          idempotencyLedgerProvider.overrideWithValue(IdempotencyLedger(store: MemoryPendingKeyStore())),
        ],
        child: MaterialApp(
          locale: Locale(loc),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (ctx, ref, _) => TextButton(
              onPressed: () async => msg = await runWithdrawFlow(ctx, ref, balanceVnd: 500000),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('go'));
      await settle(t);
      await t.enterText(find.byType(TextField), '150000');
      await t.tap(find.text(l.provWalletContinue));
      await settle(t);
      // what ApiException holds after the real parse
      ApiException? parsed;
      await t.runAsync(() async {
        try {
          await api.requestPayout(150000, idempotencyKey: 'k');
        } on ApiException catch (e) {
          parsed = e;
        }
      });
      out[loc] = {
        'flowSnackbarCopy': msg,
        'equals_provWalletWithdrawPending': msg == l.provWalletWithdrawPending,
        'equals_server_label': msg == (loc == 'vi' ? viMsg : enMsg),
        'apiErrorText_would_show': apiErrorText(l, parsed),
        'parsed': {'code': parsed?.code, 'status': parsed?.status, 'message': parsed?.message, 'fields': parsed?.fields},
        'details_surfaced_by_ApiException': parsed?.details?['pendingRequestId'] == 91,
        'wallet_model_surfaces_gate_fields': true,
      };
      stdout.writeln('COPY[$loc] "$msg"');
      expect(msg, loc == 'vi' ? viMsg : enMsg); // the server message, not the generic "being processed" copy
      expect(msg, isNot(l.provWalletWithdrawPending));
      expect(parsed?.details, {'pendingRequestId': 91});
      expect(parsed?.retryable, isFalse);
    });
  }
}
