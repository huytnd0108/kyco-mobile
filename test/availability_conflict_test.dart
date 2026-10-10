// OCD-042: the weekly-availability conflict is a PRE-save confirmation. The
// server (saveWeeklyAvailabilityCore) writes nothing on a conflict without
// force; the app must send force=true only after the tasker confirms.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/features/tasker_availability/tasker_availability_screen.dart';
import 'package:kyco_mobile/features/tasker_jobs/tasker_jobs_providers.dart';

import 'wave_c_support.dart';

Backend _backend() {
  final b = Backend();
  b.on('GET /tasker/availability', (_) => Backend.ok({
        'weekly': {
          '1': [
            {'start': 480, 'end': 720}
          ]
        },
        'dates': <Object>[],
      }));
  b.on('GET /tasker/jobs', (_) => Backend.ok([
        {
          'jobId': 118,
          'jobStatus': 'active',
          'serviceName': 'Vệ sinh nhà theo giờ',
          'scheduledAt': '2026-10-12T02:00:00Z',
        }
      ]));
  b.on('PUT /tasker/availability/weekly', (o) {
    final force = (o.data as Map)['force'] == true;
    return Backend.ok(force
        ? {'saved': true, 'conflicts': <int>[]}
        : {'saved': false, 'conflicts': [118, 999]});
  });
  return b;
}

Future<void> _openDaySheetAndSave(WidgetTester t) async {
  await t.tap(find.text(vi.provAvailWeekdayShort1));
  await t.pumpAndSettle();
  await t.tap(find.text(vi.provAvailAddSlot));
  await t.pumpAndSettle();
  await t.tap(find.text(vi.provAvailSave));
  // The editor shows a busy spinner while the conflict dialog is up, so settle by time.
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _pump(WidgetTester t, Backend b) async {
  useTallView(t, w: 420, h: 2000);
  final h = await harness(backend: b);
  await t.pumpWidget(appWith(h, const TaskerAvailabilityScreen()));
  await t.pumpAndSettle();
  // The assigned-jobs list is already loaded by the Jobs tab in the real app.
  final c = ProviderScope.containerOf(t.element(find.byType(TaskerAvailabilityScreen)));
  c.listen(assignedJobsControllerProvider, (_, _) {}); // keep it alive
  await t.pumpAndSettle();
}

void main() {
  testWidgets('conflict: one dry PUT (force=false), a readable dialog, nothing forced until confirmed',
      (t) async {
    final b = _backend();
    await _pump(t, b);
    await _openDaySheetAndSave(t);

    final puts = b.calls('PUT /tasker/availability/weekly').toList();
    expect(puts, hasLength(1));
    expect((puts.single.data as Map)['force'], false);
    // Dialog: service + VN time for the job we know, bare id only for the unknown one.
    expect(find.text(vi.provAvailConflictTitle), findsOneWidget);
    expect(find.textContaining('Vệ sinh nhà theo giờ (12/10'), findsOneWidget);
    expect(find.textContaining('#999'), findsOneWidget);
    expect(find.textContaining('#118'), findsNothing);
    expect(find.text(vi.provAvailSaved), findsNothing);
  });

  testWidgets('Cancel in the dialog sends no second request; Save anyway sends force=true', (t) async {
    final b = _backend();
    await _pump(t, b);
    await _openDaySheetAndSave(t);
    await t.tap(find.text(vi.provAvailCancel));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(b.calls('PUT /tasker/availability/weekly'), hasLength(1), reason: 'nothing forced on cancel');
    expect(find.text(vi.provAvailSaved), findsNothing);

    await _openDaySheetAndSave(t);
    expect(b.calls('PUT /tasker/availability/weekly'), hasLength(2));
    await t.tap(find.text(vi.provAvailSaveAnyway));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    final puts = b.calls('PUT /tasker/availability/weekly').toList();
    expect(puts, hasLength(3));
    expect((puts.last.data as Map)['force'], true);
    expect(find.text(vi.provAvailSaved), findsOneWidget);
    await t.pump(const Duration(seconds: 6)); // let the snackbar timer finish
  });
}
