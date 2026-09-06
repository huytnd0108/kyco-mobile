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
/// here (same `/auth/otp/request` client path become_tasker uses) BEFORE showing
/// the code field, with a resend affordance + rate-limit handling.
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
  // OTP path only: the registered phone the code is sent to.
  final _phoneController = TextEditingController();

  bool _submitting = false; // step-up verify in flight
  bool _sending = false; // OTP-request in flight
  bool _otpSent = false; // OTP path phase: false → collect phone, true → enter code
  bool _obscure = true;
  String? _error;
  String? _info; // e.g. "Đã gửi mã OTP tới …"

  // Same acceptance the become-tasker signup uses.
  static final _phoneRe = RegExp(r'^(0|\+84)\d{9}$');

  @override
  void dispose() {
    _controller.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Issue the step-up OTP for a phone-only account. Purpose MUST be
  /// `phone_verification` so the issued challenge matches the server's step-up
  /// verify (a login/register OTP is deliberately NOT replayable here).
  Future<void> _requestOtp() async {
    if (_sending) return;
    final phone = _phoneController.text.trim();
    if (!_phoneRe.hasMatch(phone)) {
      setState(() => _error = 'Số điện thoại không hợp lệ.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
      _info = null;
    });
    try {
      // Bearer-free public OTP issue — same client path as become_tasker.
      await ref.read(apiClientProvider).post(
        '/auth/otp/request',
        auth: false,
        body: {'phone': phone, 'purpose': 'phone_verification'},
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _info = 'Đã gửi mã OTP tới $phone.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final reason = e.fields?['phone'];
      setState(() => _error = switch (reason) {
            'rate_limited' =>
              'Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau.',
            'invalid_phone' || 'invalid' => 'Số điện thoại không hợp lệ.',
            _ => 'Không gửi được mã OTP. Vui lòng thử lại.',
          });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không gửi được mã OTP. Vui lòng thử lại.');
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

    // OTP path, phase 1: collect the registered phone and issue the challenge.
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
                child: Text('Xác minh bảo mật',
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
                ? 'Nhập mật khẩu để xác nhận yêu cầu rút tiền.'
                : collectPhone
                    ? 'Nhập số điện thoại đã đăng ký để nhận mã OTP xác nhận rút tiền.'
                    : 'Nhập mã OTP vừa gửi tới điện thoại để xác nhận yêu cầu rút tiền.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _phoneController,
          autofocus: true,
          enabled: !_sending,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.phone_outlined),
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
              : const Text('Gửi mã OTP'),
        ),
      ],
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
            labelText: usePassword ? l.password : 'Mã OTP',
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
              : const Text('Xác nhận'),
        ),
        if (!usePassword) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: (_sending || _submitting) ? null : _requestOtp,
            child: Text(_sending ? 'Đang gửi lại…' : 'Gửi lại mã'),
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
