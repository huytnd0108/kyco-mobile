import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'account_providers.dart';
import 'invite_screen.dart' show SignInGate;

/// `/addresses` — saved-address CRUD over `/v1/addresses`.
///
/// Backend bug MQA-2: `PATCH /v1/addresses/{id}` REPLACES every column (absent
/// keys become '' / false), so an edit always sends the full [SavedAddress]
/// write body — never a partial.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn = ref.watch(authControllerProvider).status == AuthStatus.signedIn;
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.cust2Addresses)),
        body: const SafeArea(child: SignInGate(from: '/addresses')),
      );
    }
    final async = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.cust2Addresses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l.cust2AddressAdd),
      ),
      body: SafeArea(
        child: CenteredMaxWidth(
          maxWidth: 700,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(addressesProvider);
              try {
                await ref.read(addressesProvider.future);
              } catch (_) {/* UI recovers via .when(error:) */}
            },
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 120),
                ErrorRetry(message: apiErrorText(l, e), onRetry: () => ref.invalidate(addressesProvider)),
              ]),
              data: (list) => list.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      EmptyState(icon: '📍', message: l.cust2AddressEmpty),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _AddressTile(
                        a: list[i],
                        onEdit: () => _edit(context, ref, list[i]),
                        onDelete: () => _delete(context, ref, list[i]),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, SavedAddress? a) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddressFormSheet(initial: a),
    );
    if (saved == true) ref.invalidate(addressesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SavedAddress a) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.cust2AddressDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cust2Cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.cust2AddressDelete)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(kycoApiProvider).deleteAddress(a.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(apiErrorText(l, e))));
    }
    ref.invalidate(addressesProvider);
  }
}

class _AddressTile extends StatelessWidget {
  const _AddressTile({required this.a, required this.onEdit, required this.onDelete});
  final SavedAddress a;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final line = [a.line, a.ward, a.district, a.city].where((s) => s.trim().isNotEmpty).join(', ');
    return Card(
      child: ListTile(
        onTap: onEdit,
        leading: Icon(a.isDefault ? Icons.home : Icons.place_outlined, color: cs.primary),
        title: Row(
          children: [
            Flexible(child: Text(a.label.isEmpty ? line : a.label, overflow: TextOverflow.ellipsis)),
            if (a.isDefault) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(999)),
                child: Text(l.cust2AddressDefaultBadge,
                    style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
        subtitle: a.label.isEmpty ? null : Text(line),
        trailing: IconButton(
          tooltip: l.cust2AddressDelete,
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

/// Create / edit form. Pops `true` after a successful save.
class AddressFormSheet extends ConsumerStatefulWidget {
  const AddressFormSheet({super.key, this.initial});
  final SavedAddress? initial;
  @override
  ConsumerState<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends ConsumerState<AddressFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.initial?.label ?? '');
  late final _line = TextEditingController(text: widget.initial?.line ?? '');
  late final _ward = TextEditingController(text: widget.initial?.ward ?? '');
  late final _district = TextEditingController(text: widget.initial?.district ?? '');
  late final _city = TextEditingController(text: widget.initial?.city ?? '');
  late bool _isDefault = widget.initial?.isDefault ?? false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_label, _line, _ward, _district, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The FULL object (MQA-2) — every field, edited or not.
  SavedAddress _value() => SavedAddress(
        id: widget.initial?.id ?? 0,
        label: _label.text.trim(),
        line: _line.text.trim(),
        ward: _ward.text.trim(),
        district: _district.text.trim(),
        city: _city.text.trim(),
        isDefault: _isDefault,
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = ref.read(kycoApiProvider);
    try {
      if (widget.initial == null) {
        await api.createAddress(_value());
      } else {
        await api.updateAddress(_value());
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = (e is ApiException && e.fields?['city'] != null) ? l.cust2Required : apiErrorText(l, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final insets = MediaQuery.of(context).viewInsets;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? l.cust2Required : null;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: insets.bottom + 20),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.initial == null ? l.cust2AddressAdd : l.cust2AddressEdit,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(controller: _label, decoration: InputDecoration(labelText: l.cust2AddressLabel)),
              const SizedBox(height: 10),
              TextFormField(
                  controller: _line,
                  decoration: InputDecoration(labelText: l.cust2AddressLine),
                  validator: required),
              const SizedBox(height: 10),
              TextFormField(controller: _ward, decoration: InputDecoration(labelText: l.cust2AddressWard)),
              const SizedBox(height: 10),
              TextFormField(controller: _district, decoration: InputDecoration(labelText: l.cust2AddressDistrict)),
              const SizedBox(height: 10),
              TextFormField(
                  controller: _city,
                  decoration: InputDecoration(labelText: l.cust2AddressCity),
                  validator: required),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                onChanged: _saving ? null : (v) => setState(() => _isDefault = v),
                title: Text(l.cust2AddressDefault),
              ),
              if (_error != null) ...[ErrorBanner(_error!), const SizedBox(height: 10)],
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.cust2Save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
