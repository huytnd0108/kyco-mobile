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

enum PayPhase {
  idle,
  initiating, // POST /payment/initiate in flight
  awaiting, // pay URL handed to the browser/app; waiting for the user to return
  checking, // polling the server status
  paid, // the SERVER reported paid
  failed, // the SERVER reported failed
  timeout, // no verdict within the poll window
  cash,
  alreadyPaid,
  noRail,
  openFailed, // initiate ok but nothing could open the URL
  error, // initiate failed (see [PayFlowState.error])
}

class PayFlowState {
  const PayFlowState(this.phase, {this.error});
  final PayPhase phase;
  final Object? error;

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

  void _refreshBooking() {
    if (_disposed) return;
    _ref.invalidate(bookingDetailProvider(bookingId));
    _ref.invalidate(bookingsProvider);
  }

  /// Host suffixes a gateway pay page may live on (mirrors the backend's
  /// lib/checkout/qr-guard.ts trust list). Our own API host is also allowed so a
  /// lab/sandbox stub page works; any other host is refused — a tampered or
  /// compromised payload can never send the customer to a phishing page.
  static const _payHostSuffixes = ['momo.vn', 'vnpayment.vn', 'vnpay.vn'];

  static bool _hostTrusted(String host) {
    final h = host.toLowerCase();
    final own = Uri.tryParse(AppConfig.apiBase)?.host.toLowerCase();
    if (own != null && own.isNotEmpty && h == own) return true;
    return _payHostSuffixes.any((s) => h == s || h.endsWith('.$s'));
  }

  /// The pay URL must be https on a trusted gateway host.
  static bool isOpenablePayUrl(String? raw) {
    final u = Uri.tryParse(raw ?? '');
    return u != null && u.scheme == 'https' && u.host.isNotEmpty && _hostTrusted(u.host);
  }

  /// Deeplink: only the MoMo app scheme, or a MoMo-hosted https link — the same
  /// constraint the backend applies (qr-guard.ts). Everything else is dropped.
  static bool isOpenableDeeplink(String? raw) {
    final u = Uri.tryParse(raw ?? '');
    if (u == null) return false;
    final scheme = u.scheme.toLowerCase();
    if (scheme == 'momo') return true;
    return scheme == 'https' && u.host.isNotEmpty &&
        (u.host.toLowerCase() == 'momo.vn' || u.host.toLowerCase().endsWith('.momo.vn'));
  }

  /// Ask the server for the pay URL (same txn on a repeat: P6) and hand it to
  /// an external browser/app. Ignored while another call is in flight.
  Future<void> pay() async {
    if (state.busy) return;
    _set(const PayFlowState(PayPhase.initiating));
    final PaymentInitiateResult r;
    try {
      r = await _ref.read(idempotencyLedgerProvider).run(
            'pay-initiate:$bookingId',
            (key) => _ref.read(kycoApiProvider).initiatePayment(bookingId, idempotencyKey: key),
          );
    } on ApiException catch (e) {
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
    _set(PayFlowState(opened ? PayPhase.awaiting : PayPhase.openFailed));
  }

  /// Poll the server (backoff) until it says paid/failed or the window ends,
  /// then refresh the booking. Called on app resume and "Tôi đã thanh toán".
  Future<void> check() async {
    if (state.busy) return;
    _set(const PayFlowState(PayPhase.checking));
    final api = _ref.read(kycoApiProvider);
    final outcome = await pollPaymentStatus(
      () => api.paymentStatus(bookingId),
      delays: _ref.read(paymentPollDelaysProvider),
      sleep: _ref.read(paymentPollSleepProvider),
      isCancelled: () => _disposed,
    );
    _set(PayFlowState(switch (outcome) {
      PaymentPollOutcome.paid => PayPhase.paid,
      PaymentPollOutcome.failed => PayPhase.failed,
      PaymentPollOutcome.timeout => PayPhase.timeout,
    }));
    _refreshBooking();
  }
}
