import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/problem.dart';
import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/widgets.dart';

/// Re-authentication sheet for the payout step-up gate (`POST /v1/auth/step-up`).
///
/// A leaked session token alone must never drain the wallet, so a fresh grant
/// is minted here with the account password (or a one-time code for phone-only
/// accounts with no usable password). Returns `true` from [showStepUpSheet] once
/// the grant is minted; the server still re-checks freshness on the payout POST.
///
/// OTP path contract: nothing auto-sends the code. The server's step-up verify
/// (`apps/kyco/app/(actions)/stepup.ts::stepUpWithOtp`) calls
/// `verifyChallenge(phone, code, 'phone_verification')` against a challenge that
/// the client must have issued first — its own comment: "The step-up OTP form …
/// MUST request the OTP from /api/auth/otp/request with purpose:'phone_verification'
/// so issue + verify match." So for phone-only accounts we issue that challenge
/// here BEFORE showing the code field, with a resend affordance + rate-limit
/// handling.
///
/// The server verifies against the ACCOUNT's verified phone
/// (`getStepUpPhone(userId)`), never a typed one — so the user does not enter a
/// number: the sheet reads `GET /me` {phone, phoneVerified}, shows the number
/// masked, and issues the OTP to exactly that phone. An account with no verified
/// phone cannot OTP step-up at all (server fails closed) — say so up front.
class StepUpSheet extends ConsumerStatefulWidget {
  const StepUpSheet({super.key, required this.hasUsablePassword});

  /// From [StepUpStatus.hasUsablePassword] — password path vs. OTP path.
  final bool hasUsablePassword;

  @override
  ConsumerState<StepUpSheet> createState() => _StepUpSheetState();
}

class _StepUpSheetState extends ConsumerState<StepUpSheet> {
  // Holds the password (password path) or the OTP code (OTP path).
  final _controller = TextEditingController();
  // OTP path only: the account's verified phone (from GET /me) — never typed.
  String? _accountPhone;
  bool _phoneLoading = false;
  bool _noVerifiedPhone = false;

  bool _submitting = false; // step-up verify in flight
  bool _sending = false; // OTP-request in flight
  bool _otpSent = false; // OTP path phase: false → collect phone, true → enter code
  bool _obscure = true;
  String? _error;
  String? _info; // e.g. "Đã gửi mã OTP tới …"

  @override
  void initState() {
    super.initState();
    if (!widget.hasUsablePassword) _loadAccountPhone();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Read the account's own phone + verification flag (Bearer `GET /me`).
  Future<void> _loadAccountPhone() async {
    setState(() {
      _phoneLoading = true;
      _error = null;
    });
    try {
      final me = await ref.read(apiClientProvider).get('/me');
      if (!mounted) return;
      final m = me is Map<String, dynamic> ? me : const <String, dynamic>{};
      final phone = (m['phone'] as String?)?.trim();
      final verified = m['phoneVerified'] == true;
      setState(() {
        _accountPhone = (phone != null && phone.isNotEmpty && verified) ? phone : null;
        _noVerifiedPhone = _accountPhone == null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).prov2StepUpPhoneLoadFailed);
      }
    } finally {
      if (mounted) setState(() => _phoneLoading = false);
    }
  }

  /// Issue the step-up OTP for a phone-only account. Purpose MUST be
  /// `phone_verification` so the issued challenge matches the server's step-up
  /// verify (a login/register OTP is deliberately NOT replayable here).
  Future<void> _requestOtp() async {
    if (_sending) return;
    final phone = _accountPhone;
    if (phone == null) return;
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      // The public OTP issue takes a phone; we send ONLY the account's own
      // verified number, which is the one the server step-up verifies against.
      await ref.read(apiClientProvider).post(
        '/auth/otp/request',
        auth: false,
        body: {'phone': phone, 'purpose': 'phone_verification'},
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _info = AppLocalizations.of(context).provOtpSentTo(maskPhone(phone));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      final reason = e.fields?['phone'];
      setState(() => _error = switch (reason) {
            'rate_limited' => l.provOtpRateLimited,
            'invalid_phone' || 'invalid' => l.provOtpInvalidPhone,
            _ => l.provOtpSendFailed,
          });
    } catch (_) {
      if (mounted) {
        setState(() => _error = AppLocalizations.of(context).provOtpSendFailed);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final api = ref.read(kycoApiProvider);
      if (widget.hasUsablePassword) {
        await api.stepUp(password: value);
      } else {
        await api.stepUp(otpCode: value);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = AppLocalizations.of(context).genericError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final usePassword = widget.hasUsablePassword;
    final insets = MediaQuery.of(context).viewInsets;

    // OTP path, phase 1: show the (masked) account phone and issue the challenge.
    final collectPhone = !usePassword && !_otpSent;

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
              Icon(Icons.lock_outline, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.provWalletStepUpTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            usePassword
                ? l.provWalletStepUpPassword
                : collectPhone
                    ? (_accountPhone != null
                        ? l.prov2StepUpOtpTo(maskPhone(_accountPhone!))
                        : _noVerifiedPhone
                            ? l.prov2StepUpNoVerifiedPhone
                            : '')
                    : l.provWalletStepUpOtpPrompt,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_info != null && !collectPhone) ...[
            _InfoBanner(_info!),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          if (collectPhone)
            _buildPhoneStep(l, cs)
          else
            _buildCredentialStep(l, cs, usePassword),
        ],
      ),
    );
  }

  Widget _buildPhoneStep(AppLocalizations l, ColorScheme cs) {
    if (_phoneLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_accountPhone == null) {
      // No verified phone (server would refuse) or /me failed → retry only.
      return _noVerifiedPhone
          ? const SizedBox.shrink()
          : OutlinedButton(onPressed: _loadAccountPhone, child: Text(l.retry));
    }
    return FilledButton(
      onPressed: _sending ? null : _requestOtp,
      child: _sending
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : Text(l.provSendOtp),
    );
  }

  Widget _buildCredentialStep(
      AppLocalizations l, ColorScheme cs, bool usePassword) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          enabled: !_submitting,
          obscureText: usePassword && _obscure,
          keyboardType: usePassword ? TextInputType.text : TextInputType.number,
          inputFormatters: usePassword
              ? null
              : [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: usePassword ? l.password : l.provOtpLabel,
            border: const OutlineInputBorder(),
            suffixIcon: usePassword
                ? IconButton(
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? l.showPassword : l.hidePassword,
                  )
                : null,
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
              : Text(l.provWalletConfirm),
        ),
        if (!usePassword) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: (_sending || _submitting) ? null : _requestOtp,
            child: Text(_sending ? l.provWalletResendSending : l.provWalletResend),
          ),
        ],
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

/// Present the step-up sheet; resolves to `true` once a grant is minted.
Future<bool> showStepUpSheet(BuildContext context,
    {required bool hasUsablePassword}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => StepUpSheet(hasUsablePassword: hasUsablePassword),
  );
  return ok ?? false;
}

/// Mask a phone for display: keep the last 3 digits (`0912345678` →
/// `•••••••678`). Never shows the full number on a money-gating screen.
String maskPhone(String phone) {
  final p = phone.trim();
  if (p.length <= 3) return p;
  return '${'•' * (p.length - 3)}${p.substring(p.length - 3)}';
}
