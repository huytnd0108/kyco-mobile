// Small pure-logic OCD fixes: placeholder names, resend countdown, fine kinds,
// ICU plural, chronological timeline, one cancel spelling.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/labels.dart';
import 'package:kyco_mobile/core/models.dart';
import 'package:kyco_mobile/core/person_name.dart';
import 'package:kyco_mobile/core/ui/resend_cooldown.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

void main() {
  final vi = lookupAppLocalizations(const Locale('vi'));
  final en = lookupAppLocalizations(const Locale('en'));

  group('OCD-019 tasker display name', () {
    test('placeholders are never shown as a person name', () {
      for (final n in ['Tasker #1', 'tasker #42', 'Tasker 7', 'TASKER#9', 'CTV #3', 'Người làm #5', 'Cộng tác viên #5', '', '  ', null]) {
        expect(isPlaceholderPersonName(n), isTrue, reason: '$n');
        expect(taskerDisplayName(vi, n), 'Cộng tác viên');
        expect(taskerDisplayName(en, n), 'Tasker');
      }
    });
    test('real names pass through (trimmed)', () {
      for (final n in ['Nguyễn Thị Lan', ' Lan ', 'Tasker Minh', 'Tasker #1 Lan']) {
        expect(isPlaceholderPersonName(n), isFalse, reason: n);
        expect(taskerDisplayName(vi, n), n.trim());
      }
    });
    test('one term in the VI strings (Cộng tác viên, kept by decision): no CTV / đối tác / Người làm left', () {
      final arb = File('lib/l10n/app_vi.arb').readAsStringSync().toLowerCase();
      for (final w in ['ctv', 'người làm', 'đối tác']) {
        expect(arb.contains(w), isFalse, reason: 'VI ARB still says "$w"');
      }
      expect(vi.roleTasker, 'Cộng tác viên');
      expect(en.roleTasker, 'Tasker');
    });
  });

  test('OCD-012 resend label: seconds for short waits, whole minutes for a long lockout', () {
    expect(resendInText(vi, 45), vi.otpResendIn(45));
    expect(resendInText(vi, 119), vi.otpResendIn(119));
    expect(resendInText(vi, 786), vi.otpResendInMinutes(14));
    expect(resendInText(vi, 786), isNot(contains('786')));
    expect(resendInText(en, 786), 'Resend code in about 14 min');
  });

  test('OCD-063 late_arrival fines get the "late" label, not "Other"', () {
    expect(fineKindLabel(vi, 'late_arrival'), vi.fineKindLate);
    expect(fineKindLabel(vi, 'late_arrival'), isNot(vi.labelOther));
  });

  test('OCD-056 English review count is plural-aware', () {
    expect(en.reviewCount(1), '1 review');
    expect(en.reviewCount(3), '3 reviews');
    expect(vi.reviewCount(1), '1 đánh giá');
  });

  test('OCD-045 booking timeline is chronological', () {
    final b = BookingDetail.fromPage({
      'booking': {
        'id': 1, 'status': 'CONFIRMED',
        'createdAt': '2026-10-10T08:00:00Z',
        'scheduledAt': '2026-10-10T14:49:00Z',
      },
      'job': {'id': 2, 'claimedAt': '2026-10-10T14:38:00Z'},
    });
    expect([for (final e in b.timeline) e.kind], ['created', 'claimed', 'scheduled']);
  });

  test('OCD-040/046 one spelling of cancel (hủy) in both languages of the VI ARB', () {
    final arb = File('lib/l10n/app_vi.arb').readAsStringSync();
    expect(arb.contains('huỷ') || arb.contains('Huỷ'), isFalse);
  });
}
