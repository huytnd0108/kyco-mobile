import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/datetime.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import '../tasker_wallet/step_up_sheet.dart';
import 'invite_screen.dart' show SignInGate;

/// Pending-deletion read (`GET /v1/me/account/deletion`) for the signed-in user.
final deletionStatusProvider = FutureProvider.autoDispose<DeletionStatus>((ref) {
  ref.watch(authUserIdProvider);
  return ref.watch(kycoApiProvider).deletionStatus();
});

/// Whether the server lets this role self-delete: customers only (the route
/// answers 409 for tasker / pending_tasker / admin / staff). An unknown role
/// (optimistic session) is let through - the server decides.
bool canSelfDelete(String? role) => role == null || role == 'customer';

/// `/delete-account` - Account > "Xóa tài khoản" (App Store 5.1.1(v) / Play).
///
/// Flow: explain consequences + the 30-day grace -> optional data export ->
/// type the confirm word -> fresh step-up (password / OTP) -> `POST
/// /v1/me/account/deletion` -> sign out + clear user state -> the public
/// restore screen (which shows the scheduled date and the cancel form).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _busy = false; // deletion in flight
  bool _exporting = false;
  bool _exported = false;
  String? _error;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  bool _matches(AppLocalizations l) =>
      _confirm.text.trim().toLowerCase() == l.deleteConfirmWord.toLowerCase();

  Future<void> _export() async {
    if (_exporting || _exported) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _exporting = true;
      _error = null;
    });
    try {
      await ref.read(kycoApiProvider).requestDataExport();
      if (mounted) setState(() => _exported = true);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(l, e));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// A fresh step-up grant is mandatory for deletion. False = the user backed out.
  Future<bool> _ensureStepUp() async {
    final api = ref.read(kycoApiProvider);
    StepUpStatus status;
    try {
      status = await api.stepUpStatus();
    } catch (_) {
      return true; // status route unavailable: the POST's own 403 drives the gate
    }
    if (status.fresh) return true;
    if (!mounted) return false;
    return showStepUpSheet(context, hasUsablePassword: status.hasUsablePassword);
  }

  Future<void> _submit() async {
    if (_busy) return; // in-flight guard
    final l = AppLocalizations.of(context);
    if (!_matches(l)) return;
    final router = GoRouter.of(context);
    final auth = ref.read(authControllerProvider.notifier);
    final api = ref.read(kycoApiProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _ensureStepUp()) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      DeletionStatus result;
      var retriedStepUp = false;
      while (true) {
        try {
          result = await api.requestAccountDeletion();
          break;
        } on ApiException catch (e) {
          if (e.status == 403 && e.code == 'STEP_UP_REQUIRED' && !retriedStepUp) {
            retriedStepUp = true;
            if (!await _ensureStepUp()) {
              if (mounted) setState(() => _busy = false);
              return;
            }
            continue;
          }
          rethrow;
        }
      }
      // Server already revoked every session; now drop local tokens and every
      // user-scoped cache (the auth listener runs clearUserScopedState).
      await auth.logout();
      final q = result.scheduledFor == null
          ? ''
          : '?scheduled=${Uri.encodeQueryComponent(result.scheduledFor!)}';
      router.go('/restore-account$q');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorText(l, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final authState = ref.watch(authControllerProvider);
    final signedIn = authState.status == AuthStatus.signedIn;
    final pending = ref.watch(deletionStatusProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l.deleteAccountTitle)),
      body: SafeArea(
        child: !signedIn
            ? const SignInGate(from: '/delete-account')
            : CenteredMaxWidth(
                maxWidth: 600,
                child: !canSelfDelete(authState.user?.role)
                    ? _SupportOnly(role: authState.user?.role)
                    : (pending?.pending ?? false)
                        ? _PendingState(scheduledFor: pending!.scheduledFor)
                        : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(l.deleteAccountIntro),
                          const SizedBox(height: 12),
                          for (final t in [l.deleteConseq1, l.deleteConseq2, l.deleteConseq3, l.deleteConseq4])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7, right: 10),
                                    child: Icon(Icons.circle, size: 6, color: cs.onSurfaceVariant),
                                  ),
                                  Expanded(child: Text(t, style: TextStyle(color: cs.onSurfaceVariant))),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(l.deleteExportHint, style: TextStyle(color: cs.onSurfaceVariant)),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    key: const ValueKey('delete-export'),
                                    onPressed: (_exporting || _exported || _busy) ? null : _export,
                                    icon: _exporting
                                        ? const SizedBox(
                                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                        : Icon(_exported ? Icons.check_circle_outline : Icons.download_outlined),
                                    label: Text(_exported ? l.deleteExportRequested : l.deleteExportCta),
                                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            key: const ValueKey('delete-confirm-field'),
                            controller: _confirm,
                            enabled: !_busy,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: l.deleteTypeToConfirm(l.deleteConfirmWord),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
                          const SizedBox(height: 16),
                          FilledButton(
                            key: const ValueKey('delete-submit'),
                            onPressed: (_busy || !_matches(l)) ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.error,
                              foregroundColor: cs.onError,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: _busy
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.onError))
                                : Text(l.deleteConfirmButton),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }
}

/// The server already has a deletion request for this account (state=pending).
class _PendingState extends StatelessWidget {
  const _PendingState({required this.scheduledFor});
  final String? scheduledFor;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final date = scheduledFor == null ? null : vnDateMedium(context, scheduledFor);
    final hasDate = date != null && date != '—';
    return EmptyState(
      icon: Icons.hourglass_bottom,
      message: hasDate ? l.deletePendingBody(date) : l.deletePendingBodyNoDate,
      action: FilledButton(
        key: const ValueKey('delete-pending-cancel'),
        onPressed: () => context.go(
            '/restore-account${scheduledFor == null ? '' : '?scheduled=${Uri.encodeQueryComponent(scheduledFor!)}'}'),
        child: Text(l.deleteCancelRequest),
      ),
    );
  }
}

/// Tasker / admin / staff: the server refuses self-deletion - point to support.
class _SupportOnly extends StatelessWidget {
  const _SupportOnly({required this.role});
  final String? role;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tasker = role == 'tasker';
    return EmptyState(
      icon: Icons.support_agent_outlined,
      message: l.deleteSupportOnly,
      action: FilledButton(
        key: const ValueKey('delete-contact-support'),
        onPressed: () => context.push(tasker ? '/p/support' : '/legal/contact'),
        child: Text(l.deleteContactSupport),
      ),
    );
  }
}

/// `/restore-account[?scheduled=ISO]` - PUBLIC. Shown right after a deletion
/// request (with the scheduled date) and reachable from the login screen. The
/// cancel call proves ownership with email + password (+ TOTP) because the
/// account is deactivated; on success the user signs in again.
class RestoreAccountScreen extends ConsumerStatefulWidget {
  const RestoreAccountScreen({super.key, this.scheduledFor});
  final String? scheduledFor;
  @override
  ConsumerState<RestoreAccountScreen> createState() => _RestoreAccountScreenState();
}

class _RestoreAccountScreenState extends ConsumerState<RestoreAccountScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();
  bool _busy = false;
  bool _restored = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _totp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(kycoApiProvider).cancelAccountDeletion(
            email: _email.text.trim(),
            password: _password.text,
            totpCode: _totp.text.trim(),
          );
      if (mounted) setState(() => _restored = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isUnauthorized || e.status == 401 ? l.restoreFailed : apiErrorText(l, e);
      });
    } catch (_) {
      if (mounted) setState(() => _error = l.genericError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final date = widget.scheduledFor == null ? null : vnDateMedium(context, widget.scheduledFor);
    final hasDate = date != null && date != '—';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.scheduledFor != null ? l.deletePendingTitle : l.restoreTitle),
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: l.goHome,
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: CenteredMaxWidth(
          maxWidth: 480,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_restored) ...[
                Text(l.restoreSuccess, key: const ValueKey('restore-success')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: Text(l.login),
                ),
              ] else ...[
                if (widget.scheduledFor != null) ...[
                  Text(hasDate ? l.deletePendingBody(date) : l.deletePendingBodyNoDate,
                      key: const ValueKey('restore-pending-body')),
                  const SizedBox(height: 20),
                ],
                Text(l.restoreBody),
                const SizedBox(height: 16),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const ValueKey('restore-email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        enabled: !_busy,
                        decoration: InputDecoration(labelText: l.email, border: const OutlineInputBorder()),
                        validator: (v) => (v == null || v.trim().isEmpty) ? l.cust2Required : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('restore-password'),
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        enabled: !_busy,
                        decoration: InputDecoration(labelText: l.password, border: const OutlineInputBorder()),
                        validator: (v) => (v == null || v.isEmpty) ? l.cust2Required : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('restore-totp'),
                        controller: _totp,
                        keyboardType: TextInputType.number,
                        enabled: !_busy,
                        decoration:
                            InputDecoration(labelText: l.restoreTotpLabel, border: const OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('restore-submit'),
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _busy
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.scheduledFor != null ? l.deleteCancelRequest : l.restoreButton),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
