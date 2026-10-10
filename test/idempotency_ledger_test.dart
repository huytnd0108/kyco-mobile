import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/api/idempotency_ledger.dart';
import 'package:kyco_mobile/core/api/problem.dart';

final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

Future<void> _attempt(IdempotencyLedger l, String fp, List<String> seen, ApiException? fail) async {
  try {
    await l.run(fp, (k) async {
      seen.add(k);
      if (fail != null) throw fail;
      return k;
    });
  } on ApiException catch (_) {}
}

void main() {
  test('same action retried after lost/ambiguous responses reuses ONE key', () async {
    final l = IdempotencyLedger();
    final seen = <String>[];
    await _attempt(l, 'payout:100000', seen, ApiException('network', 'timeout'));
    await _attempt(l, 'payout:100000', seen, ApiException('INTERNAL', 'x', status: 502));
    await _attempt(l, 'payout:100000', seen, ApiException('CONFLICT', 'in progress', status: 409));
    await _attempt(l, 'payout:100000', seen, ApiException('RATE_LIMIT', 'slow', status: 429));
    await _attempt(l, 'payout:100000', seen, null); // finally succeeds
    expect(seen, hasLength(5));
    expect(seen.toSet(), hasLength(1));
    expect(_uuid.hasMatch(seen.first), isTrue);
  });

  test('success or a definitive 4xx ends the action → next confirmation gets a new key', () async {
    final l = IdempotencyLedger();
    final seen = <String>[];
    await _attempt(l, 'payout:100000', seen, null);
    await _attempt(l, 'payout:100000', seen, null);
    expect(seen.toSet(), hasLength(2));

    final seen2 = <String>[];
    await _attempt(l, 'job-cancel:1:x', seen2, ApiException('VALIDATION', 'no', status: 422));
    await _attempt(l, 'job-cancel:1:x', seen2, ApiException('STEP_UP_REQUIRED', 'su', status: 403));
    expect(seen2.toSet(), hasLength(2));
  });

  test('different actions never share a key', () async {
    final l = IdempotencyLedger();
    expect(await l.keyFor('payout:100000'), isNot(await l.keyFor('payout:200000')));
    expect(await l.keyFor('job-cancel:1:${IdempotencyLedger.textTag('a')}'),
        isNot(await l.keyFor('job-cancel:1:${IdempotencyLedger.textTag('b')}')));
    expect(await l.keyFor('job-cancel:1:t'), isNot(await l.keyFor('job-cancel:2:t')));
  });

  test('pending key survives an app restart (persisted store), cleared after success', () async {
    final store = MemoryPendingKeyStore();
    final before = IdempotencyLedger(store: store);
    final seen = <String>[];
    await _attempt(before, 'payout:300000', seen, ApiException('network', 'killed'));
    expect(store.value, isNotNull);
    expect(store.value, contains(seen.single));

    final after = IdempotencyLedger(store: store); // "restarted app"
    await _attempt(after, 'payout:300000', seen, null);
    expect(seen.toSet(), hasLength(1), reason: 'retry after restart replays the same key');
    expect(store.value, isNull, reason: 'nothing pending once the payout is done');
  });

  test('a stale pending key expires after the TTL', () async {
    var now = DateTime(2026, 10, 10, 9);
    final l = IdempotencyLedger(ttl: const Duration(hours: 1), now: () => now);
    final k = await l.keyFor('payout:5');
    now = now.add(const Duration(hours: 2));
    expect(await l.keyFor('payout:5'), isNot(k));
  });

  test('keepAfter: only outcomes where the server may have executed keep the key', () {
    bool keep(String code, int? s) => IdempotencyLedger.keepAfter(ApiException(code, 'm', status: s));
    expect(keep('network', null), isTrue);
    expect(keep('INTERNAL', 500), isTrue);
    expect(keep('CONFLICT', 409), isTrue);
    expect(keep('RATE_LIMIT', 429), isTrue);
    expect(keep('VALIDATION', 422), isFalse);
    expect(keep('STEP_UP_REQUIRED', 403), isFalse);
    expect(keep('NOT_FOUND', 404), isFalse);
    expect(keep('IDEMPOTENCY_STALE', 409), isFalse); // definitive, unlike IN_PROGRESS
    expect(keep('IDEMPOTENCY_IN_PROGRESS', 409), isTrue);
  });

  test('textTag is stable across runs (FNV-1a) and hides the text', () {
    expect(IdempotencyLedger.textTag('Khách hủy'), IdempotencyLedger.textTag(' Khách hủy '));
    expect(IdempotencyLedger.textTag('a'), isNot(IdempotencyLedger.textTag('b')));
    expect(IdempotencyLedger.textTag('secret reason'), isNot(contains('secret')));
  });

  test('S3b: concurrent runs of one action coalesce → ONE request, ONE key, shared outcome', () async {
    final l = IdempotencyLedger();
    var calls = 0;
    final keys = <String>[];
    Future<String> call(String k) async {
      calls++;
      keys.add(k);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 'payout-1';
    }
    final r = await Future.wait([l.run('payout:100000', call), l.run('payout:100000', call)]);
    expect(calls, 1);
    expect(r, ['payout-1', 'payout-1']);
    // A later, separate confirmation is a new action with a new key.
    await l.run('payout:100000', call);
    expect(keys.toSet(), hasLength(2));
  });

  test('a run only forgets the key it used', () async {
    final l = IdempotencyLedger();
    final k1 = await l.keyFor('payout:7');
    // Simulate the key being rotated by an expired TTL / other action meanwhile.
    final out = await l.run('payout:7', (k) async => k);
    expect(out, k1);
    expect(await l.keyFor('payout:7'), isNot(k1));
  });
}
