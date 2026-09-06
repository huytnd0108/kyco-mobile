import 'package:flutter/material.dart';
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
class StepUpSheet extends ConsumerStatefulWidget {
  const StepUpSheet({super.key, required this.hasUsablePassword});

  /// From [StepUpStatus.hasUsablePassword] — password path vs. OTP path.
  final bool hasUsablePassword;

  @override
  ConsumerState<StepUpSheet> createState() => _StepUpSheetState();
}

class _StepUpSheetState extends ConsumerState<StepUpSheet> {
  final _controller = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                : 'Nhập mã OTP đã gửi để xác nhận yêu cầu rút tiền.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            obscureText: usePassword && _obscure,
            keyboardType:
                usePassword ? TextInputType.text : TextInputType.number,
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
