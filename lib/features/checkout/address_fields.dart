import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/models.dart';
import '../account/account_providers.dart';
import '../auth/auth_controller.dart';
import 'checkout_providers.dart';
import 'draft_store.dart';

/// The checkout address block — mirrors the web `checkout-address-fields.tsx`:
///
///   1. Ward dropdown (public geo)              → the legacy `district` column
///   2. Neighborhood cascade (per-ward, hidden  → the `ward` column
///      when the ward has no neighborhood data)
///   3. Street address (free text)              → `addressLine`
///   4. Notes (free text)                       → `notes`
///
/// Every change writes straight through the [DraftController] so the draft is
/// auto-saved to prefs on each keystroke / selection.
class CheckoutAddressFields extends ConsumerStatefulWidget {
  const CheckoutAddressFields({super.key, required this.serviceId, this.keys});
  final int serviceId;

  /// Optional field keys so a failed confirm can scroll to the first error.
  final CheckoutFieldKeys? keys;

  @override
  ConsumerState<CheckoutAddressFields> createState() => _CheckoutAddressFieldsState();
}

class _CheckoutAddressFieldsState extends ConsumerState<CheckoutAddressFields> {
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  DraftController get _draft =>
      ref.read(draftControllerProvider(widget.serviceId).notifier);

  @override
  void initState() {
    super.initState();
    // Seed from the (possibly restored) draft so a returning guest sees their
    // street + notes intact.
    final d = ref.read(draftControllerProvider(widget.serviceId));
    _addressCtrl = TextEditingController(text: d?.addressLine ?? '');
    _notesCtrl = TextEditingController(text: d?.notes ?? '');
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Choose one of the user's saved addresses and prefill the block. Saved
  /// `district` is the ward name the checkout dropdown shows (legacy column
  /// naming), saved `ward` is the neighborhood, `line` the street.
  Future<void> _pickSaved(List<SavedAddress> saved) async {
    final picked = await showModalBottomSheet<SavedAddress>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SavedAddressSheet(saved),
    );
    if (picked == null || !mounted) return;
    final wards = ref.read(checkoutWardsProvider).valueOrNull ?? const [];
    final wanted = picked.district.trim().toLowerCase();
    final match = wanted.isEmpty ? null : wards.where((w) => w.name.trim().toLowerCase() == wanted).firstOrNull;
    _draft.applySavedAddress(
      line: picked.line,
      wardCode: match?.code,
      wardName: match?.name,
      neighborhood: picked.ward.trim(),
    );
    setState(() => _addressCtrl.text = picked.line);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final draft = ref.watch(draftControllerProvider(widget.serviceId));
    final wardsAsync = ref.watch(checkoutWardsProvider);
    final wardCode = draft?.wardCode;
    final showErrors = ref.watch(checkoutShowErrorsProvider(widget.serviceId));

    final saved = ref.watch(authUserIdProvider) == null
        ? const <SavedAddress>[]
        : (ref.watch(addressesProvider).valueOrNull ?? const <SavedAddress>[]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 0. Saved-address shortcut (signed-in users with /addresses data).
        if (saved.isNotEmpty) ...[
          OutlinedButton.icon(
            key: const ValueKey('checkout-use-saved'),
            onPressed: () => _pickSaved(saved),
            icon: const Icon(Icons.bookmark_outline),
            label: Text(l.checkoutUseSaved),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 16),
        ],
        // 1. Ward dropdown.
        wardsAsync.when(
          loading: () => const _FieldSkeleton(),
          // Never silently drop the ward field — the funnel dead-ends otherwise
          // (Confirm stays blocked with no visible field to complete).
          error: (_, _) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(l.genericError,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(checkoutWardsProvider),
                  child: Text(l.retry),
                ),
              ],
            ),
          ),
          // KeyedSubtree: initialValue is read once, so re-create the field when a
          // saved address (or the user) changes the ward.
          data: (wards) => KeyedSubtree(
            key: ValueKey('ward-$wardCode'),
            child: DropdownButtonFormField<int>(
            key: widget.keys?.ward,
            initialValue: wards.any((w) => w.code == wardCode) ? wardCode : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.wardLabel,
              errorText: showErrors && (draft?.wardName ?? '').isEmpty ? l.cust2Required : null,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final w in wards)
                DropdownMenuItem(value: w.code, child: Text(w.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (code) {
              if (code == null) return;
              final w = wards.firstWhere((e) => e.code == code);
              _draft.setWard(w.code, w.name);
            },
          )),
        ),
        const SizedBox(height: 16),

        // 2. Neighborhood cascade — only when the ward has crawled data.
        if (wardCode != null) _NeighborhoodField(serviceId: widget.serviceId, wardCode: wardCode),

        // 3. Street address.
        TextField(
          key: widget.keys?.street,
          controller: _addressCtrl,
          textInputAction: TextInputAction.next,
          onChanged: _draft.setAddressLine,
          decoration: InputDecoration(
            labelText: l.addressLineLabel,
            errorText: showErrors && (draft?.addressLine ?? '').trim().isEmpty ? l.cust2Required : null,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Notes.
        TextField(
          controller: _notesCtrl,
          minLines: 3,
          maxLines: 5,
          onChanged: _draft.setNotes,
          decoration: InputDecoration(
            labelText: l.notesLabel,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

/// The cascading neighborhood dropdown. Renders nothing while loading OR when
/// the ward has no neighborhood data (web parity: hide the empty cascade).
class _NeighborhoodField extends ConsumerWidget {
  const _NeighborhoodField({required this.serviceId, required this.wardCode});
  final int serviceId;
  final int wardCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final draft = ref.watch(draftControllerProvider(serviceId));
    final async = ref.watch(neighborhoodsProvider(wardCode));

    return async.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final current = draft?.neighborhood;
        final value = list.any((n) => n.name == current) ? current : null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            key: ValueKey('neighborhood-$value'),
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.neighborhoodLabel,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final n in list)
                DropdownMenuItem(value: n.name, child: Text(n.name, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (name) {
              if (name != null) {
                ref.read(draftControllerProvider(serviceId).notifier).setNeighborhood(name);
              }
            },
          ),
        );
      },
    );
  }
}

class _FieldSkeleton extends StatelessWidget {
  const _FieldSkeleton();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _SavedAddressSheet extends StatelessWidget {
  const _SavedAddressSheet(this.addresses);
  final List<SavedAddress> addresses;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(l.checkoutSavedTitle, style: Theme.of(context).textTheme.titleLarge),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final a in addresses)
                  ListTile(
                    key: ValueKey('saved-address-${a.id}'),
                    leading: Icon(a.isDefault ? Icons.home_outlined : Icons.place_outlined,
                        color: cs.onSurfaceVariant),
                    title: Text(a.label.isEmpty ? a.line : a.label),
                    subtitle: Text(
                        [a.line, a.ward, a.district, a.city].where((s) => s.trim().isNotEmpty).join(', ')),
                    trailing: a.isDefault ? Text(l.checkoutSavedDefault) : null,
                    onTap: () => Navigator.of(context).pop(a),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
