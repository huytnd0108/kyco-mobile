import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// U4 — guest checkout draft contract. Locks the two invariants the booking
/// path depends on: (1) the draft survives a prefs round-trip with every field
/// intact, and (2) toCreateBody() is a cash-only, amount-free body with the
/// web's legacy column mapping (wardName→district, neighborhood→ward).
void main() {
  BookingDraft sampleDraft() => BookingDraft(
        serviceId: 101,
        serviceName: 'Vệ sinh nhà theo giờ',
        basePriceVnd: 480000,
        scheduledDate: '2026-09-20',
        scheduledTime: '09:30',
        wardCode: 26734,
        wardName: 'Phường Bến Thành',
        neighborhood: 'Khu phố 1',
        addressLine: '12 Lê Lợi',
        notes: 'Gọi trước khi đến',
      );

  test('toJson/fromJson round-trips every field including idempotencyKey', () {
    final d = sampleDraft();
    final back = BookingDraft.fromJson(d.toJson());

    expect(back.serviceId, d.serviceId);
    expect(back.serviceName, d.serviceName);
    expect(back.basePriceVnd, d.basePriceVnd);
    expect(back.scheduledDate, d.scheduledDate);
    expect(back.scheduledTime, d.scheduledTime);
    expect(back.wardCode, d.wardCode);
    expect(back.wardName, d.wardName);
    expect(back.neighborhood, d.neighborhood);
    expect(back.addressLine, d.addressLine);
    expect(back.notes, d.notes);
    // The idempotency key is minted once and must be stable across restore.
    expect(back.idempotencyKey, d.idempotencyKey);
  });

  test('DraftStore persists and restores a draft through SharedPreferences', () async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final store = DraftStore(prefs);

    expect(store.read(101), isNull);

    final d = sampleDraft();
    await store.save(d);

    final restored = store.read(101);
    expect(restored, isNotNull);
    expect(restored!.wardName, 'Phường Bến Thành');
    expect(restored.neighborhood, 'Khu phố 1');
    expect(restored.addressLine, '12 Lê Lợi');
    expect(restored.idempotencyKey, d.idempotencyKey);

    await store.clear(101);
    expect(store.read(101), isNull);
  });

  test('toCreateBody maps wardName→district and neighborhood→ward', () {
    final body = sampleDraft().toCreateBody();
    expect(body['district'], 'Phường Bến Thành'); // wardName → district (legacy)
    expect(body['ward'], 'Khu phố 1'); // neighborhood → ward
    expect(body['addressLine'], '12 Lê Lợi');
    expect(body['scheduledAt'], '2026-09-20T09:30:00');
    expect(body['serviceId'], 101);
    expect(body['idempotencyKey'], isNotNull);
    expect((body['idempotencyKey'] as String).isNotEmpty, isTrue);
  });

  test('toCreateBody is cash-only and NEVER carries an amount key', () {
    final body = sampleDraft().toCreateBody();
    expect(body['paymentMethod'], 'cash');
    for (final forbidden in const ['totalVnd', 'amountVnd', 'price', 'total', 'amount']) {
      expect(body.containsKey(forbidden), isFalse, reason: 'body must not contain "$forbidden"');
    }
  });

  test('empty neighborhood maps to an empty ward, never null', () {
    final body = BookingDraft(
      serviceId: 5,
      serviceName: 'x',
      basePriceVnd: 1000,
      wardName: 'Phường X',
    ).toCreateBody();
    expect(body['ward'], '');
    expect(body.containsKey('amount'), isFalse);
    expect(body['paymentMethod'], 'cash');
  });
}
