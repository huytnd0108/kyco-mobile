import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
import '../../core/ui/resend_cooldown.dart';
import '../../core/widgets.dart';
import '../tasker_wallet/step_up_sheet.dart';

/// Verified phone-change sheet for the customer account area.
///
/// Two phases, mirroring the become-tasker / step-up OTP grammar:
///   1. collect the NEW phone → `POST /auth/otp/request` with
///      `purpose: 'phone_change'` (via [KycoApi.requestOtp]),
///   2. enter the 6-digit code → `POST /me/phone { phone, code }`.
///
/// The change is step-up-gated server-side. We prove freshness BEFORE the POST
/// via [KycoApiTasker.stepUpStatus] + [showStepUpSheet] (reusing the wallet's
/// existing sheet unchanged), and ALSO retry once if the server still answers
/// 403 `STEP_UP_REQUIRED` (freshness can lapse between the check and the POST).
/// 422 VALIDATION (`fields.phone`/`fields.code`) and 409 CONFLICT surface as
/// clear messages. Pops `true` on a confirmed change so the caller can refresh
/// the account/me state.
class ChangePhoneSheet extends ConsumerStatefulWidget {
  const ChangePhoneSheet({super.key});

  @override
  ConsumerState<ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends ConsumerState<ChangePhoneSheet> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _sending = false; // OTP-request in flight
  bool _submitting = false; // phone-change POST in flight
  bool _otpSent = false; // false → collect phone, true → enter code
  String? _error;
  String? _info; // e.g. "Đã gửi mã OTP tới …"
  final _cooldown = ResendCooldown(); // OTP resend gate (60 s / Retry-After)

  // Same acceptance the become-tasker signup + step-up sheet use.
  static final _phoneRe = RegExp(r'^(0|\+84)\d{9}$');

  @override
  void dispose() {
    _cooldown.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _phone => _phoneController.text.trim();

  /// Issue the phone-change OTP to the NEW number. Purpose MUST be
  /// `phone_change` so the server verifies against a matching challenge.
  Future<void> _requestOtp() async {
    if (_sending) return;
    final phone = _phone;
    if (!_phoneRe.hasMatch(phone)) {
      setState(() => _error = AppLocalizations.of(context).provOtpInvalidPhone);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(kycoApiProvider).requestOtp(phone: phone, purpose: 'phone_change');
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _info = AppLocalizations.of(context).provOtpSentTo(phone);
      });
      _cooldown.start();
    } catch (e) {
      if (!mounted) return;
      _cooldown.startAfterFailure(e);
      setState(() => _error = otpSendErrorText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Ensure a fresh step-up grant exists before the change POST, reusing the
  /// wallet's step-up sheet. Returns false if the user backs out. Tolerant of
  /// the step-up route not being deployed yet — the POST's own 403 retry covers
  /// that path.
  Future<bool> _ensureStepUp() async {
    final api = ref.read(kycoApiProvider);
    StepUpStatus status;
    try {
      status = await api.stepUpStatus();
    } catch (_) {
      // Status route unavailable — let the change POST drive the gate via 403.
      return true;
    }
    if (status.fresh) return true;
    if (!mounted) return false;
    return showStepUpSheet(context, hasUsablePassword: status.hasUsablePassword);
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final l = AppLocalizations.of(context);
    if (code.length < 6) {
      setState(() => _error = l.changePhoneCodeRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    if (!await _ensureStepUp()) {
      if (mounted) setState(() => _submitting = false);
      return;
    }

    final api = ref.read(kycoApiProvider);
    var retriedStepUp = false;
    while (true) {
      try {
        await api.changePhone(phone: _phone, code: code);
        if (mounted) Navigator.of(context).pop(true);
        return;
      } on ApiException catch (e) {
        // Freshness can lapse between the pre-check and the POST — offer step-up
        // once more, then retry the same request.
        if (e.status == 403 && e.code == 'STEP_UP_REQUIRED' && !retriedStepUp) {
          retriedStepUp = true;
          if (!await _ensureStepUp()) {
            if (mounted) setState(() => _submitting = false);
            return;
          }
          continue;
        }
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = _messageFor(e, l);
          });
        }
        return;
      } catch (_) {
        if (mounted) {
          setState(() {
            _submitting = false;
            _error = l.genericError;
          });
        }
        return;
      }
    }
  }

  String _messageFor(ApiException e, AppLocalizations l) {
    if (e.status == 409) return l.changePhoneConflict;
    if (e.status == 422) {
      if (e.fields?['code'] != null) return l.changePhoneInvalidCode;
      if (e.fields?['phone'] != null) return l.provOtpInvalidPhone;
    }
    // Everything else (403, network, maintenance, rate limit, …) is localized
    // centrally — never the raw transport / server text.
    return apiErrorText(l, e);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final insets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + insets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.phone_iphone, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.changePhoneTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _otpSent ? l.changePhoneCodePrompt : l.changePhonePrompt,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_info != null && _otpSent) ...[
            _InfoBanner(_info!),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          if (!_otpSent) _buildPhoneStep(l) else _buildCodeStep(l),
        ],
      ),
    );
  }

  Widget _buildPhoneStep(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _phoneController,
          autofocus: true,
          enabled: !_sending,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: l.changePhoneNewLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.phone_outlined),
          ),
          onSubmitted: (_) => _requestOtp(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _sending ? null : _requestOtp,
          child: _sending
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.provSendOtp),
        ),
      ],
    );
  }

  Widget _buildCodeStep(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _codeController,
          autofocus: true,
          enabled: !_submitting,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l.provOtpLabel,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.changePhoneSubmit),
        ),
        const SizedBox(height: 4),
        ListenableBuilder(
          listenable: _cooldown,
          builder: (context, _) => TextButton(
            onPressed: (_sending || _submitting || _cooldown.active) ? null : _requestOtp,
            child: Text(_sending
                ? l.provWalletResendSending
                : (_cooldown.active ? l.otpResendIn(_cooldown.remaining) : l.provWalletResend)),
          ),
        ),
      ],
    );
  }
}

/// Inline confirmation note (mirrors [ErrorBanner]'s shape, success tone).
class _InfoBanner extends StatelessWidget {
  const _InfoBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        border: Border.all(color: cs.secondary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.mark_email_read_outlined,
              color: cs.onSecondaryContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: cs.onSecondaryContainer))),
        ],
      ),
    );
  }
}

/// Present the change-phone flow. Resolves to `true` once the change is
/// confirmed server-side, so the caller can refresh account/me state.
Future<bool> showChangePhoneSheet(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const ChangePhoneSheet(),
  );
  return ok ?? false;
}
