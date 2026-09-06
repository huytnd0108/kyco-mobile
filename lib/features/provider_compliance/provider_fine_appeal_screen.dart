import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'provider_compliance_providers.dart';

/// Minimum appeal body length the backend enforces (422 below this).
const int _kMinAppealChars = 20;

/// `/p/fines/:id/appeal` (A4) — the ONE write in this folder. Shows the fine,
/// then either the existing appeal (read-only) or a text form. Submitting fires
/// `appealFine(id, body)` and reconciles the two server rejections: 409 (an
/// appeal already exists) and 422 (body under 20 chars). Money is DISPLAY-ONLY.
class ProviderFineAppealScreen extends ConsumerWidget {
  const ProviderFineAppealScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    // The route builder ignores GoRouterState, so read the id here.
    final id = int.tryParse(GoRouterState.of(context).pathParameters['id'] ?? '') ?? 0;
    final detail = ref.watch(fineDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(l.provAppealTitle)),
      body: SafeArea(
        top: false,
        child: CenteredMaxWidth(
          maxWidth: 640,
          child: detail.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetry(
              message: l.homeLoadError(e.toString()),
              onRetry: () => ref.invalidate(fineDetailProvider(id)),
            ),
            data: (view) {
              final fine = view.fine;
              if (fine == null) {
                // TODO-i18n: "Không tìm thấy khoản phạt" not-found (no ARB key).
                return EmptyState(message: 'Không tìm thấy khoản phạt', icon: '🔍');
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _FineCard(fine),
                  const SizedBox(height: 16),
                  if (view.existing != null)
                    _ExistingAppeal(view.existing!)
                  else
                    _AppealForm(fineId: id),
                  const SizedBox(height: 16),
                  const _AppealNote(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FineCard extends StatelessWidget {
  const _FineCard(this.fine);
  final Fine fine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // kind / reason are backend enums — shown raw (server-derived display).
          Text(fine.kind ?? '—',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: cs.onErrorContainer)),
          if ((fine.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(fine.reason!, style: TextStyle(color: cs.onErrorContainer)),
          ],
          const SizedBox(height: 10),
          Text('-${formatVnd(fine.amountVnd)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.error,
              )),
        ],
      ),
    );
  }
}

class _ExistingAppeal extends StatelessWidget {
  const _ExistingAppeal(this.appeal);
  final FineAppeal appeal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TODO-i18n: "Khiếu nại của bạn" existing-appeal header (no ARB key).
            Text('Khiếu nại của bạn',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                // TODO-i18n: "Trạng thái" status label (no ARB key).
                Text('Trạng thái: ', style: TextStyle(color: cs.onSurfaceVariant)),
                // status is a backend enum — shown raw.
                Text(appeal.status ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            if ((appeal.body ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"${appeal.body}"',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppealForm extends ConsumerStatefulWidget {
  const _AppealForm({required this.fineId});
  final int fineId;

  @override
  ConsumerState<_AppealForm> createState() => _AppealFormState();
}

class _AppealFormState extends ConsumerState<_AppealForm> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {})); // live-enable the button
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _len => _controller.text.trim().length;
  bool get _valid => _len >= _kMinAppealChars;

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(kycoApiProvider)
          .appealFine(widget.fineId, _controller.text.trim());
      if (!mounted) return;
      // Refetch so the new appeal renders read-only; refresh the ledger too.
      ref.invalidate(fineDetailProvider(widget.fineId));
      ref.invalidate(finesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        // TODO-i18n: "Đã gửi khiếu nại" success toast (no ARB key).
        const SnackBar(content: Text('Đã gửi khiếu nại')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Map the two documented rejections; fall back to the server message.
  String _messageFor(ApiException e) {
    if (e.status == 409) {
      // TODO-i18n: 409 already-appealed copy (no ARB key).
      return 'Khoản phạt này đã được khiếu nại.';
    }
    if (e.status == 422) {
      // TODO-i18n: 422 too-short copy (no ARB key).
      return 'Nội dung khiếu nại phải có ít nhất $_kMinAppealChars ký tự.';
    }
    return e.message;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TODO-i18n: "Lý do khiếu nại" form label (no ARB key).
            Text('Lý do khiếu nại',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 8,
              enabled: !_submitting,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                // TODO-i18n: appeal placeholder (no ARB key).
                hintText: 'Mô tả vì sao bạn cho rằng khoản phạt này chưa hợp lý…',
                // TODO-i18n: "{n}/20 ký tự" counter (no ARB key).
                helperText: '$_len/$_kMinAppealChars ký tự',
                helperStyle: TextStyle(
                    color: _valid ? const Color(0xFF047857) : cs.onSurfaceVariant),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid && !_submitting ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    // TODO-i18n: "Gửi khiếu nại" submit label (no ARB key).
                    : const Text('Gửi khiếu nại'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppealNote extends StatelessWidget {
  const _AppealNote();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              // TODO-i18n: appeal-review note (no ARB key).
              'Đội ngũ Kyco sẽ xem xét khiếu nại của bạn trong thời gian sớm nhất.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
