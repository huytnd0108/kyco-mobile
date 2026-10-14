import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/api/idempotency_ledger.dart';
import '../../core/api/payment_poll.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../auth/auth_controller.dart' show authUserIdProvider;
import '../home/home_providers.dart';

/// Opens a payment URL OUTSIDE the app (system browser / the PSP's app).
/// Overridable in tests. Never throws: false = nothing could open it.
final externalLauncherProvider = Provider<Future<bool> Function(Uri)>((_) => (uri) async {
      try {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    });

/// Delay schedule + sleeper for the status poll (overridable in tests).
final paymentPollDelaysProvider = Provider<List<Duration>>((_) => kPaymentPollDelays);
final paymentPollSleepProvider = Provider<Future<void> Function(Duration)>(
    (_) => (d) => Future<void>.delayed(d));

/// Clock for the pay-intent expiry (overridable in tests).
final payClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Rails the server offers (`GET /payment/methods`). Any load error falls back
/// to the legacy set WITHOUT zalopay, so ZaloPay only shows when listed.
final paymentMethodsProvider = FutureProvider.autoDispose<PaymentMethodsInfo>((ref) async {
  ref.watch(authUserIdProvider);
  try {
    return await ref.read(kycoApiProvider).paymentMethods();
  } catch (_) {
    return PaymentMethodsInfo.fallback;
  }
});

enum PayPhase {
  idle,
  initiating, // POST /payment/initiate in flight
  awaiting, // pay URL handed to the browser/app; waiting for the user to return
  checking, // polling the server status
  paid, // the SERVER reported paid
  failed, // the SERVER reported failed
  timeout, // no verdict within the poll window
  expired, // the pay intent passed its server expiresAt (re-create = new key)
  cash,
  alreadyPaid,
  noRail,
  openFailed, // initiate ok but nothing could open the URL
  error, // initiate failed (see [PayFlowState.error])
}

class PayFlowState {
  const PayFlowState(this.phase, {this.error, this.expiresAt, this.sandbox = false});
  final PayPhase phase;
  final Object? error;

  /// Server expiry of the current pay intent (null = unknown).
  final DateTime? expiresAt;

  /// The initiate answer said the rail is in test mode.
  final bool sandbox;

  PayFlowState to(PayPhase p, {Object? error}) =>
      PayFlowState(p, error: error, expiresAt: expiresAt, sandbox: sandbox);

  bool get busy => phase == PayPhase.initiating || phase == PayPhase.checking;
}

/// Per-booking pay state. NOT auto-disposed: it survives rebuilds, navigation
/// and the app being backgrounded for the external payment, so "Đang xác nhận
/// thanh toán" is still there when the user comes back.
final payFlowProvider = StateNotifierProvider.family<PayFlowController, PayFlowState, int>((ref, id) {
  ref.watch(authUserIdProvider); // an account switch starts from a clean state
  return PayFlowController(ref, id);
});

class PayFlowController extends StateNotifier<PayFlowState> {
  PayFlowController(this._ref, this.bookingId) : super(const PayFlowState(PayPhase.idle));
  final Ref _ref;
  final int bookingId;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _set(PayFlowState s) {
    if (!_disposed) state = s;
  }

  String get _fingerprint => 'pay-initiate:$bookingId';

  void _refreshBooking() {
    if (_disposed) return;
    _ref.invalidate(bookingDetailProvider(bookingId));
    _ref.invalidate(bookingsProvider);
  }

  /// Host suffixes a gateway pay page may live on (mirrors the backend's
  /// lib/checkout/qr-guard.ts trust list). Our own API host is also allowed so a
  /// lab/sandbox stub page works; any other host is refused — a tampered or
  /// compromised payload can never send the customer to a phishing page.
  static const _payHostSuffixes = ['momo.vn', 'vnpayment.vn', 'vnpay.vn', 'zalopay.vn'];

  /// Exact domain or a real subdomain: the suffix is matched WITH its leading
  /// dot, never by `contains`, so `evilzalopay.vn` / `zalopay.vn.evil.com` fail.
  static bool _onSuffix(String host, String suffix) => host == suffix || host.endsWith('.$suffix');

  /// https, a host, no `user@` part and no non-default port: the parts a
  /// look-alike URL hides behind.
  static bool _plainHttps(Uri u) =>
      u.scheme == 'https' && u.host.isNotEmpty && u.userInfo.isEmpty && (!u.hasPort || u.port == 443);

  static bool _hostTrusted(Uri u) {
    final h = u.host.toLowerCase();
    // The own-API-host stub page is a lab/debug aid only: never in a release build.
    if (!kReleaseMode) {
      final own = Uri.tryParse(AppConfig.apiBase)?.host.toLowerCase();
      if (own != null && own.isNotEmpty && h == own) return true;
    }
    return _plainHttps(u) && _payHostSuffixes.any((s) => _onSuffix(h, s));
  }

  /// The pay URL must be https on a trusted gateway host.
  static bool isOpenablePayUrl(String? raw) {
    final u = Uri.tryParse(raw ?? '');
    return u != null && u.scheme == 'https' && u.host.isNotEmpty && _hostTrusted(u);
  }

  /// Deeplink: only the MoMo app scheme, or an https link on a MoMo / ZaloPay
  /// host (same constraint as the backend qr-guard.ts). No custom ZaloPay app
  /// scheme is accepted (unconfirmed): such a deeplink is ignored and the flow
  /// falls back to the pay URL. Everything else is dropped.
  static bool isOpenableDeeplink(String? raw) {
    final u = Uri.tryParse(raw ?? '');
    if (u == null) return false;
    final scheme = u.scheme.toLowerCase();
    if (scheme == 'momo') return true;
    final h = u.host.toLowerCase();
    return _plainHttps(u) && (_onSuffix(h, 'momo.vn') || _onSuffix(h, 'zalopay.vn'));
  }

  /// Ask the server for the pay URL (same txn on a repeat: P6) and hand it to
  /// an external browser/app. Ignored while another call is in flight.
  Future<void> pay() async {
    if (state.busy) return;
    final ledger = _ref.read(idempotencyLedgerProvider);
    // The last intent is past its server expiry: a pending key from it must not
    // be replayed, so this tap is a NEW action with a fresh key.
    final exp = state.expiresAt;
    if (exp != null && !_ref.read(payClockProvider)().isBefore(exp)) {
      await ledger.forget(_fingerprint);
    }
    if (_disposed) return;
    _set(const PayFlowState(PayPhase.initiating));
    final PaymentInitiateResult r;
    try {
      r = await ledger.run(
        _fingerprint,
        (key) => _ref.read(kycoApiProvider).initiatePayment(bookingId, idempotencyKey: key),
      );
    } on ApiException catch (e) {
      // 409 PAYMENT_NOT_ALLOWED_IN_STATUS: the booking moved on — show its real state.
      if (e.code == 'PAYMENT_NOT_ALLOWED_IN_STATUS') _refreshBooking();
      _set(PayFlowState(PayPhase.error, error: e));
      return;
    } catch (e) {
      _set(PayFlowState(PayPhase.error, error: e));
      return;
    }
    switch (r.kind) {
      case 'cash':
        _set(const PayFlowState(PayPhase.cash));
        _refreshBooking();
      case 'already_paid':
        _set(const PayFlowState(PayPhase.alreadyPaid));
        _refreshBooking();
      case 'no_rail':
        _set(const PayFlowState(PayPhase.noRail));
      case 'ok':
        await _open(r);
      default:
        _set(PayFlowState(PayPhase.error, error: StateError('unknown initiate kind')));
    }
  }

  Future<void> _open(PaymentInitiateResult r) async {
    final launch = _ref.read(externalLauncherProvider);
    var opened = false;
    if (isOpenableDeeplink(r.deeplink)) opened = await launch(Uri.parse(r.deeplink!));
    if (!opened && isOpenablePayUrl(r.payUrl)) opened = await launch(Uri.parse(r.payUrl!));
    // Opening is NOT payment: the state only says "waiting for the server".
    _set(PayFlowState(opened ? PayPhase.awaiting : PayPhase.openFailed,
        expiresAt: r.expiry, sandbox: r.sandbox == true));
  }

  /// Poll the server (backoff) until it says paid/failed or the window ends,
  /// then refresh the booking. Called on app resume and "Tôi đã thanh toán".
  Future<void> check() async {
    if (state.busy) return;
    _set(state.to(PayPhase.checking));
    final api = _ref.read(kycoApiProvider);
    final now = _ref.read(payClockProvider);
    // The poll never runs past the server expiry (nor past the usual cap).
    final outcome = await pollPaymentStatus(
      () => api.paymentStatus(bookingId),
      delays: _ref.read(paymentPollDelaysProvider),
      sleep: _ref.read(paymentPollSleepProvider),
      isCancelled: () => _disposed,
      deadline: state.expiresAt,
      now: now,
    );
    final exp = state.expiresAt;
    final expired = exp != null && !now().isBefore(exp);
    _set(state.to(switch (outcome) {
      PaymentPollOutcome.paid => PayPhase.paid,
      PaymentPollOutcome.failed => PayPhase.failed,
      PaymentPollOutcome.timeout => expired ? PayPhase.expired : PayPhase.timeout,
    }));
    _refreshBooking();
  }
}
