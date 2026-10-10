import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The single funnel for uncaught errors (UX-M63).
///
/// Wiring ([installGlobalErrorHandling]):
///  - `FlutterError.onError`            framework errors (build / layout / paint)
///  - `PlatformDispatcher.onError`      uncaught async + platform errors
///  - `ErrorWidget.builder`             a friendly fallback instead of a red screen
///
/// No crash SDK is configured (adding one needs a human-supplied DSN and a
/// privacy-manifest review). Until then the [sink] is `debugPrint` in debug
/// builds only; in release nothing is printed or stored. When an SDK is added,
/// plug it in as the [sink] - everything it receives is already scrubbed.
class ErrorReporter {
  ErrorReporter({void Function(String line)? sink}) : sink = sink ?? _debugOnlySink;

  /// Receives ONE scrubbed line per report.
  final void Function(String line) sink;

  static void _debugOnlySink(String line) {
    if (kDebugMode) debugPrint(line);
  }

  /// Process-wide reporter used by the global hooks.
  static ErrorReporter instance = ErrorReporter();

  static final _rules = <(RegExp, String)>[
    // Authorization header values / bare bearer tokens.
    (RegExp(r'bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false), 'Bearer [token]'),
    // JWTs (header.payload.signature).
    (RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*'), '[jwt]'),
    // key=value / "key": "value" for secret-ish keys.
    (
      RegExp(
          r'''(access[_-]?token|refresh[_-]?token|id[_-]?token|authorization|password|passcode|otp|secret|api[_-]?key|cookie)(["']?\s*[:=]\s*["']?)[^\s"',;&}]+''',
          caseSensitive: false),
      r'$1$2[redacted]'
    ),
    // E-mail addresses.
    (RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'), '[email]'),
    // Phone numbers (VN 0xxxxxxxxx / +84... / 84...), 9-11 digits after the prefix.
    (RegExp(r'(?<![\d.])(?:\+?84|0)[\s.\-]?\d(?:[\s.\-]?\d){7,9}(?!\d)'), '[phone]'),
    // Long opaque hex / base64-ish blobs (refresh tokens, hashes).
    (RegExp(r'\b[A-Fa-f0-9]{32,}\b'), '[hex]'),
  ];

  /// Remove tokens and personal data from free text. Pure.
  static String scrub(String input) {
    var out = input;
    for (final (re, to) in _rules) {
      out = out.replaceAllMapped(re, (m) {
        var r = to;
        for (var i = 1; i <= m.groupCount; i++) {
          r = r.replaceAll('\$$i', m.group(i) ?? '');
        }
        return r;
      });
    }
    return out;
  }

  /// Report one error. Never throws.
  void report(Object error, StackTrace? stack, {String source = 'app', bool fatal = false}) {
    try {
      final head = scrub('${error.runtimeType}: $error');
      final trace = stack == null ? '' : '\n${scrub(stack.toString())}';
      sink('[kyco-error][$source${fatal ? ',fatal' : ''}] $head$trace');
    } catch (_) {/* the reporter must never be the thing that crashes */}
  }
}

/// Hook the framework + platform error channels into [reporter].
void installGlobalErrorHandling({ErrorReporter? reporter}) {
  final r = reporter ?? ErrorReporter.instance;
  FlutterError.onError = (details) {
    r.report(details.exception, details.stack, source: 'flutter');
    // Keep the console dump in debug so developers still see the full widget
    // context; release stays silent.
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    r.report(error, stack, source: 'platform', fatal: true);
    return true; // handled: never crash the process on an async error
  };
}

/// Replace the red/grey error screen with a friendly fallback in release.
/// Call from a place that has localized strings (MaterialApp.builder). Debug
/// builds keep Flutter's default so errors stay loud during development;
/// [force] lets tests exercise the release path.
void installErrorWidget({required String title, required String body, bool force = false}) {
  if (!force && !kReleaseMode) return;
  ErrorWidget.builder = (details) => FriendlyErrorWidget(title: title, body: body);
}

/// What a user sees where a widget failed to build. No stack, no exception text.
class FriendlyErrorWidget extends StatelessWidget {
  const FriendlyErrorWidget({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFFF5F5F5),
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Color(0xFF616161)),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF212121))),
            const SizedBox(height: 4),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF424242))),
          ],
        ),
      ),
    );
  }
}
