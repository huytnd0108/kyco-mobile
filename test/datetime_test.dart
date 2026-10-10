// UX-M57/M58/M59: one VN-time formatter. Fixed UTC+7, no DST, no tz database.
// The suite runs with TZ=UTC; these tests must also hold under any device zone
// because nothing here reads the device zone.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kyco_mobile/core/datetime.dart';

void main() {
  setUpAll(() async => initializeDateFormatting());

  group('parseInstant', () {
    test('Z / offset / Postgres short offset all resolve to the same instant', () {
      final z = parseInstant('2026-12-06T02:00:00Z')!;
      expect(z, DateTime.utc(2026, 12, 6, 2));
      expect(parseInstant('2026-12-06 02:00:00+00'), z);
      expect(parseInstant('2026-12-06T09:00:00+07:00'), z);
    });

    test('zone-less is VN wall-clock (the server reads checkout times as VN)', () {
      expect(parseInstant('2026-10-12T09:00:00'), DateTime.utc(2026, 10, 12, 2));
      expect(parseInstant('2026-10-12 09:00'), DateTime.utc(2026, 10, 12, 2));
    });

    test('garbage / empty / null -> null', () {
      expect(parseInstant(null), isNull);
      expect(parseInstant(''), isNull);
      expect(parseInstant('not a date'), isNull);
    });
  });

  group('day boundaries (VN = UTC+7)', () {
    test('16:59Z is still the same VN day, 17:00Z is the next one', () {
      final a = vnWall('2026-10-10T16:59:59Z')!;
      expect((a.year, a.month, a.day, a.hour, a.minute), (2026, 10, 10, 23, 59));
      final b = vnWall('2026-10-10T17:00:00Z')!;
      expect((b.year, b.month, b.day, b.hour, b.minute), (2026, 10, 11, 0, 0));
    });

    test('Dec 31 17:00Z rolls into Jan 1 of the next year', () {
      final a = vnWall('2026-12-31T16:59:59Z')!;
      expect((a.year, a.month, a.day), (2026, 12, 31));
      final b = vnWall('2026-12-31T17:00:00Z')!;
      expect((b.year, b.month, b.day, b.hour), (2027, 1, 1, 0));
    });

    test('formatted output follows the VN calendar day', () {
      expect(formatVnDate('2026-10-10T16:59:00Z', locale: 'vi'), '10/10/2026');
      expect(formatVnDate('2026-10-10T17:00:00Z', locale: 'vi'), '11/10/2026');
      expect(formatVnDate('2026-12-31T17:00:00Z', locale: 'vi'), '1/1/2027');
      expect(formatVnDateTime('2026-12-31T17:00:00Z', locale: 'vi'), '1/1/2027 00:00');
      expect(formatVnDateTime('2026-10-10T16:59:00Z', locale: 'vi'), '10/10/2026 23:59');
    });
  });

  group('locales', () {
    test('vi and en format the same VN wall-clock differently', () {
      expect(formatVnDate('2026-12-06 02:00:00+00', locale: 'vi'), '6/12/2026');
      expect(formatVnDate('2026-12-06 02:00:00+00', locale: 'en'), '12/6/2026');
      expect(formatVnTime('2026-12-06T02:00:00Z', locale: 'vi'), '09:00');
      expect(formatVnDateMedium('2026-12-06T02:00:00Z', locale: 'en'), 'Dec 6, 2026');
    });

    test('invalid input shows an em dash, never the raw string', () {
      expect(formatVnDate('2026-13-45', locale: 'vi'), '—');
      expect(formatVnDateTime('garbage', locale: 'en'), '—');
      expect(formatVnDate(null), '—');
    });

    test('formatVnDateKey renders a yyyy-MM-dd key as a localized date', () {
      expect(formatVnDateKey('2026-10-12', locale: 'en'), contains('2026'));
      expect(formatVnDateKey('2026-10-12', locale: 'en'), isNot(contains('2026-10-12')));
      expect(formatVnDateKey('nope', locale: 'vi'), '—');
    });
  });

  group('VN "today" / period boundaries', () {
    test('vnToday uses the VN date, not the device date', () {
      // 17:30Z on Oct 10 is already Oct 11 in Vietnam.
      expect(vnToday(DateTime.utc(2026, 10, 10, 17, 30)), DateTime(2026, 10, 11));
      expect(vnToday(DateTime.utc(2026, 10, 10, 16, 30)), DateTime(2026, 10, 10));
      expect(vnToday(DateTime.utc(2026, 12, 31, 17, 0)), DateTime(2027, 1, 1));
    });

    test('vnDateKey is yyyy-MM-dd', () {
      expect(vnDateKey(DateTime(2027, 1, 1)), '2027-01-01');
    });

    test('parsePeriodKey', () {
      expect(parsePeriodKey('2026-W41'), (isWeek: true, year: 2026, number: 41));
      expect(parsePeriodKey('2026-10'), (isWeek: false, year: 2026, number: 10));
      expect(parsePeriodKey('2026-13'), isNull);
      expect(parsePeriodKey('x'), isNull);
      expect(parsePeriodKey(null), isNull);
    });
  });
}
