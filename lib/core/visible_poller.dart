import 'dart:async';

import 'package:flutter/widgets.dart';

/// Periodic callback that only runs while the screen is VISIBLE: the app is in
/// the foreground AND the owning widget is mounted and not hidden behind
/// another route / an inactive shell tab ([isVisible]). The timer is cancelled
/// when the app is backgrounded and on [dispose], so no request outlives the
/// screen.
class VisiblePoller with WidgetsBindingObserver {
  VisiblePoller({required this.interval, required this.onTick, required this.isVisible});

  final Duration interval;
  final void Function() onTick;
  final bool Function() isVisible;
  Timer? _timer;
  bool _disposed = false;

  /// True while a periodic timer is armed.
  bool get active => _timer != null;

  void start() {
    if (_disposed) return;
    WidgetsBinding.instance.addObserver(this);
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      if (_disposed || !isVisible()) return;
      onTick();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      _arm();
      if (isVisible()) onTick(); // catch up immediately on return
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }
}
