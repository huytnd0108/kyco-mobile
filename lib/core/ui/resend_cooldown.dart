import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/problem.dart';

/// Countdown that gates an OTP "resend" action (the server enforces a 60 s
/// resend cooldown, so an early tap only produces a 429).
///
/// Listen with a `ListenableBuilder`; disable the button while [active] and
/// show [remaining] seconds in its label.
class ResendCooldown extends ChangeNotifier {
  ResendCooldown({this.defaultDuration = const Duration(seconds: 60)});

  final Duration defaultDuration;
  Timer? _timer;
  int _remaining = 0;
  bool _disposed = false;

  int get remaining => _remaining;
  bool get active => _remaining > 0;

  /// Start (or restart) the countdown for [duration] (default: 60 s).
  void start([Duration? duration]) {
    _timer?.cancel();
    final secs = (duration ?? defaultDuration).inSeconds;
    _remaining = secs < 1 ? 1 : secs;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _remaining--;
      if (_remaining <= 0) {
        _remaining = 0;
        t.cancel();
      }
      notifyListeners();
    });
  }

  /// Start the countdown after a failed send when it is a rate limit (429):
  /// the server's `Retry-After` when present, else the default. Other failures
  /// do not start a cooldown (nothing was sent).
  void startAfterFailure(Object? failure) {
    if (failure is ApiException && failure.isRateLimited) start(failure.retryAfter);
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
