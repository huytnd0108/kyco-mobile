import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/problem.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import 'auth_controller.dart';

/// The web's `callbackUrl` — the flow the guest came from, to resume after
/// sign-in. Safe when there is no GoRouter in the tree (e.g. golden harness).
String? authFromParam(BuildContext context) => GoRouter.maybeOf(context) == null
    ? null
    : GoRouterState.of(context).uri.queryParameters['from'];

/// Localized banner text for the auth screens' last failure (null = none).
/// Typed failures go through [apiErrorText]; [authText] overrides the 401 copy
/// (a login 401 means "wrong credentials", not "session expired").
String? authErrorText(AppLocalizations l, AuthState auth, {String? authText}) {
  if (auth.failure != null) return apiErrorText(l, auth.failure, authText: authText);
  if (auth.error == null) return null;
  return auth.error == AuthController.genericError ? l.genericError : auth.error;
}

enum _LoginMode { email, phone }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _totp = TextEditingController();
  bool _obscure = true;
  _LoginMode _mode = _LoginMode.email;

  /// Phone mode: the number an OTP was sent to (null = not sent yet).
  String? _otpSentTo;
  bool _sending = false;
  String? _sendError;

  /// Shown once the server answers TOTP_REQUIRED (or TOTP_INVALID).
  bool _needTotp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    _totp.dispose();
    super.dispose();
  }

  void _setMode(_LoginMode m) {
    if (m == _mode) return;
    ref.read(authControllerProvider.notifier).clearError();
    setState(() {
      _mode = m;
      _needTotp = false;
      _sendError = null;
      _totp.clear();
    });
  }

  static final _phoneRe = RegExp(r'^\+?[0-9 .-]{8,16}$');
  static final _otpRe = RegExp(r'^[0-9]{4,8}$');

  Future<void> _sendOtp() async {
    final l = AppLocalizations.of(context);
    final phone = _phone.text.trim();
    if (!_phoneRe.hasMatch(phone)) {
      setState(() => _sendError = l.cust2PhoneInvalid);
      return;
    }
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final failure = await ref.read(authControllerProvider.notifier).requestLoginOtp(phone);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (failure == null) {
        _otpSentTo = phone;
      } else {
        _sendError = (failure is ApiException && failure.code == 'VALIDATION')
            ? l.cust2PhoneInvalid
            : apiErrorText(l, failure);
      }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ctrl = ref.read(authControllerProvider.notifier);
    final totp = _needTotp ? _totp.text.trim() : null;
    final ok = _mode == _LoginMode.email
        ? await ctrl.login(email: _email.text.trim(), password: _password.text, totpCode: totp)
        : await ctrl.loginWithOtp(phone: _otpSentTo ?? _phone.text.trim(), code: _otp.text.trim(), totpCode: totp);
    if (!mounted) return;
    if (ok) {
      // Resume the flow the guest came from (?from=, the web's callbackUrl) —
      // minus a tasker-shell target the signed-in role cannot enter.
      final role = ref.read(authControllerProvider).user?.role;
      context.go(resumeAfterLogin(authFromParam(context), role));
      return;
    }
    final code = ref.read(authControllerProvider).failure?.code;
    if (code == 'TOTP_REQUIRED' || code == 'TOTP_INVALID') {
      setState(() => _needTotp = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final from = authFromParam(context);
    final signupPath = from == null ? '/signup' : '/signup?from=${Uri.encodeQueryComponent(from)}';
    final auth = ref.watch(authControllerProvider);
    final errorText = authErrorText(l, auth,
        authText: _mode == _LoginMode.email ? l.cust2ErrLoginInvalid : l.cust2ErrOtpLoginInvalid);
    final phoneMode = _mode == _LoginMode.phone;
    final canSubmit = !auth.busy && (!phoneMode || _otpSentTo != null);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KycoBrand(),
                    const SizedBox(height: 28),
                    Text(l.login, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    // Wrap (not SegmentedButton) so it never overflows at 320dp.
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          selected: !phoneMode,
                          avatar: const Icon(Icons.mail_outline, size: 18),
                          label: Text(l.cust2LoginModeEmail),
                          onSelected: auth.busy ? null : (_) => _setMode(_LoginMode.email),
                        ),
                        ChoiceChip(
                          selected: phoneMode,
                          avatar: const Icon(Icons.phone_iphone, size: 18),
                          label: Text(l.cust2LoginModePhone),
                          onSelected: auth.busy ? null : (_) => _setMode(_LoginMode.phone),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!phoneMode) ...[
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(labelText: l.email),
                        validator: (v) => (v == null || !v.contains('@')) ? l.emailInvalid : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: l.password,
                          suffixIcon: IconButton(
                            tooltip: _obscure ? l.showPassword : l.hidePassword,
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8) ? l.passwordMin8 : null,
                      ),
                    ] else ...[
                      TextFormField(
                        key: const ValueKey('login-phone'),
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        enabled: !_sending && !auth.busy,
                        decoration: InputDecoration(labelText: l.cust2PhoneLabel),
                        onChanged: (_) {
                          // Editing the number invalidates a code sent to the old one.
                          if (_otpSentTo != null) setState(() => _otpSentTo = null);
                        },
                        validator: (v) => (v == null || !_phoneRe.hasMatch(v.trim())) ? l.cust2PhoneInvalid : null,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        key: const ValueKey('login-send-otp'),
                        onPressed: (_sending || auth.busy) ? null : _sendOtp,
                        child: _sending
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_otpSentTo == null ? l.cust2SendCode : l.cust2ResendCode),
                      ),
                      if (_sendError != null) ...[
                        const SizedBox(height: 10),
                        ErrorBanner(_sendError!),
                      ],
                      if (_otpSentTo != null) ...[
                        const SizedBox(height: 10),
                        Text(l.cust2OtpSent(_otpSentTo!),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const ValueKey('login-otp'),
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(labelText: l.cust2OtpLabel),
                          validator: (v) => (v == null || !_otpRe.hasMatch(v.trim())) ? l.cust2OtpFormat : null,
                        ),
                      ],
                    ],
                    if (_needTotp) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const ValueKey('login-totp'),
                        controller: _totp,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(labelText: l.cust2TotpLabel),
                        validator: (v) => (v == null || !_otpRe.hasMatch(v.trim())) ? l.cust2OtpFormat : null,
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 14),
                      ErrorBanner(errorText),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const ValueKey('login-submit'),
                      onPressed: canSubmit ? _submit : null,
                      child: auth.busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.login),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.busy ? null : () => context.go(signupPath),
                      child: Text(l.noAccountSignup),
                    ),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(l.browseWithoutLogin),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
