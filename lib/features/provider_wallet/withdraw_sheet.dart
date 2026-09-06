import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'provider_wallet_providers.dart';
import 'step_up_sheet.dart';

/// The withdraw/payout amount sheet. Collects the ONE user-supplied figure —
/// `amountVnd` — and pops it to the caller. It shows the server's min/max as a
/// hint and does a light client pre-check purely for UX, but NEVER decides
/// eligibility: the server validates the range, whole-đồng integrality, and the
/// live balance on the payout POST, and its verdict is what the flow surfaces.
class WithdrawSheet extends StatefulWidget {
  const WithdrawSheet({super.key, required this.balanceVnd});

  /// Server balance (display + a soft cap on the input hint) — not a gate.
  final int balanceVnd;

  @override
  State<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<WithdrawSheet> {
  late final TextEditingController _controller;
  String? _error;

  int get _cap =>
      widget.balanceVnd < kPayoutMaxVnd ? widget.balanceVnd : kPayoutMaxVnd;

  @override
  void initState() {
    super.initState();
    // Web parity: default to min(balance, 1.000.000₫).
    final preset = widget.balanceVnd < 1000000 ? widget.balanceVnd : 1000000;
    _controller = TextEditingController(text: '$preset');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = _controller.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(raw) ?? 0;
    // Soft, advisory pre-check only — the server is authoritative.
    final l = AppLocalizations.of(context);
    if (amount < kPayoutMinVnd) {
      setState(() => _error =
          l.provWalletWithdrawMinError(formatVnd(kPayoutMinVnd)));
      return;
    }
    if (amount > kPayoutMaxVnd) {
      setState(() => _error =
          l.provWalletWithdrawMaxError(formatVnd(kPayoutMaxVnd)));
      return;
    }
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
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
              Icon(Icons.payments_outlined, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.provWalletWithdrawAction,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l.provWalletSheetBalance(formatVnd(widget.balanceVnd)),
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (_error != null) ...[
            ErrorBanner(_error!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l.provWalletAmountLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.attach_money),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(
            l.provWalletAmountHint(formatVnd(kPayoutMinVnd), formatVnd(_cap)),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send),
            label: Text(l.provWalletContinue),
          ),
        ],
      ),
    );
  }
}

/// Orchestrates the full payout flow, returning a short human message for a
/// snackbar (or null when the user backed out):
///   1. collect `amountVnd` (this sheet),
///   2. `stepUpStatus()` → if not fresh, mint a grant via the step-up sheet,
///   3. `requestPayout(amountVnd)` and map the server's status:
///        201 pending · 409 in-flight · 422 insufficient (server balance) ·
///        403 step-up required. The app NEVER computes fees or net.
Future<String?> runWithdrawFlow(
  BuildContext context,
  WidgetRef ref, {
  required int balanceVnd,
}) async {
  final l = AppLocalizations.of(context);

  final amount = await showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WithdrawSheet(balanceVnd: balanceVnd),
  );
  if (amount == null) return null;

  final api = ref.read(kycoApiProvider);

  // Step-up gate — mirror the server's ordering: prove freshness BEFORE the
  // money POST. A failure here (e.g. route not yet deployed) surfaces cleanly.
  StepUpStatus status;
  try {
    status = await api.stepUpStatus();
  } on ApiException catch (e) {
    return e.isMaintenance ? l.provWalletMaintenance : e.message;
  } catch (_) {
    return l.genericError;
  }

  if (!status.fresh) {
    if (!context.mounted) return null;
    final ok = await showStepUpSheet(context,
        hasUsablePassword: status.hasUsablePassword);
    if (!ok) return null;
  }

  // Only the money POST lives in this try. A failure here is a genuine payout
  // failure and maps to the right message.
  final PayoutRequestResult result;
  try {
    result = await api.requestPayout(amount);
  } on ApiException catch (e) {
    switch (e.status) {
      case 409:
        return l.provWalletWithdrawPending;
      case 422:
        // Server-returned insufficient message already carries the live balance.
        return e.fields?['amount_vnd'] ?? e.message;
      case 403:
        return l.provWalletWithdrawStepUp;
      default:
        return e.isMaintenance ? l.provWalletMaintenance : e.message;
    }
  } catch (_) {
    return l.genericError;
  }

  // Payout CONFIRMED accepted — the money has moved. From here a dead-ref error
  // (sheet unmounted mid-POST) must NEVER be reported as a payout failure, or
  // the provider sees an error for a debit that succeeded and re-submits. Do the
  // balance/ledger refresh best-effort and always return the success message.
  try {
    ref.invalidate(walletSummaryProvider);
    ref.invalidate(walletTxnsControllerProvider);
    ref.invalidate(payoutsControllerProvider);
  } catch (_) {
    // Ref disposed after unmount — the balance refreshes on the next wallet open.
  }
  final tail = result.accountTail;
  final bank = result.bankCode;
  if (tail != null && bank != null) {
    return l.provWalletWithdrawSubmitted(
        formatVnd(result.amountVnd), bank, tail);
  }
  return l.provWalletWithdrawSubmittedNoBank(formatVnd(result.amountVnd));
}
