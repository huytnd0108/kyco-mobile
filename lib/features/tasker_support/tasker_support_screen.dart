import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/api/problem.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'tasker_support_providers.dart';

/// `/p/support` — 24/7 partner support (web parity: /tasker/support).
///
/// Three sections: quick-contact info rows (hotline / Zalo / email), a ticket
/// form that POSTs `createSupportTicket(...)` (existing POST /support/tickets),
/// and the tasker's own ticket history (`supportTickets()` — A7, rendered as
/// an [AsyncValue] with pull-to-refresh; a 503/error until A7 deploys shows the
/// friendly empty state, since a new tasker genuinely has none).
///
class TaskerSupportScreen extends ConsumerWidget {
  const TaskerSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.provSupportTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myTicketsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: const [
            _Subtitle(),
            SizedBox(height: 16),
            _ContactCards(),
            SizedBox(height: 24),
            _TicketForm(),
            SizedBox(height: 24),
            _MyTickets(),
          ],
        ),
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      AppLocalizations.of(context).provSupportSubtitle,
      style: TextStyle(color: cs.onSurfaceVariant),
    );
  }
}

// ── quick contact ────────────────────────────────────────────────────────────

/// Quick-contact info rows (Zalo / email). Display-only contact details (no
/// dialer/URL launch dependency added in this unit) mirroring the web
/// quick-contact grid. The hotline row is omitted until a real number exists.
class _ContactCards extends StatelessWidget {
  const _ContactCards();
  @override
  Widget build(BuildContext context) {
    // NOTE: the hotline row is intentionally omitted — no real 24/7 partner
    // number has been provisioned yet, and shipping the '1900-XXXX' placeholder
    // as a live number is a dishonest UX. Restore it only with a real number.
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        _ContactRow(
          icon: Icons.chat_bubble_outline,
          label: 'Zalo',
          value: 'Kyco Partner',
          hint: l.provSupportZaloHint,
        ),
        const SizedBox(height: 10),
        _ContactRow(
          icon: Icons.mail_outline,
          label: l.email,
          value: 'tasker@kyco.vn',
          hint: l.provSupportEmailHint,
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });
  final IconData icon;
  final String label, value, hint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(hint,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── ticket form ──────────────────────────────────────────────────────────────

/// Category values match the web select (`wallet` included per the unit spec).
const _categoryValues = <String>['wallet', 'tech', 'policy', 'other'];

const _priorityValues = <String>['normal', 'high', 'urgent'];

/// Localized form-list label for a support category value.
String _categoryLabel(AppLocalizations l, String v) => switch (v) {
      'wallet' => l.provSupportCatWallet,
      'tech' => l.provSupportCatTech,
      'policy' => l.provSupportCatPolicy,
      _ => l.provSupportCatOther,
    };

/// Localized label for a support priority value.
String _priorityLabel(AppLocalizations l, String v) => switch (v) {
      'high' => l.provSupportPrioHigh,
      'urgent' => l.provSupportPrioUrgent,
      _ => l.provSupportPrioNormal,
    };

class _TicketForm extends ConsumerStatefulWidget {
  const _TicketForm();
  @override
  ConsumerState<_TicketForm> createState() => _TicketFormState();
}

class _TicketFormState extends ConsumerState<_TicketForm> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = 'wallet';
  String _priority = 'normal';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      await ref.read(kycoApiProvider).createSupportTicket(
            subject: _subject.text.trim(),
            body: _body.text.trim().isEmpty ? null : _body.text.trim(),
            category: _category,
            priority: _priority,
          );
      if (!mounted) return;
      _subject.clear();
      _body.clear();
      setState(() {
        _category = 'wallet';
        _priority = 'normal';
      });
      // Reflect the new ticket in the history section.
      ref.invalidate(myTicketsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).provSupportSent)),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = AppLocalizations.of(context).provSupportSendError);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.provSupportFormTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: l.provSupportCategoryField),
                    items: [
                      for (final v in _categoryValues)
                        DropdownMenuItem(
                            value: v, child: Text(_categoryLabel(l, v))),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? 'wallet'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    isExpanded: true,
                    decoration:
                        InputDecoration(labelText: l.provSupportPriorityField),
                    items: [
                      for (final v in _priorityValues)
                        DropdownMenuItem(
                            value: v, child: Text(_priorityLabel(l, v))),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 'normal'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subject,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l.provSupportSubjectLabel,
                hintText: l.provSupportSubjectHint,
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 5) return l.provSupportSubjectMin;
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _body,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l.provSupportBodyLabel,
                hintText: l.provSupportBodyHint,
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l.provSupportSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── my tickets history ───────────────────────────────────────────────────────

class _MyTickets extends ConsumerWidget {
  const _MyTickets();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tickets = ref.watch(myTicketsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context).provSupportMyTickets,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        tickets.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          // A7 not deployed yet (503) or a transient read error → treat as an
          // empty history rather than a hard failure. Pull-to-refresh retries.
          error: (_, _) => _EmptyTickets(cs: cs),
          data: (rows) => rows.isEmpty
              ? _EmptyTickets(cs: cs)
              : Column(
                  children: [
                    for (final t in rows) _TicketTile(ticket: t),
                  ],
                ),
        ),
      ],
    );
  }
}

class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets({required this.cs});
  final ColorScheme cs;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined, color: cs.onSurfaceVariant, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(AppLocalizations.of(context).provSupportNoTickets,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          ],
        ),
      );
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});
  final SupportTicket ticket;

  /// Short display label for a support category value (display map — distinct
  /// from the form-list [_categoryLabel], e.g. tech → "Kỹ thuật").
  static String? _catDisplayLabel(AppLocalizations l, String? v) => switch (v) {
        'wallet' => l.provSupportCatWallet,
        'tech' => l.provSupportCatTechShort,
        'policy' => l.provSupportCatPolicy,
        'other' => l.provSupportCatOther,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final cat = _catDisplayLabel(l, ticket.category) ??
        ticket.category ??
        l.provSupportCatOther;
    final created = (ticket.createdAt ?? '');
    final createdShort = created.length >= 16 ? created.substring(0, 16) : created;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.subject ?? l.provSupportTicketNumber(ticket.id),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  createdShort.isEmpty ? cat : '$cat · $createdShort',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusChip(status: ticket.status),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final (bg, fg, label) = switch (status) {
      'open' => (
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
          l.provSupportStatusOpen
        ),
      'in_progress' => (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          l.provSupportStatusInProgress
        ),
      'resolved' => (
          cs.secondaryContainer,
          cs.onSecondaryContainer,
          l.provSupportStatusResolved
        ),
      _ => (cs.surfaceContainerHigh, cs.onSurfaceVariant, status ?? '—'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
