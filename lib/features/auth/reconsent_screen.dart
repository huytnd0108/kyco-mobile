import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/problem.dart';
import '../../core/launch.dart';
import '../../core/legal.dart';
import '../../core/ui/consent_checkbox.dart' show legalDocUri;
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import 'auth_controller.dart';

/// "Cập nhật điều khoản" - the blocking-but-polite re-consent gate (release-i).
///
/// Reached only through the router redirect when the signed-in user's `/me`
/// says `consents.needsReconsent`. One checkbox covers both documents; accept
/// records the server's CURRENT version (`POST /me/consents`) and refreshes
/// /me, after which the router resumes the place the user was going. A failed
/// POST shows a friendly error and the same button retries; the gate itself is
/// driven only by /me, so a failure can never loop. Sign-out stays available.
class ReconsentScreen extends ConsumerStatefulWidget {
  const ReconsentScreen({super.key});
  @override
  ConsumerState<ReconsentScreen> createState() => _ReconsentScreenState();
}

class _ReconsentScreenState extends ConsumerState<ReconsentScreen> {
  bool _agreed = false;
  bool _busy = false;
  Object? _failure;

  Future<void> _accept() async {
    if (!_agreed || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final err = await ref.read(authControllerProvider.notifier).acceptReconsent();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = err;
    });
  }

  /// `2026-05-24` -> `24/05/2026`; anything else is shown as sent.
  static String _date(String? v) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v ?? '');
    return m == null ? (v ?? '') : '${m[3]}/${m[2]}/${m[1]}';
  }

  String _errorText(AppLocalizations l, Object e) =>
      e is ApiException && (e.isNetwork || e.isRateLimited || e.isMaintenance)
          ? apiErrorText(l, e)
          : (e is ApiException ? consentErrorText(l, e) : null) ?? l.reconsentError;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final consents = ref.watch(authControllerProvider.select((s) => s.user?.consents));
    final legal = ref.watch(legalProvider).valueOrNull;
    final open = ref.read(urlOpenerProvider);
    final tv = _date(consents?.currentTermsVersion);
    final pv = _date(consents?.currentPrivacyVersion);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.reconsentTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            key: const ValueKey('reconsent-logout'),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: Text(l.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KycoBrand(),
                  const SizedBox(height: 24),
                  Text(l.reconsentIntro, key: const ValueKey('reconsent-intro')),
                  const SizedBox(height: 12),
                  if (tv.isNotEmpty)
                    Text(l.reconsentTermsVersion(tv), key: const ValueKey('reconsent-terms-version')),
                  if (pv.isNotEmpty)
                    Text(l.reconsentPrivacyVersion(pv), key: const ValueKey('reconsent-privacy-version')),
                  Wrap(
                    children: [
                      TextButton(
                        key: const ValueKey('reconsent-terms-link'),
                        onPressed: () => open(legalDocUri(context, legal, 'terms')),
                        child: Text(l.consentTermsLink),
                      ),
                      TextButton(
                        key: const ValueKey('reconsent-privacy-link'),
                        onPressed: () => open(legalDocUri(context, legal, 'privacy')),
                        child: Text(l.consentPrivacyLink),
                      ),
                    ],
                  ),
                  Material(
                    type: MaterialType.transparency,
                    child: CheckboxListTile(
                      key: const ValueKey('reconsent-checkbox'),
                      value: _agreed,
                      onChanged: _busy ? null : (v) => setState(() => _agreed = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.consentAgree),
                    ),
                  ),
                  if (_failure != null) ...[
                    const SizedBox(height: 8),
                    ErrorBanner(_errorText(l, _failure!), key: const ValueKey('reconsent-error')),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    key: const ValueKey('reconsent-accept'),
                    onPressed: (_agreed && !_busy) ? _accept : null,
                    child: _busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_failure != null ? l.retry : l.reconsentAccept),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
