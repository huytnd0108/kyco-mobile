import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).login(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final errorText =
        auth.error == null ? null : (auth.error == AuthController.genericError ? l.genericError : auth.error!);
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
                    const SizedBox(height: 20),
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
                    if (errorText != null) ...[
                      const SizedBox(height: 14),
                      ErrorBanner(errorText),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: auth.busy ? null : _submit,
                      child: auth.busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(l.login),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: auth.busy ? null : () => context.go('/signup'),
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
