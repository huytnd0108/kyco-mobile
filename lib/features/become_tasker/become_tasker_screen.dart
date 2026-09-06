import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/widgets.dart';

/// `/become-tasker` — PUBLIC (guest-first) partner onboarding, mirroring the web
/// `become-tasker/tasker-signup-form.tsx` 3-step wizard:
///   1. phone → request OTP (`POST /api/v1/auth/otp/request`, purpose `register`)
///   2. verify OTP + profile fields (name / city / district / optional referral)
///   3. 3 KYC captures (CCCD front/back + selfie) via the device camera.
///
/// SUBMIT: the web signup is a Next.js server action (`submitTaskerSignup`) — it
/// is NOT exposed as an `/api/v1` route, so there is no mobile submit endpoint to
/// call, and the frozen [KycoApiProvider.kycUpload] is Bearer-only (a guest has
/// no token). For a guest (the primary audience of this PUBLIC route) NOTHING is
/// persisted — the upload 401s — so the terminal state must NOT claim receipt.
/// The wizard captures the fields, attempts the upload, and branches on the REAL
/// result: an honest "documents submitted" only when the upload actually
/// succeeded (a signed-in re-applicant with a real token), otherwise an honest
/// "coming soon — finish on the web" state. See the unit report's "missing
/// onboarding submit route".
///
/// NOTE: copy is inlined (VN-first) — the `partner.form.*` strings are NOT in the
/// mobile ARB (l10n is out of this unit's scope). See report's "missing ARB".
class BecomeTaskerScreen extends ConsumerStatefulWidget {
  const BecomeTaskerScreen({super.key});
  @override
  ConsumerState<BecomeTaskerScreen> createState() => _BecomeTaskerScreenState();
}

enum _Step { phone, verify, profile }

const _cities = <(String, String)>[
  ('hcm', 'TP. Hồ Chí Minh'),
  ('hn', 'Hà Nội (sắp khai trương)'),
  ('dn', 'Đà Nẵng (sắp khai trương)'),
];

/// The 3 required KYC doc kinds — must match ALLOWED_DOC_KINDS server-side
/// (see [KycUploadFile] + the web REQUIRED_KYC).
const _kycKinds = <(String, String)>[
  ('cccd_front', 'CCCD mặt trước'),
  ('cccd_back', 'CCCD mặt sau'),
  ('selfie', 'Ảnh chân dung'),
];

class _BecomeTaskerScreenState extends ConsumerState<BecomeTaskerScreen> {
  _Step _step = _Step.phone;
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _district = TextEditingController();
  final _referral = TextEditingController();
  String _city = 'hcm';
  final Map<String, XFile> _files = {};

  bool _otpSending = false;
  bool _submitting = false;
  String? _error;
  bool _done = false;
  // True ONLY when kycUpload actually persisted the docs (a signed-in
  // re-applicant with a real token). A guest upload 401s → stays false, and the
  // terminal state then honestly says registration isn't live yet.
  bool _uploaded = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    _district.dispose();
    _referral.dispose();
    super.dispose();
  }

  static final _phoneRe = RegExp(r'^(0|\+84)\d{9}$');
  static final _codeRe = RegExp(r'^\d{6,8}$');

  // ── step 1: request OTP ────────────────────────────────────────────────────
  Future<void> _requestOtp() async {
    setState(() => _error = null);
    final phone = _phone.text.trim();
    if (!_phoneRe.hasMatch(phone)) {
      setState(() => _error = 'Số điện thoại không hợp lệ.');
      return;
    }
    if (_otpSending) return;
    setState(() => _otpSending = true);
    try {
      // Bearer-free public OTP issue — same path the web signup form uses.
      await ref.read(apiClientProvider).post(
        '/auth/otp/request',
        auth: false,
        body: {'phone': phone, 'purpose': 'register'},
      );
      if (!mounted) return;
      setState(() => _step = _Step.verify);
    } on ApiException catch (e) {
      if (!mounted) return;
      final reason = e.fields?['phone'];
      setState(() => _error = switch (reason) {
            'rate_limited' => 'Bạn đã yêu cầu quá nhiều lần. Vui lòng thử lại sau.',
            'invalid_phone' || 'invalid' => 'Số điện thoại không hợp lệ.',
            _ => 'Không gửi được mã OTP. Vui lòng thử lại.',
          });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không gửi được mã OTP. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _otpSending = false);
    }
  }

  // ── step 2: verify (client format only; server binds OTP at signup) ─────────
  void _continueToProfile() {
    if (!_codeRe.hasMatch(_code.text.trim())) {
      setState(() => _error = 'Mã OTP gồm 6–8 chữ số.');
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.profile;
    });
  }

  // ── step 3: camera capture ─────────────────────────────────────────────────
  Future<void> _capture(String kind) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Không mở được camera. Vui lòng cấp quyền camera trong Cài đặt.'),
        ),
      );
    }
  }

  // ── submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    setState(() => _error = null);
    if (_name.text.trim().isEmpty || _district.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập họ tên và quận/huyện.');
      return;
    }
    for (final (kind, _) in _kycKinds) {
      if (!_files.containsKey(kind)) {
        setState(() => _error = 'Vui lòng chụp đủ 3 ảnh giấy tờ.');
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      // Build the multipart payload from the captures.
      final uploads = <KycUploadFile>[
        for (final (kind, _) in _kycKinds)
          KycUploadFile(
            kind: kind,
            filename: _files[kind]!.name,
            bytes: await _files[kind]!.readAsBytes(),
          ),
      ];
      // kycUpload is Bearer-only and there is no public /api/v1 tasker-signup
      // route yet, so a guest upload cannot persist a signup (it 401s). Attempt
      // it and branch on the ACTUAL result: a signed-in re-applicant with a real
      // token persists their docs (honest "submitted"); a guest does not, so the
      // terminal state must NOT claim receipt — see [_DoneView].
      var uploaded = false;
      try {
        await ref.read(kycoApiProvider).kycUpload(uploads);
        uploaded = true;
      } catch (_) {
        // Guest/401 or a transient failure — nothing was stored.
        uploaded = false;
      }
      if (!mounted) return;
      setState(() {
        _uploaded = uploaded;
        _done = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không đọc được ảnh. Vui lòng chụp lại.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.becomePartner)),
      body: _done
          ? _DoneView(uploaded: _uploaded)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Stepper(step: _step),
                const SizedBox(height: 20),
                if (_step == _Step.phone) _phoneStep(),
                if (_step == _Step.verify) _verifyStep(),
                if (_step == _Step.profile) _profileStep(),
              ],
            ),
    );
  }

  // ── step views ─────────────────────────────────────────────────────────────
  Widget _phoneStep() => _Card(
        title: 'Xác minh số điện thoại',
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Số điện thoại',
              hintText: '09xxxxxxxx',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(_error!),
          ],
          const SizedBox(height: 16),
          _PrimaryButton(
            label: _otpSending ? 'Đang gửi…' : 'Gửi mã OTP',
            busy: _otpSending,
            onPressed: _otpSending ? null : _requestOtp,
          ),
        ],
      );

  Widget _verifyStep() => _Card(
        title: 'Nhập mã OTP',
        children: [
          Text('Mã đã gửi tới ${_phone.text.trim()}',
              style: Theme.of(context).textTheme.bodySmall),
          TextButton(
            onPressed: () => setState(() => _step = _Step.phone),
            child: const Text('Đổi số điện thoại'),
          ),
          TextField(
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 8,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'Mã OTP'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            ErrorBanner(_error!),
          ],
          const SizedBox(height: 16),
          _PrimaryButton(label: 'Tiếp tục', onPressed: _continueToProfile),
        ],
      );

  Widget _profileStep() => _Card(
        title: 'Thông tin & giấy tờ',
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _city,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Thành phố'),
            items: [
              for (final (v, label) in _cities)
                DropdownMenuItem(value: v, child: Text(label)),
            ],
            onChanged: (v) => setState(() => _city = v ?? 'hcm'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _district,
            decoration: const InputDecoration(
              labelText: 'Quận / Huyện',
              hintText: 'VD: Quận 1',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referral,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Mã giới thiệu (tuỳ chọn)',
            ),
          ),
          const SizedBox(height: 8),
          const Text('Chụp ảnh giấy tờ',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final (kind, label) in _kycKinds)
            _KycTile(
              label: label,
              captured: _files.containsKey(kind),
              fileName: _files[kind]?.name,
              onTap: () => _capture(kind),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(_error!),
          ],
          const SizedBox(height: 16),
          _PrimaryButton(
            label: _submitting ? 'Đang gửi…' : 'Gửi hồ sơ',
            busy: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      );
}

// ── completion ─────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView({required this.uploaded});

  /// Whether the KYC upload actually persisted (a signed-in re-applicant with a
  /// real Bearer token). For a guest the upload 401s and NOTHING is stored, so
  /// we must not claim receipt — see [_BecomeTaskerScreenState._submit].
  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: uploaded ? _submitted(context, cs) : _notLive(context, cs),
        ),
      ),
    );
  }

  // Honest success — reached ONLY when kycUpload actually succeeded (real token).
  List<Widget> _submitted(BuildContext context, ColorScheme cs) => [
        CircleAvatar(
          radius: 32,
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          child: const Icon(Icons.check, size: 34),
        ),
        const SizedBox(height: 16),
        Text('Đã gửi hồ sơ • Documents submitted',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Kyco đã nhận giấy tờ của bạn và sẽ liên hệ để hoàn tất đăng ký. '
          'We have received your documents and will contact you to finish signing up.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Về trang chủ • Home'),
        ),
      ];

  // Honest not-live state — the guest path, where nothing was persisted. It must
  // NOT promise receipt or a 24h callback the backend cannot deliver.
  List<Widget> _notLive(BuildContext context, ColorScheme cs) => [
        CircleAvatar(
          radius: 32,
          backgroundColor: cs.secondaryContainer,
          foregroundColor: cs.onSecondaryContainer,
          child: const Icon(Icons.hourglass_top, size: 34),
        ),
        const SizedBox(height: 16),
        Text('Sắp ra mắt trên ứng dụng • Coming soon in the app',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Đăng ký cộng tác viên chưa mở trên ứng dụng, nên hồ sơ chưa được gửi đi. '
          'Vui lòng hoàn tất đăng ký tại kyco.vn hoặc email tasker@kyco.vn.\n'
          'Partner registration isn’t live in the app yet, so your details were '
          'not submitted. Please finish signing up at kyco.vn or email tasker@kyco.vn.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Về trang chủ • Home'),
        ),
      ];
}

// ── small UI helpers ─────────────────────────────────────────────────────────

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final _Step step;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Both phone + verify map to the "verify phone" stage (web parity).
    final idx = step == _Step.profile ? 1 : 0;
    const labels = ['Xác minh SĐT', 'Hồ sơ & KYC', 'Duyệt hồ sơ'];
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
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onPressed, this.busy = false});
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
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (captured && fileName != null)
                      Text(fileName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(captured ? 'Chụp lại' : 'Chụp ảnh',
                  style: TextStyle(color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
