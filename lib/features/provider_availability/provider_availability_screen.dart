import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../../theme/app_semantics.dart';
import 'provider_availability_providers.dart';

/// Weekday short label (e.g. `CN`/`Sun`), indexed by `dow % 7` (0 = Sunday).
String _weekdayShort(AppLocalizations l, int dow) {
  switch (dow % 7) {
    case 0:
      return l.provAvailWeekdayShort0;
    case 1:
      return l.provAvailWeekdayShort1;
    case 2:
      return l.provAvailWeekdayShort2;
    case 3:
      return l.provAvailWeekdayShort3;
    case 4:
      return l.provAvailWeekdayShort4;
    case 5:
      return l.provAvailWeekdayShort5;
    default:
      return l.provAvailWeekdayShort6;
  }
}

/// Weekday long label (e.g. `Chủ nhật`/`Sunday`), indexed by `dow % 7` (0 = Sunday).
String _weekdayLong(AppLocalizations l, int dow) {
  switch (dow % 7) {
    case 0:
      return l.provAvailWeekdayLong0;
    case 1:
      return l.provAvailWeekdayLong1;
    case 2:
      return l.provAvailWeekdayLong2;
    case 3:
      return l.provAvailWeekdayLong3;
    case 4:
      return l.provAvailWeekdayLong4;
    case 5:
      return l.provAvailWeekdayLong5;
    default:
      return l.provAvailWeekdayLong6;
  }
}

/// `620` minutes → `10 giờ 20` / `10h 20m`; whole hours drop the minutes (ICU plural).
String _hoursLabel(AppLocalizations l, int minutes) =>
    l.provAvailHours(minutes ~/ 60, minutes % 60);


/// Provider · Availability — a weekly recurring-slot grid editor plus per-date
/// overrides, backed by [availabilityProvider] (GET, §A10 pending) and saved via
/// [KycoApiProvider.setWeeklyAvailability] / [KycoApiProvider.setDateAvailability].
/// No money is displayed or moved here — schedule only.
class ProviderAvailabilityScreen extends ConsumerWidget {
  const ProviderAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = AppLocalizations.of(context);
    final async = ref.watch(availabilityProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.provAvailabilityTitle),
        actions: [
          IconButton(
            tooltip: l.retry,
            onPressed: () => ref.invalidate(availabilityProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // §A10: GET pending → the API throws; show a friendly retryable state.
          error: (e, _) => ErrorRetry(
            message: s.provAvailLoadError,
            onRetry: () => ref.invalidate(availabilityProvider),
          ),
          data: (week) => _Editor(week: week),
        ),
      ),
    );
  }
}

/// Stateful editor seeded from the loaded [AvailabilityWeek]. Holds a mutable
/// copy so edits render optimistically; a successful save invalidates the
/// provider so the next read re-seeds from the server.
class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.week});
  final AvailabilityWeek week;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late Map<int, List<AvailabilitySlot>> _weekly;
  late List<AvailabilityDateOverride> _dates;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(covariant _Editor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A pull-refresh or post-save invalidate re-reads the provider and delivers
    // a NEW AvailabilityWeek instance into this kept-alive editor. Without a
    // re-seed here the grid keeps its stale optimistic copy: cross-device edits
    // stay invisible and a cancelled save-conflict leaves the unsaved grid
    // looking saved. Re-seed on every fresh fetch so the server stays canonical.
    if (!identical(oldWidget.week, widget.week)) {
      _seed();
    }
  }

  void _seed() {
    _weekly = {
      for (final dow in kAvailabilityDows)
        dow: List<AvailabilitySlot>.from(widget.week.weekly[dow] ?? const []),
    };
    _dates = [...widget.week.dates]..sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _refresh() async {
    ref.invalidate(availabilityProvider);
    // Swallow the reload error — an offline pull would otherwise throw an
    // uncaught ApiException; the UI already recovers via async.when(error:).
    try {
      await ref.read(availabilityProvider.future);
    } catch (_) {/* offline pull — UI recovers via async.when(error:) */}
  }

  // ── weekly grid save ────────────────────────────────────────────────────
  Future<void> _saveWeekly({bool force = false}) async {
    final s = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final res = await ref.read(kycoApiProvider).setWeeklyAvailability(_weekly, force: force);
      if (!mounted) return;
      if (!res.saved) {
        // Conflicts → offer the force-overwrite confirm; otherwise the server
        // declined for another reason and this is NOT a success — never snack
        // "Đã lưu" on a saved:false response.
        if (res.conflicts.isNotEmpty) {
          final ok = await _confirmConflict(res.conflicts);
          if (ok == true) { await _saveWeekly(force: true); }
          return;
        }
        _snack(s.provAvailSaveFailed, error: true);
        return;
      }
      _snack(s.provAvailSaved);
      ref.invalidate(availabilityProvider);
    } catch (_) {
      if (mounted) _snack(s.provAvailSaveFailed, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── per-date override save ──────────────────────────────────────────────
  Future<void> _saveDate(String date, List<AvailabilitySlot> slots, {bool force = false}) async {
    final s = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final res = await ref.read(kycoApiProvider).setDateAvailability(date, slots, force: force);
      if (!mounted) return;
      if (!res.saved) {
        if (res.conflicts.isNotEmpty) {
          final ok = await _confirmConflict(res.conflicts);
          if (ok == true) { await _saveDate(date, slots, force: true); }
          return;
        }
        _snack(s.provAvailSaveFailed, error: true);
        return;
      }
      setState(() {
        _dates.removeWhere((d) => d.date == date);
        _dates.add(AvailabilityDateOverride(date: date, slots: slots));
        _dates.sort((a, b) => a.date.compareTo(b.date));
      });
      _snack(s.provAvailSaved);
      ref.invalidate(availabilityProvider);
    } catch (_) {
      if (mounted) _snack(s.provAvailSaveFailed, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirmConflict(List<int> jobIds) {
    final s = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(s.provAvailConflictTitle),
        content: Text(s.provAvailConflictBody(jobIds.map((e) => '#$e').join(', '))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.provAvailCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.provAvailSaveAnyway)),
        ],
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? cs.errorContainer : null,
    ));
  }

  Future<void> _editDay(int dow) async {
    final slots = await showModalBottomSheet<List<AvailabilitySlot>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SlotSheet(
        title: _weekdayLong(AppLocalizations.of(context), dow),
        initial: _weekly[dow] ?? const [],
      ),
    );
    if (slots == null) return;
    setState(() => _weekly[dow] = slots);
    await _saveWeekly();
  }

  Future<void> _addOverride() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDate: now,
    );
    if (date == null || !mounted) return;
    final iso = _iso(date);
    final existing = _dates.where((d) => d.date == iso).toList();
    final slots = await showModalBottomSheet<List<AvailabilitySlot>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SlotSheet(
        title: iso,
        initial: existing.isEmpty ? const [] : existing.first.slots,
      ),
    );
    if (slots == null) return;
    await _saveDate(iso, slots);
  }

  Future<void> _editOverride(AvailabilityDateOverride o) async {
    final slots = await showModalBottomSheet<List<AvailabilitySlot>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SlotSheet(title: o.date, initial: o.slots),
    );
    if (slots == null) return;
    await _saveDate(o.date, slots);
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: Stack(
        children: [
          CenteredMaxWidth(
            maxWidth: 720,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _FreeHoursCard(minutes: weeklyFreeMinutes(_weekly)),
                const SizedBox(height: 24),
                _SectionHeader(title: s.provAvailWeeklyHeading, subtitle: s.provAvailWeeklySub),
                const SizedBox(height: 8),
                for (final dow in kAvailabilityDows)
                  _DayRow(
                    dow: dow,
                    slots: _weekly[dow] ?? const [],
                    onTap: _busy ? null : () => _editDay(dow),
                  ),
                const SizedBox(height: 24),
                _SectionHeader(title: s.provAvailOverridesHeading, subtitle: s.provAvailOverridesSub),
                const SizedBox(height: 8),
                if (_dates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      s.provAvailEmptyOverrides,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  for (final o in _dates)
                    _OverrideRow(
                      item: o,
                      onTap: _busy ? null : () => _editOverride(o),
                    ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _addOverride,
                  icon: const Icon(Icons.add),
                  label: Text(s.provAvailAddOverride),
                ),
              ],
            ),
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _FreeHoursCard extends StatelessWidget {
  const _FreeHoursCard({required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final sem = context.semantics;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: sem.infoContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: sem.onInfoContainer),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.provAvailFreeHoursTitle, style: TextStyle(color: sem.onInfoContainer)),
                const SizedBox(height: 4),
                Text(
                  _hoursLabel(s, minutes),
                  style: TextStyle(
                    color: sem.onInfoContainer,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.dow, required this.slots, this.onTap});
  final int dow;
  final List<AvailabilitySlot> slots;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final empty = slots.isEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  _weekdayShort(s, dow),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: empty
                    ? Text(s.provAvailNoSlots, style: TextStyle(color: cs.onSurfaceVariant))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final slot in slots) _SlotChip(label: formatSlot(slot))],
                      ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverrideRow extends StatelessWidget {
  const _OverrideRow({required this.item, this.onTap});
  final AvailabilityDateOverride item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final off = item.slots.isEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.event, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.date, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (off)
                      Text(s.provAvailUnavailableFull, style: TextStyle(color: cs.onSurfaceVariant))
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [for (final slot in item.slots) _SlotChip(label: formatSlot(slot))],
                      ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final sem = context.semantics;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: sem.successContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: sem.onSuccessContainer, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

/// Bottom-sheet slot editor: add / remove `{start,end}` rows for one day or one
/// date. Returns the edited list (may be empty = "off"), or null on cancel.
class _SlotSheet extends StatefulWidget {
  const _SlotSheet({required this.title, required this.initial});
  final String title;
  final List<AvailabilitySlot> initial;

  @override
  State<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends State<_SlotSheet> {
  late List<AvailabilitySlot> _slots;

  @override
  void initState() {
    super.initState();
    _slots = [...widget.initial]..sort((a, b) => a.start.compareTo(b.start));
  }

  Future<void> _pick(int index, bool isStart) async {
    final s = AppLocalizations.of(context);
    final current = isStart ? _slots[index].start : _slots[index].end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (current ~/ 60) % 24, minute: current % 60),
    );
    if (picked == null) return;
    final mins = picked.hour * 60 + picked.minute;
    setState(() {
      final slot = _slots[index];
      _slots[index] = AvailabilitySlot(
        start: isStart ? mins : slot.start,
        end: isStart ? slot.end : mins,
      );
    });
    final slot = _slots[index];
    if (slot.end <= slot.start && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.provAvailSlotOrderError)));
    }
  }

  void _add() {
    setState(() {
      final last = _slots.isEmpty ? 8 * 60 : _slots.last.end;
      _slots.add(AvailabilitySlot(start: last, end: (last + 120).clamp(0, 24 * 60)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final valid = _slots.every((sl) => sl.end > sl.start);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (_slots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(s.provAvailUnavailableFull, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          for (var i = 0; i < _slots.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(i, true),
                      child: Text('${s.provAvailStart}: ${formatMinutes(_slots[i].start)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pick(i, false),
                      child: Text('${s.provAvailEnd}: ${formatMinutes(_slots[i].end)}'),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _slots.removeAt(i)),
                    icon: Icon(Icons.delete_outline, color: cs.error),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(s.provAvailAddSlot),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(s.provAvailCancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: valid ? () => Navigator.pop(context, _slots) : null,
                  child: Text(s.provAvailSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
