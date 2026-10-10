import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';

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
      if (mounted && _reapply) setState(() => _step = _Step.profile);
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
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
      );
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
    setState(() => _error = null);
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
      } else {
        await api.becomeTasker(
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
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Stepper(step: _step),
                const SizedBox(height: 20),
                if (_step == _Step.phone) _phoneStep(l),
                if (_step == _Step.verify) _verifyStep(l),
                if (_step == _Step.profile) _profileStep(l),
              ],
            ),
    );
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
      const SizedBox(height: 16),
      _PrimaryButton(
        label: _submitting ? l.provTaskerSending : l.provTaskerSubmit,
        busy: _submitting,
        onPressed: _submitting ? null : _submit,
      ),
    ],
  );
}

// ── completion ─────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _submitted(context, cs),
        ),
      ),
    );
  }

  // Reached ONLY after the server confirmed the application was stored.
  List<Widget> _submitted(BuildContext context, ColorScheme cs) {
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
      const SizedBox(height: 24),
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
                    if (captured && fileName != null)
                      Text(
                        fileName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
