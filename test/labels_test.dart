// UX-M54/M55/M56: every backend enum shown to users maps to a localized label;
// an unknown value falls back to the neutral "Khac"/"Other" and NEVER prints the
// raw server string. Period keys are formatted, never shown as '2026-W41'.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kyco_mobile/core/labels.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

void main() {
  final locales = {
    'vi': lookupAppLocalizations(const Locale('vi')),
    'en': lookupAppLocalizations(const Locale('en')),
  };
  const bogus = 'zz_new_backend_value';

  final enums = <String, ({String Function(AppLocalizations, String?) fn, List<String> known})>{
    'bookingStatus': (fn: bookingStatusLabel, known: const [
      'PENDING', 'CONFIRMED', 'EN_ROUTE', 'ARRIVED', 'CHECKED_IN', 'ACTIVE',
      'AWAITING_CUSTOMER_CONFIRMATION', 'AWAITING_PAYMENT', 'AWAITING_CASH_CONFIRM',
      'COMPLETED', 'CLOSED', 'SETTLED', 'IN_DISPUTE', 'CANCELLED', 'BAD_DEBT',
    ]),
    'paymentMethod': (fn: paymentMethodLabel, known: const ['cash', 'vnpay', 'momo', 'zalopay', 'bank_transfer']),
    'timeline': (fn: timelineLabel, known: const [
      'created', 'scheduled', 'claimed', 'started', 'finished', 'completed',
      'customerConfirmed', 'cashReceived', 'settled',
    ]),
    'cancelReason': (fn: cancelReasonLabel, known: const [
      'plan_changed', 'wrong_time', 'price', 'found_other', 'other', 'sick', 'address_unreach', 'wrong_scope', 'safety',
    ]),
    'fineKind': (fn: fineKindLabel, known: const [
      'cancel_late', 'late', 'extra_charge', 'private_client', 'bad_attitude', 'fraud', 'damage',
    ]),
    'fineStatus': (fn: fineStatusLabel, known: const ['pending', 'charged', 'refunded']),
    'appealStatus': (fn: appealStatusLabel, known: const ['pending', 'accepted', 'rejected']),
    'referralStatus': (fn: referralStatusLabel, known: const ['pending_kyc', 'active', 'completed']),
    'subFrequency': (fn: subscriptionFrequencyLabel, known: const ['weekly', 'biweekly', 'monthly']),
    'subStatus': (fn: subscriptionStatusLabel, known: const ['active', 'paused', 'pending', 'cancelled', 'expired', 'completed']),
    'role': (fn: accountRoleLabel, known: const ['customer', 'tasker', 'pending_tasker', 'admin', 'staff']),
    'jobStatus': (fn: jobStatusLabel, known: const ['pending', 'active', 'closed']),
    'payoutRequest': (fn: payoutRequestStatusLabel, known: const ['paid', 'rejected', 'pending']),
    'bonusKind': (fn: bonusKindLabel, known: const ['weekly_jobs', 'monthly_revenue', 'punctuality', 'rating', 'referral']),
  };

  for (final e in enums.entries) {
    for (final loc in locales.entries) {
      test('${e.key} [${loc.key}]: known values are localized, unknown -> Other, never raw', () {
        final l = loc.value;
        for (final v in e.value.known) {
          final out = e.value.fn(l, v);
          expect(out, isNotEmpty, reason: v);
          // A known value is never echoed back as its raw code (brand names
          // like VNPay/MoMo/ZaloPay are the only intentional same-text labels).
          if (!{'vnpay', 'momo', 'zalopay'}.contains(v)) {
            expect(out, isNot(v), reason: v);
            expect(out, isNot(contains('_')), reason: v);
          }
        }
        expect(e.value.fn(l, bogus), isNot(contains(bogus)));
        if (e.key == 'cancelReason') {
          expect(e.value.fn(l, bogus), l.moneyCancelReasonOther);
        } else {
          expect(e.value.fn(l, bogus), l.labelOther);
        }
        expect(e.value.fn(l, null), '—');
        expect(e.value.fn(l, ''), '—');
      });
    }
  }

  test('labelOther is "Khác" / "Other"', () {
    expect(locales['vi']!.labelOther, 'Khác');
    expect(locales['en']!.labelOther, 'Other');
  });

  test('matching is case-insensitive for lower-case enums', () {
    final l = locales['en']!;
    expect(fineStatusLabel(l, 'CHARGED'), fineStatusLabel(l, 'charged'));
    expect(bookingStatusLabel(l, 'settled'), bookingStatusLabel(l, 'SETTLED'));
  });

  test('periodLabel formats week and month keys, never the raw key', () {
    final vi = locales['vi']!;
    final en = locales['en']!;
    expect(periodLabel(vi, '2026-W41'), 'Tuần 41, 2026');
    expect(periodLabel(vi, '2026-10'), 'Tháng 10/2026');
    expect(periodLabel(en, '2026-W41'), 'Week 41, 2026');
    expect(periodLabel(en, '2026-10'), 'Month 10/2026');
    expect(periodLabel(vi, 'garbage'), 'Khác');
    expect(periodLabel(vi, null), 'Khác');
  });

  test('ratingOutOf announces "4,5 trên 5 sao" (vi decimal comma)', () {
    expect(locales['vi']!.ratingOutOf(4.5), '4,5 trên 5 sao');
    expect(locales['en']!.ratingOutOf(4.5), '4.5 out of 5 stars');
  });
}
