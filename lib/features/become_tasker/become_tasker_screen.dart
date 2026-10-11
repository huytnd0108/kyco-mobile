import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/datetime.dart';
import '../../core/di.dart';
import '../../core/legal.dart';
import '../../core/models.dart';
import '../../core/ui/consent_checkbox.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';

/// Captures one KYC photo from the device camera (null = the user backed out).
/// A provider so widget tests can supply bytes without the camera plugin.
final kycPhotoPickerProvider = Provider<Future<XFile?> Function()>(
  (ref) => () => ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
      ),
);

/// The signed-in pending tasker's application status. `GET /v1/kyc` first;
/// an older backend (no such route) falls back to `/me`'s `application`, and
/// when neither is there the screen shows the static review copy.
final taskerApplicationProvider = FutureProvider.autoDispose<TaskerApplication?>((ref) async {
  try {
    final app = await ref.read(kycoApiProvider).kycApplication();
    if (app != null) return app;
  } catch (_) {/* older backend / offline: use the session's copy */}
  return ref.read(authControllerProvider).user?.application;
});

/// `/become-tasker` — PUBLIC (guest-first) partner onboarding, mirroring the web
/// `become-tasker/tasker-signup-form.tsx` 3-step wizard:
///   1. phone → request OTP (`POST /api/v1/auth/otp/request`, purpose `register`)
///   2. verify OTP + profile fields (name / city / district / optional referral)
///   3. 3 KYC captures (CCCD front/back + selfie) via the device camera.
///
/// SUBMIT — two real backend paths:
///  * guest (the primary audience): `POST /api/v1/become-tasker` (PUBLIC
///    multipart: phone, otp_code, name, city, district, referral_code?,
///    cccd_front, cccd_back, selfie) — verifies the `register` OTP, creates the
///    pending_tasker account and stores the 3 docs in one call;
///  * a signed-in `pending_tasker` re-uploading (rejected / incomplete KYC):
///    Bearer `POST /api/v1/kyc/upload` (+ optional national_id). That route
///    answers 200 even when single files fail, so success is shown ONLY when
///    every required doc kind came back `ok`.
/// Every part carries an explicit allowlisted content type.
class BecomeTaskerScreen extends ConsumerStatefulWidget {
  const BecomeTaskerScreen({super.key});
  @override
  ConsumerState<BecomeTaskerScreen> createState() => _BecomeTaskerScreenState();
}

enum _Step { phone, verify, profile }

const _cityValues = <String>['hcm', 'hn', 'dn'];

/// The 3 required KYC doc kinds — must match ALLOWED_DOC_KINDS server-side
/// (see [KycUploadFile] + the web REQUIRED_KYC).
const _kycKindValues = <String>['cccd_front', 'cccd_back', 'selfie'];

/// Localized label for a city value.
String _cityLabel(AppLocalizations l, String v) => switch (v) {
  'hn' => l.provTaskerCityHn,
  'dn' => l.provTaskerCityDn,
  _ => l.provTaskerCityHcm,
};

/// Localized label for a KYC doc kind.
String _kycKindLabel(AppLocalizations l, String v) => switch (v) {
  'cccd_back' => l.provTaskerKycBack,
  'selfie' => l.provTaskerKycSelfie,
  _ => l.provTaskerKycFront,
};

class _BecomeTaskerScreenState extends ConsumerState<BecomeTaskerScreen> {
  _Step _step = _Step.phone;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _district = TextEditingController();
  final _referral = TextEditingController();
  final _nationalId = TextEditingController();
  String _city = 'hcm';
  final Map<String, XFile> _files = {};

  bool _otpSending = false;
  bool _submitting = false;
  String? _error;
  bool _done = false;

  /// A signed-in pending_tasker looking at the status first; the re-upload form
  /// is one tap away ([_showReupload]).
  bool _showReupload = false;
  bool _refreshing = false;

  /// The public door answered 409 (phone already registered): offer sign-in.
  bool _needLogin = false;

  /// Explicit terms/privacy consent (UX-M06 / FE-47). Client-side gate only:
  /// the API rejects unknown keys (MQA-65); server-side recording is a backend
  /// gap. Not required when re-uploading KYC on an existing pending account.
  bool _consent = false;
  bool _consentTouched = false;
  bool get _needsConsent => !_reapply;

  /// A signed-in CUSTOMER applying: no OTP / phone steps, the account exists
  /// (`POST /become-tasker/upgrade`, the phone is already verified server-side).
  bool get _upgrade {
    final auth = ref.read(authControllerProvider);
    return auth.status == AuthStatus.signedIn && auth.user?.role == 'customer';
  }

  /// A signed-in pending_tasker re-uploading KYC: no phone/OTP/profile steps
  /// (the account exists) — straight to the captures, sent via /kyc/upload.
  bool get _reapply {
    final auth = ref.read(authControllerProvider);
    return auth.status == AuthStatus.signedIn &&
        auth.user?.role == 'pending_tasker';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_reapply) setState(() => _step = _Step.profile);
      if (_upgrade) {
        final known = ref.read(authControllerProvider).user?.name;
        if (known != null && known.trim().isNotEmpty && _name.text.isEmpty) _name.text = known.trim();
        setState(() => _step = _Step.profile);
      }
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    _district.dispose();
    _referral.dispose();
    _nationalId.dispose();
    super.dispose();
  }

  static final _phoneRe = RegExp(r'^(0|\+84)\d{9}$');
  static final _codeRe = RegExp(r'^\d{6,8}$');

  // ── step 1: request OTP ────────────────────────────────────────────────────
  Future<void> _requestOtp() async {
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    final phone = _phone.text.trim();
    if (!_phoneRe.hasMatch(phone)) {
      setState(() => _error = l.provOtpInvalidPhone);
      return;
    }
    if (_otpSending) return;
    setState(() => _otpSending = true);
    try {
      await ref.read(kycoApiProvider).requestOtp(phone: phone, purpose: 'register');
      if (!mounted) return;
      setState(() => _step = _Step.verify);
    } catch (e) {
      if (mounted) setState(() => _error = otpSendErrorText(l, e));
    } finally {
      if (mounted) setState(() => _otpSending = false);
    }
  }

  // ── step 2: verify (client format only; server binds OTP at signup) ─────────
  void _continueToProfile() {
    if (!_codeRe.hasMatch(_code.text.trim())) {
      setState(() => _error = AppLocalizations.of(context).provTaskerOtpFormat);
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.profile;
    });
  }

  // ── step 3: camera capture ─────────────────────────────────────────────────
  Future<void> _capture(String kind) async {
    final l = AppLocalizations.of(context);
    try {
      final x = await ref.read(kycPhotoPickerProvider)();
      if (x == null) return; // user backed out
      if (!mounted) return;
      setState(() => _files[kind] = x);
    } catch (_) {
      // Permission denied / no camera / channel error — all surface here.
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.provTaskerCameraDenied)));
    }
  }

  // ── submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final reapply = _reapply;
    final upgrade = _upgrade;
    if (_needsConsent && !_consent) {
      setState(() => _consentTouched = true);
      return;
    }
    setState(() {
      _error = null;
      _needLogin = false;
    });
    if (!reapply &&
        (_name.text.trim().isEmpty || _district.text.trim().isEmpty)) {
      setState(() => _error = l.provTaskerNameDistrictRequired);
      return;
    }
    for (final kind in _kycKindValues) {
      if (!_files.containsKey(kind)) {
        setState(() => _error = l.provTaskerNeed3Photos);
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final List<KycUploadFile> uploads;
      try {
        uploads = <KycUploadFile>[
          for (final kind in _kycKindValues)
            KycUploadFile(
              kind: kind,
              filename: _files[kind]!.name,
              bytes: await _files[kind]!.readAsBytes(),
              mimeType: _files[kind]!.mimeType,
            ),
        ];
      } catch (_) {
        if (mounted) setState(() => _error = l.provTaskerPhotoReadFailed);
        return;
      }
      final api = ref.read(kycoApiProvider);
      if (reapply) {
        final out = await api.kycUpload(uploads, nationalId: _nationalId.text);
        if (!mounted) return;
        if (!out.allOk(_kycKindValues)) {
          final missing = _kycKindValues.where(
            (k) => !out.uploadedKinds.contains(k),
          );
          setState(
            () => _error = l.prov2TaskerPartialUpload(
              missing.map((k) => _kycKindLabel(l, k)).join(', '),
            ),
          );
          return;
        }
      } else if (upgrade) {
        await api.becomeTaskerUpgrade(
          name: _name.text.trim(),
          city: _city,
          district: _district.text.trim(),
          referralCode: _referral.text,
          files: uploads,
        );
        if (!mounted) return;
        // The account is pending_tasker now: refresh the session role so the app
        // (Account menu, /p gate) reflects it without a cold start.
        unawaited(ref.read(authControllerProvider.notifier).reloadMe());
      } else {
        // Consent fields only if GET /v1/legal answered 200 (guest door only:
        // the upgrade door has no consent contract).
        final consent = ConsentPayload.forLegal(await resolveLegal(ref));
        if (!mounted) return;
        await api.becomeTasker(
          consent: consent,
          phone: _phone.text.trim(),
          otpCode: _code.text.trim(),
          name: _name.text.trim(),
          city: _city,
          district: _district.text.trim(),
          referralCode: _referral.text,
          files: uploads,
        );
        if (!mounted) return;
      }
      // Only reached after the server confirmed every doc was stored.
      setState(() => _done = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _submitErrorText(l, e));
    } catch (_) {
      if (mounted) setState(() => _error = l.prov2TaskerSubmitFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Map a signup/KYC refusal to text: a bad OTP sends the user back to the code
  /// step; a missing/oversized doc names that doc; otherwise the server's own
  /// localized message (phone already registered, rate limit, …).
  String _submitErrorText(AppLocalizations l, ApiException e) {
    final f = e.fields ?? const <String, String>{};
    if (f.containsKey('otp_code')) {
      _step = _Step.verify;
      return l.prov2TaskerOtpInvalid;
    }
    final badDocs = _kycKindValues.where(f.containsKey).toList();
    if (badDocs.isNotEmpty) {
      return l.prov2TaskerPartialUpload(
        badDocs.map((k) => _kycKindLabel(l, k)).join(', '),
      );
    }
    if (e.isMaintenance || e.code == 'network') {
      return l.prov2TaskerSubmitFailed;
    }
    // 409 on the PUBLIC door = the phone already belongs to an account. Say what
    // to do (sign in first) instead of the generic "please sign in or use a
    // different number" that read as nonsense to someone already signed in.
    if (e.status == 409 && !_reapply && !_upgrade) {
      _needLogin = true;
      return l.taskerPhoneExistsLogin;
    }
    final text = apiErrorText(l, e);
    return text == l.genericError ? l.prov2TaskerSubmitFailed : text;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.becomePartner)),
      body: _done
          ? const _DoneView()
          : (_reapply && !_showReupload)
          ? _PendingReviewView(
              refreshing: _refreshing,
              onReupload: () => setState(() => _showReupload = true),
              onRefresh: _refreshStatus,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Stepper(step: _step),
                const SizedBox(height: 20),
                if (_upgrade) ...[
                  Text(l.taskerUpgradeIntro, key: const ValueKey('tasker-upgrade-intro')),
                  const SizedBox(height: 16),
                ],
                if (_step == _Step.phone) _phoneStep(l),
                if (_step == _Step.verify) _verifyStep(l),
                if (_step == _Step.profile) _profileStep(l),
              ],
            ),
    );
  }

  /// Re-read the role: an approved tasker goes straight to the workspace.
  Future<void> _refreshStatus() async {
    if (_refreshing) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _refreshing = true);
    ref.invalidate(taskerApplicationProvider);
    final role = await ref.read(authControllerProvider.notifier).reloadMe();
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (role == 'tasker') {
      router.go('/p');
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l.taskerReviewStillPending)));
    }
  }

  // ── step views ─────────────────────────────────────────────────────────────
  Widget _phoneStep(AppLocalizations l) => _Card(
    title: l.provTaskerVerifyPhoneTitle,
    children: [
      TextField(
        controller: _phone,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: l.provPhoneLabel,
          hintText: '09xxxxxxxx',
        ),
      ),
      if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
      const SizedBox(height: 16),
      _PrimaryButton(
        label: _otpSending ? l.provTaskerSending : l.provSendOtp,
        busy: _otpSending,
        onPressed: _otpSending ? null : _requestOtp,
      ),
    ],
  );

  Widget _verifyStep(AppLocalizations l) => _Card(
    title: l.provTaskerEnterOtpTitle,
    children: [
      Text(
        l.provTaskerOtpSentTo(_phone.text.trim()),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      TextButton(
        onPressed: () => setState(() => _step = _Step.phone),
        child: Text(l.provTaskerChangePhone),
      ),
      TextField(
        controller: _code,
        keyboardType: TextInputType.number,
        maxLength: 8,
        textAlign: TextAlign.center,
        decoration: InputDecoration(labelText: l.provOtpLabel),
      ),
      if (_error != null) ...[const SizedBox(height: 4), ErrorBanner(_error!)],
      const SizedBox(height: 16),
      _PrimaryButton(
        label: l.provTaskerContinue,
        onPressed: _continueToProfile,
      ),
    ],
  );

  Widget _profileStep(AppLocalizations l) => _Card(
    title: l.provTaskerProfileTitle,
    children: [
      if (_reapply) ...[
        TextField(
          controller: _nationalId,
          keyboardType: TextInputType.number,
          maxLength: 12,
          decoration: InputDecoration(labelText: l.prov2TaskerNationalId),
        ),
        const SizedBox(height: 8),
      ] else ...[
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: l.provTaskerFullName),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _city,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.provTaskerCity),
          items: [
            for (final v in _cityValues)
              DropdownMenuItem(value: v, child: Text(_cityLabel(l, v))),
          ],
          onChanged: (v) => setState(() => _city = v ?? 'hcm'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _district,
          decoration: InputDecoration(
            labelText: l.provTaskerDistrict,
            hintText: l.provTaskerDistrictHint,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _referral,
          textCapitalization: TextCapitalization.characters,
          maxLength: 8,
          decoration: InputDecoration(labelText: l.provTaskerReferral),
        ),
        const SizedBox(height: 8),
      ],
      Text(
        l.provTaskerCaptureDocsTitle,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      for (final kind in _kycKindValues)
        _KycTile(
          label: _kycKindLabel(l, kind),
          captured: _files.containsKey(kind),
          fileName: _files[kind]?.name,
          onTap: () => _capture(kind),
        ),
      if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
      if (_needLogin) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('tasker-login-first'),
          onPressed: () => context.push('/login?from=${Uri.encodeQueryComponent('/become-tasker')}'),
          child: Text(AppLocalizations.of(context).login),
        ),
      ],
      if (_needsConsent) ...[
        const SizedBox(height: 8),
        ConsentCheckbox(
          value: _consent,
          showError: _consentTouched,
          onChanged: (v) => setState(() {
            _consent = v;
            _consentTouched = true;
          }),
        ),
      ],
      const SizedBox(height: 16),
      _PrimaryButton(
        label: _submitting ? l.provTaskerSending : l.provTaskerSubmit,
        busy: _submitting,
        onPressed: (_submitting || (_needsConsent && !_consent)) ? null : _submit,
      ),
    ],
  );
}

// ── pending review (signed-in pending_tasker) ───────────────────────────────

class _PendingReviewView extends ConsumerWidget {
  const _PendingReviewView({
    required this.onReupload,
    required this.onRefresh,
    required this.refreshing,
  });
  final VoidCallback onReupload;
  final VoidCallback onRefresh;
  final bool refreshing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final app = ref.watch(taskerApplicationProvider).valueOrNull;
    final rejected = app?.isRejected ?? false;
    Widget step(int n, String text) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: cs.secondaryContainer,
                foregroundColor: cs.onSecondaryContainer,
                child: Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text)),
            ],
          ),
        );
    return ListView(
      key: const ValueKey('tasker-pending-review'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        Icon(Icons.hourglass_top, size: 48, color: cs.primary),
        const SizedBox(height: 12),
        Text(rejected ? l.taskerAppNeedsChanges : l.taskerReviewTitle,
            textAlign: TextAlign.center,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(app?.statusLabel ?? l.taskerReviewIntro,
            key: const ValueKey('tasker-app-status'),
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant)),
        if (app != null) _ApplicationDetails(app: app, onReupload: onReupload),
        const SizedBox(height: 24),
        Text(l.taskerReviewNextTitle, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        step(1, l.taskerReviewNext1),
        step(2, l.taskerReviewNext2),
        step(3, l.taskerReviewNext3),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('tasker-review-refresh'),
          onPressed: refreshing ? null : onRefresh,
          icon: refreshing
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh),
          label: Text(l.taskerReviewRefresh),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('tasker-review-reupload'),
          onPressed: onReupload,
          child: Text(l.taskerReviewReupload),
        ),
        TextButton(onPressed: () => context.go('/'), child: Text(l.provTaskerBackHome)),
      ],
    );
  }
}

/// Dates, the admin's rejection reason and per-document status of the
/// application. A rejected document gets its own re-upload CTA (all three
/// photos are retaken together by the form it opens).
class _ApplicationDetails extends StatelessWidget {
  const _ApplicationDetails({required this.app, required this.onReupload});
  final TaskerApplication app;
  final VoidCallback onReupload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = TextStyle(color: cs.onSurfaceVariant);
    final submitted = vnWall(app.submittedAt) == null ? null : vnDateTime(context, app.submittedAt);
    final reviewed = vnWall(app.reviewedAt) == null ? null : vnDateTime(context, app.reviewedAt);
    return Column(
      key: const ValueKey('tasker-app-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (submitted != null || reviewed != null) ...[
          const SizedBox(height: 12),
          if (submitted != null)
            Text(l.taskerAppSubmittedOn(submitted),
                key: const ValueKey('tasker-app-submitted'), textAlign: TextAlign.center, style: muted),
          if (reviewed != null)
            Text(l.taskerAppReviewedOn(reviewed),
                key: const ValueKey('tasker-app-reviewed'), textAlign: TextAlign.center, style: muted),
        ],
        if (app.rejectionReason != null) ...[
          const SizedBox(height: 12),
          Container(
            key: const ValueKey('tasker-app-rejection'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(l.taskerAppReason(app.rejectionReason!),
                style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],
        if (app.documents.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l.taskerAppDocsTitle, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          for (final d in app.documents) _docRow(context, l, cs, d),
        ],
      ],
    );
  }

  Widget _docRow(BuildContext context, AppLocalizations l, ColorScheme cs, ApplicationDocument d) {
    final name = d.docLabel ?? _kycKindLabel(l, d.docKind);
    final (statusText, icon, color) = switch (d.status) {
      'approved' => (l.taskerAppDocApproved, Icons.check_circle_outline, cs.primary),
      'rejected' => (l.taskerAppDocRejected, Icons.error_outline, cs.error),
      _ => (l.taskerAppDocPending, Icons.hourglass_top, cs.onSurfaceVariant),
    };
    return Padding(
      key: ValueKey('tasker-app-doc-${d.docKind}'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(statusText, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ]),
          if (d.reason != null)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2),
              child: Text(d.reason!, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          if (d.rejected)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('tasker-app-reupload-${d.docKind}'),
                onPressed: onReupload,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l.taskerAppDocReupload(name)),
              ),
            ),
        ],
      ),
    );
  }
}

// ── completion ─────────────────────────────────────────────────────────────

class _DoneView extends ConsumerWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    // A phone-only applicant who applied through the PUBLIC door is not signed
    // in: say how to track the application (OCD-058).
    final signedOut = ref.watch(authControllerProvider).status != AuthStatus.signedIn;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _submitted(context, cs, signedOut: signedOut),
        ),
      ),
    );
  }

  // Reached ONLY after the server confirmed the application was stored.
  List<Widget> _submitted(BuildContext context, ColorScheme cs, {required bool signedOut}) {
    final l = AppLocalizations.of(context);
    return [
      CircleAvatar(
        radius: 32,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        child: const Icon(Icons.check, size: 34),
      ),
      const SizedBox(height: 16),
      Text(
        l.provTaskerDoneTitle,
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        l.provTaskerDoneBody,
        textAlign: TextAlign.center,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
      if (signedOut) ...[
        const SizedBox(height: 12),
        Text(
          l.taskerDoneSignInHint,
          key: const ValueKey('tasker-done-signin-hint'),
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
      ],
      const SizedBox(height: 24),
      if (signedOut) ...[
        FilledButton(
          key: const ValueKey('tasker-done-login'),
          onPressed: () => context.go('/login'),
          child: Text(l.login),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => context.go('/'), child: Text(l.provTaskerBackHome)),
      ] else
        FilledButton(
          onPressed: () => context.go('/'),
          child: Text(l.provTaskerBackHome),
        ),
    ];
  }
}

// ── small UI helpers ─────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final _Step step;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    // Both phone + verify map to the "verify phone" stage (web parity).
    final idx = step == _Step.profile ? 1 : 0;
    final labels = [
      l.provTaskerStepPhone,
      l.provTaskerStepProfile,
      l.provTaskerStepReview,
    ];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: i == idx
                    ? cs.primary
                    : i < idx
                    ? cs.secondaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${i + 1}. ${labels[i]}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: i == idx
                      ? cs.onPrimary
                      : i < idx
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      child: busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    ),
  );
}

class _KycTile extends StatelessWidget {
  const _KycTile({
    required this.label,
    required this.captured,
    required this.onTap,
    this.fileName,
  });
  final String label;
  final bool captured;
  final VoidCallback onTap;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: captured ? cs.primary : cs.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(
                captured ? Icons.check_circle : Icons.photo_camera_outlined,
                color: captured ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    // Never the raw temp file name ("scaled_e114de20-….jpg").
                    if (captured)
                      Text(
                        AppLocalizations.of(context).provTaskerCaptured,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                captured
                    ? AppLocalizations.of(context).provTaskerRetake
                    : AppLocalizations.of(context).provTaskerCapturePhoto,
                style: TextStyle(color: cs.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
