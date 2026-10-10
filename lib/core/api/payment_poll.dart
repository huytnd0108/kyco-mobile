import '../models/booking.dart';
import 'problem.dart';

enum PaymentPollOutcome { paid, failed, timeout }

/// Backoff between status reads: 2s, 4s, 8s, 16s, then 32s steps, about
/// 2 minutes in total (126 s) before giving up.
const kPaymentPollDelays = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 4),
  Duration(seconds: 8),
  Duration(seconds: 16),
  Duration(seconds: 32),
  Duration(seconds: 32),
  Duration(seconds: 32),
];

/// Polls the SERVER payment status until it reports paid or failed, or the
/// schedule is exhausted. A browser/app return is never evidence of payment:
/// [PaymentPollOutcome.paid] is returned only when [fetch] resolved to a status
/// the server itself marks paid. Transient read errors are skipped (the next
/// read decides); running out of time is [PaymentPollOutcome.timeout], never
/// paid.
Future<PaymentPollOutcome> pollPaymentStatus(
  Future<PaymentStatusResult> Function() fetch, {
  List<Duration> delays = kPaymentPollDelays,
  Future<void> Function(Duration) sleep = _defaultSleep,
  bool Function()? isCancelled,
}) async {
  Future<PaymentPollOutcome?> readOnce() async {
    try {
      final s = await fetch();
      if (s.serverSaysPaid) return PaymentPollOutcome.paid;
      if (s.serverSaysFailed) return PaymentPollOutcome.failed;
    } on ApiException {
      // transient (network, 5xx, 429 ...): try again on the next tick
    }
    return null;
  }

  final first = await readOnce();
  if (first != null) return first;
  for (final d in delays) {
    if (isCancelled?.call() ?? false) return PaymentPollOutcome.timeout;
    await sleep(d);
    if (isCancelled?.call() ?? false) return PaymentPollOutcome.timeout;
    final out = await readOnce();
    if (out != null) return out;
  }
  return PaymentPollOutcome.timeout;
}

Future<void> _defaultSleep(Duration d) => Future<void>.delayed(d);
