import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/widgets.dart';
import 'auth_controller.dart';
import 'login_screen.dart' show authErrorText, authFromParam;

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    // Don't greet the form with the login screen's failure banner.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(authControllerProvider.notifier).clearError();
    });
  }

  void _onEdited([String? _]) => ref.read(authControllerProvider.notifier).clearError();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).signup(
          email: _email.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
        );
    if (ok && mounted) {
      // Resume the flow the guest came from (?from=, the web's callbackUrl).
      context.go(resumeAfterLogin(authFromParam(context), ref.read(authControllerProvider).user?.role));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final from = authFromParam(context);
    final loginPath = from == null ? '/login' : '/login?from=${Uri.encodeQueryComponent(from)}';
    final auth = ref.watch(authControllerProvider);
    final errorText = authErrorText(l, auth);
    return Scaffold(
      appBar: AppBar(title: Text(l.signup)),
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
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      onChanged: _onEdited,
                      decoration: InputDecoration(labelText: l.fullName),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onChanged: _onEdited,
                      decoration: InputDecoration(labelText: l.email),
                      validator: (v) => (v == null || !v.contains('@')) ? l.emailInvalid : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      onChanged: _onEdited,
                      decoration: InputDecoration(
                        labelText: l.password,
                        helperText: l.passwordMin8,
                        suffixIcon: IconButton(
                          tooltip: _obscure ? l.showPassword : l.hidePassword,
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 8) ? l.passwordMin8 : null,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 14),
                      ErrorBanner(errorText),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.createAccount),
                    ),
                    TextButton(
                      onPressed: auth.busy ? null : () => context.go(loginPath),
                      child: Text(l.haveAccountLogin),
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
