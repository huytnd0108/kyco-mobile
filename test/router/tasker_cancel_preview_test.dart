// Release-i tasker cancel preview (kyco 4f36881d lib/tasker/tasker-cancel-assess.ts:81-181,
// app/api/v1/tasker/jobs/[id]/cancel-preview/route.ts, tasker/jobs/[id]/route.ts:71):
// JobCancelDialog shows the SERVER's numbers/text (no client math), through the
// real tasker job screen and as a widget. Fixtures: test/fixtures/release_i.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/app.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/locale_controller.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/features/tasker_job_detail/tasker_job_detail_screen.dart' show JobCancelDialog;

import '../wave_c_support.dart';

Map<String, dynamic> _fx(String n) =>
    jsonDecode(File('test/fixtures/release_i/$n').readAsStringSync()) as Map<String, dynamic>;
TaskerCancelPreview _pv(String n) => TaskerCancelPreview.tryParse(_fx(n))!;

Map<String, dynamic> _detail({Map<String, dynamic>? preview}) => {
      'job': {'id': 5, 'status': 'active', 'bookingId': 90},
      'booking': {
        'id': 90, 'status': 'CONFIRMED', 'totalVnd': 480000, 'paymentMethod': 'cash',
        'scheduledAt': '2026-10-10T09:00:00Z', 'addressLine': '45 Lê Lợi', 'district': 'Quận 1',
      },
      'service': {'name': 'Vệ sinh nhà', 'durationMinutes': 120},
      'customer': {'name': 'Ngọc Anh'},
      'hasCheckedIn': false,
      'hasCheckedOut': false,
      'thread': <Object>[],
      'cancelPreview': ?preview,
    };

Finder _k(String k) => find.byKey(ValueKey(k));

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _pickReason(WidgetTester t, String label) async {
  await t.tap(_k('job-cancel-reason'));
  await _settle(t);
  await t.tap(find.text(label).last);
  await _settle(t);
}

/// Opens [JobCancelDialog] and returns a getter for the popped value.
Future<({String code, String text})? Function()> _openDialog(WidgetTester t,
    {TaskerCancelPreview? preview, Future<TaskerCancelPreview?> Function()? load}) async {
  useTallView(t, w: 420, h: 1600);
  ({String code, String text})? out;
  await t.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('vi'),
    home: Builder(
      builder: (c) => TextButton(
        onPressed: () async => out = await showDialog<({String code, String text})>(
            context: c, builder: (_) => JobCancelDialog(preview: preview, loadPreview: load)),
        child: const Text('open'),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await _settle(t);
  return () => out;
}

void main() {
  group('model (4f36881d TaskerCancelPreview)', () {
    test('parses the fine + willBlock shape; there is no compensation field', () {
      final p = _pv('cancel_preview_fine_willblock.json');
      expect(p.canCancel, isTrue);
      expect(p.fineVnd, 100000);
      expect((p.willBlock, p.consequence, p.blockedUntil), (true, 'suspend_7d', '2026-10-18T09:30:00.000Z'));
      expect(p.reasonLabel, contains('100.000'));
      expect(p.strikeLabel, contains('7 ngày'));
      expect(p.reasons.map((r) => r.code), ['sick', 'flood', 'other']);
      expect(p.repooled, isTrue);
      expect(_fx('cancel_preview_fine_willblock.json').containsKey('compensationVnd'), isFalse);
    });

    test('refusal: blockedReason + empty labels', () {
      final p = _pv('cancel_preview_too_late.json');
      expect((p.canCancel, p.blockedCode, p.fineVnd, p.willBlock), (false, 'TOO_LATE_1H', 0, false));
      expect(p.blockedLabel, contains('1 giờ'));
      expect((p.strikeLabel, p.reasonLabel), (null, null));
    });

    test('tolerant: junk -> null; job detail without the key -> null preview', () {
      expect(TaskerCancelPreview.tryParse(null), isNull);
      expect(TaskerCancelPreview.tryParse({'fineVnd': 1}), isNull);
      expect(TaskerJobDetail.fromJson(_detail()).cancelPreview, isNull);
      expect(TaskerJobDetail.fromJson(_detail(preview: _fx('cancel_preview_free.json'))).cancelPreview!.canCancel, isTrue);
    });
  });

  group('dialog', () {
    testWidgets('willBlock + fine: server fine/reason/strike, prominent warning with VN-time until, server reasons',
        (t) async {
      final out = await _openDialog(t, preview: _pv('cancel_preview_fine_willblock.json'));
      expect(t.widget<Text>(_k('job-cancel-fine')).data, vi.cancelPreviewFineLine('100.000₫'));
      expect(find.textContaining('bị phạt 100.000 ₫ trừ vào ví'), findsOneWidget);
      expect(find.text('Tài khoản sẽ bị khoá tạm 7 ngày do huỷ 5 job trong 30 ngày.'), findsOneWidget);
      expect(_k('job-cancel-will-block'), findsOneWidget);
      expect(find.text(vi.cancelPreviewWillBlockTitle), findsOneWidget);
      expect(find.text(vi.cancelPreviewConsequenceSuspend7d), findsOneWidget);
      // 2026-10-18T09:30Z is 16:30 in Vietnam, whatever the device zone.
      expect(t.widget<Text>(_k('job-cancel-until')).data, vi.cancelPreviewBlockedUntil('18/10/2026 16:30'));
      expect(find.text(vi.provJdCancelWarning), findsNothing, reason: 'the generic policy line gives way to the numbers');

      // The server's reason list IS the picker (codes + labels), not the local five.
      await t.tap(_k('job-cancel-reason'));
      await _settle(t);
      expect(find.text('Ngập nước, không đến được'), findsWidgets);
      expect(find.text(vi.moneyCancelReasonSafety), findsNothing);
      await t.tap(find.text('Ngập nước, không đến được').last);
      await _settle(t);
      await t.enterText(_k('job-cancel-note'), ' nước ');
      await t.tap(_k('job-cancel-submit'));
      await _settle(t);
      expect(out(), (code: 'flood', text: 'nước'));
    });

    testWidgets('permanent consequence, no blockedUntil line', (t) async {
      await _openDialog(t, preview: _pv('cancel_preview_permanent.json'));
      expect(find.text(vi.cancelPreviewConsequencePermanent), findsOneWidget);
      expect(_k('job-cancel-until'), findsNothing);
      expect(t.widget<Text>(_k('job-cancel-fine')).data, vi.cancelPreviewFineLine('0₫'));
    });

    testWidgets('free cancel: server text, no warning box', (t) async {
      await _openDialog(t, preview: _pv('cancel_preview_free.json'));
      expect(find.text('Huỷ trước giờ hẹn từ 4 giờ trở lên: không bị phạt tiền.'), findsOneWidget);
      expect(find.text('Huỷ liên tiếp: 1/3. Điểm kỷ luật +1.'), findsOneWidget);
      expect(_k('job-cancel-will-block'), findsNothing);
    });

    testWidgets('canCancel false: the server refusal is shown and confirm is disabled', (t) async {
      await _openDialog(t, preview: _pv('cancel_preview_too_late.json'));
      expect(find.textContaining('Không thể huỷ trong vòng 1 giờ'), findsOneWidget);
      expect(_k('job-cancel-fine'), findsNothing);
      expect(_k('job-cancel-reason'), findsNothing);
      expect(t.widget<FilledButton>(_k('job-cancel-submit')).onPressed, isNull);
    });

    testWidgets('preview without server reasons falls back to the local tasker codes', (t) async {
      final p = TaskerCancelPreview.tryParse({..._fx('cancel_preview_free.json'), 'reasons': <Object>[]})!;
      final out = await _openDialog(t, preview: p);
      await _pickReason(t, vi.moneyCancelReasonSick);
      await t.tap(_k('job-cancel-submit'));
      await _settle(t);
      expect(out(), (code: 'sick', text: ''));
    });

    testWidgets('loader returns the preview (spinner first, confirm disabled meanwhile)', (t) async {
      final gate = Completer<TaskerCancelPreview?>();
      await _openDialog(t, load: () => gate.future);
      expect(_k('job-cancel-loading'), findsOneWidget);
      expect(t.widget<FilledButton>(_k('job-cancel-submit')).onPressed, isNull);
      gate.complete(_pv('cancel_preview_fine_willblock.json'));
      await _settle(t);
      expect(_k('job-cancel-loading'), findsNothing);
      expect(_k('job-cancel-will-block'), findsOneWidget);
    });

    testWidgets('404 (older backend): the current dialog, local codes, no numbers', (t) async {
      final out = await _openDialog(t, load: () async => null);
      expect(find.text(vi.provJdCancelWarning), findsOneWidget);
      expect(_k('job-cancel-fine'), findsNothing);
      expect(_k('job-cancel-load-failed'), findsNothing);
      await _pickReason(t, vi.moneyCancelReasonSafety);
      await t.tap(_k('job-cancel-submit'));
      await _settle(t);
      expect(out(), (code: 'safety', text: ''));
    });

    testWidgets('embedded preview + loader: embedded shown with "đang cập nhật", confirm disabled until fresh',
        (t) async {
      final gate = Completer<TaskerCancelPreview?>();
      final out = await _openDialog(t, preview: _pv('cancel_preview_free.json'), load: () => gate.future);
      expect(_k('job-cancel-refreshing'), findsOneWidget);
      expect(find.text('Huỷ liên tiếp: 1/3. Điểm kỷ luật +1.'), findsOneWidget);
      await _pickReason(t, 'Tôi bị ốm / có việc đột xuất');
      expect(t.widget<FilledButton>(_k('job-cancel-submit')).onPressed, isNull);
      gate.complete(_pv('cancel_preview_fine_willblock.json'));
      await _settle(t);
      expect(_k('job-cancel-refreshing'), findsNothing);
      expect(_k('job-cancel-will-block'), findsOneWidget, reason: 'the fresh numbers replace the stale ones');
      expect(find.text('Huỷ liên tiếp: 1/3. Điểm kỷ luật +1.'), findsNothing);
      await _pickReason(t, 'Ngập nước, không đến được');
      await t.tap(_k('job-cancel-submit'));
      await _settle(t);
      expect(out(), (code: 'flood', text: ''));
    });

    testWidgets('embedded preview + loader 404: embedded kept, confirm enabled', (t) async {
      final out = await _openDialog(t, preview: _pv('cancel_preview_free.json'), load: () async => null);
      expect(_k('job-cancel-refreshing'), findsNothing);
      expect(find.text('Huỷ liên tiếp: 1/3. Điểm kỷ luật +1.'), findsOneWidget);
      await _pickReason(t, 'Tôi bị ốm / có việc đột xuất');
      await t.tap(_k('job-cancel-submit'));
      await _settle(t);
      expect(out(), (code: 'sick', text: ''));
    });

    testWidgets('embedded preview + transient failure: embedded + retry note, confirm disabled until retry works',
        (t) async {
      var n = 0;
      await _openDialog(t, preview: _pv('cancel_preview_free.json'), load: () async {
        if (n++ == 0) throw StateError('offline');
        return _pv('cancel_preview_permanent.json');
      });
      expect(_k('job-cancel-load-failed'), findsOneWidget);
      expect(find.text('Huỷ liên tiếp: 1/3. Điểm kỷ luật +1.'), findsOneWidget);
      await _pickReason(t, 'Tôi bị ốm / có việc đột xuất');
      expect(t.widget<FilledButton>(_k('job-cancel-submit')).onPressed, isNull);
      await t.tap(_k('job-cancel-reload'));
      await _settle(t);
      expect(_k('job-cancel-load-failed'), findsNothing);
      expect(find.text(vi.cancelPreviewConsequencePermanent), findsOneWidget);
      await _pickReason(t, 'Tôi bị ốm / có việc đột xuất');
      expect(t.widget<FilledButton>(_k('job-cancel-submit')).onPressed, isNotNull);
    });

    testWidgets('transient load failure: plain dialog + a retry that loads the preview', (t) async {
      var n = 0;
      await _openDialog(t, load: () async {
        if (n++ == 0) throw StateError('offline');
        return _pv('cancel_preview_permanent.json');
      });
      expect(_k('job-cancel-load-failed'), findsOneWidget);
      expect(find.text(vi.provJdCancelWarning), findsOneWidget);
      await t.tap(_k('job-cancel-reload'));
      await _settle(t);
      expect(_k('job-cancel-load-failed'), findsNothing);
      expect(find.text(vi.cancelPreviewConsequencePermanent), findsOneWidget);
    });
  });

  group('through the job screen (ledger + request unchanged)', () {
    Future<Backend> openCancel(WidgetTester t, Backend b) async {
      useTallView(t, w: 420, h: 2600);
      final h = await harness(backend: b, auth: signedInAs('tasker'), extra: [
        idempotencyLedgerProvider.overrideWithValue(IdempotencyLedger(store: MemoryPendingKeyStore())),
      ]);
      final c = ProviderContainer(overrides: h.overrides);
      addTearDown(c.dispose);
      await c.read(localeControllerProvider.notifier).set(const Locale('vi'));
      await t.pumpWidget(UncontrolledProviderScope(container: c, child: const KycoApp()));
      await t.pumpAndSettle();
      final router = c.read(routerProvider);
      router.go('/p/jobs');
      await t.pumpAndSettle();
      unawaited(router.push<Object?>('/p/jobs/5'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(vi.provJdCancelTitle).first);
      await t.tap(find.text(vi.provJdCancelTitle).first);
      await t.pumpAndSettle();
      return b;
    }

    testWidgets('detail carries cancelPreview: still re-fetched on open; the fresh one wins, cancel posts once',
        (t) async {
      final b = Backend()
        ..on('GET /tasker/jobs/5', (_) => Backend.ok(_detail(preview: _fx('cancel_preview_free.json'))))
        ..on('GET /tasker/jobs/5/cancel-preview', (_) => Backend.ok(_fx('cancel_preview_fine_willblock.json')))
        ..on('POST /tasker/jobs/5/cancel', (_) => Backend.ok({'fineVnd': 100000}, status: 201))
        ..on('GET /tasker/jobs', (_) => Backend.ok(<Object>[]));
      await openCancel(t, b);
      expect(b.calls('GET /tasker/jobs/5/cancel-preview'), hasLength(1));
      expect(_k('job-cancel-will-block'), findsOneWidget);
      await _pickReason(t, 'Ngập nước, không đến được');
      await t.tap(_k('job-cancel-submit'));
      await t.pumpAndSettle();
      final post = b.calls('POST /tasker/jobs/5/cancel').single;
      expect(post.data, {'reasonCode': 'flood'});
      expect(post.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    });

    testWidgets('no cancelPreview in the detail: GET .../cancel-preview is used', (t) async {
      final b = Backend()
        ..on('GET /tasker/jobs/5', (_) => Backend.ok(_detail()))
        ..on('GET /tasker/jobs/5/cancel-preview', (_) => Backend.ok(_fx('cancel_preview_too_late.json')));
      await openCancel(t, b);
      expect(b.calls('GET /tasker/jobs/5/cancel-preview'), hasLength(1));
      expect(find.textContaining('Không thể huỷ trong vòng 1 giờ'), findsOneWidget);
      expect(t.widget<FilledButton>(_k('job-cancel-submit')).onPressed, isNull);
      expect(b.calls('POST /tasker/jobs/5/cancel'), isEmpty);
    });

    testWidgets('cancel-preview 404: the current dialog still cancels with a local code', (t) async {
      final b = Backend()
        ..on('GET /tasker/jobs/5', (_) => Backend.ok(_detail()))
        ..on('POST /tasker/jobs/5/cancel', (_) => Backend.ok({}, status: 201));
      await openCancel(t, b); // GET .../cancel-preview is unregistered -> 404
      expect(b.calls('GET /tasker/jobs/5/cancel-preview'), hasLength(1));
      expect(find.text(vi.provJdCancelWarning), findsOneWidget);
      await _pickReason(t, vi.moneyCancelReasonSick);
      await t.tap(_k('job-cancel-submit'));
      await t.pumpAndSettle();
      expect(b.calls('POST /tasker/jobs/5/cancel').single.data, {'reasonCode': 'sick'});
    });

    testWidgets('detail preview + cancel-preview 404: the embedded preview is used', (t) async {
      final b = Backend()
        ..on('GET /tasker/jobs/5', (_) => Backend.ok(_detail(preview: _fx('cancel_preview_free.json'))))
        ..on('POST /tasker/jobs/5/cancel', (_) => Backend.ok({}, status: 201));
      await openCancel(t, b);
      expect(b.calls('GET /tasker/jobs/5/cancel-preview'), hasLength(1));
      expect(find.text('Huỷ liên tiếp: 1/3. Điểm kỷ luật +1.'), findsOneWidget);
      await _pickReason(t, 'Tôi bị ốm / có việc đột xuất');
      await t.tap(_k('job-cancel-submit'));
      await t.pumpAndSettle();
      expect(b.calls('POST /tasker/jobs/5/cancel').single.data, {'reasonCode': 'sick'});
    });
  });
}
