import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/core/datetime.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
import '../../core/ui/not_found_screen.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import '../home/home_providers.dart';
import '../messages/messages_screen.dart' show conversationsProvider;
import 'address_fields.dart';
import 'checkout_providers.dart';
import 'draft_store.dart';

/// GUEST-COMPOSED checkout. Data is composed from PUBLIC reads only
/// (`serviceDetail` + `locationsTree`) so an anonymous visitor can fill the
/// entire form; the login wall is IN-SCREEN, at confirm. Booking creation is
/// cash-only (`toCreateBody()` → paymentMethod:'cash', never an amount).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.serviceId});
  final int serviceId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _seeded = false;
  bool _submitting = false;
  final _keys = CheckoutFieldKeys();

  int get _id => widget.serviceId;

  DraftController get _draftCtrl => ref.read(draftControllerProvider(_id).notifier);

  /// Seed (or restore) the draft once the service loads. Surfaces a "draft
  /// restored" hint when a persisted draft was found (a returning guest).
  void _seedOnce(ServiceDetail service) {
    if (_seeded) return;
    _seeded = true;
    final notifier = _draftCtrl;
    final wasPersisted = notifier.hadPersistedDraft;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.ensureSeeded(service);
      if (wasPersisted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).draftRestored)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // A malformed deep link (/checkout/abc) parses to 0: not found, no request.
    if (_id <= 0) return const NotFoundScreen();
    final serviceAsync = ref.watch(checkoutServiceProvider(_id));

    return Scaffold(
      appBar: AppBar(title: Text(l.checkoutTitle)),
      body: serviceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetry(
          error: e,
          onRetry: () => ref.invalidate(checkoutServiceProvider(_id)),
        ),
        data: (service) {
          _seedOnce(service);
          return _CheckoutBody(serviceId: _id, service: service, keys: _keys);
        },
      ),
      bottomNavigationBar: serviceAsync.maybeWhen(
        data: (service) => _SubmitBar(
          serviceId: _id,
          service: service,
          submitting: _submitting,
          onConfirm: () => _confirm(service),
        ),
        orElse: () => null,
      ),
    );
  }

  Future<void> _confirm(ServiceDetail service) async {
    final l = AppLocalizations.of(context);
    final draft = ref.read(draftControllerProvider(_id));
    if (draft == null) return;
    // Light client guard — the server is authoritative, but empty required
    // fields shouldn't cost a round-trip. Missing fields get an inline error
    // each (readable by a screen reader) and the first one is scrolled to.
    final firstMissing = _firstMissingField(draft);
    if (firstMissing != null) {
      ref.read(checkoutShowErrorsProvider(_id).notifier).state = true;
      final ctx = firstMissing.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.2);
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref.read(kycoApiProvider).createBooking(draft);
      // A booking now exists (new OR idempotent replay): every list that shows
      // bookings must refetch — tab shells keep those screens mounted.
      ref.invalidate(bookingsProvider);
      ref.invalidate(conversationsProvider);
      ref.invalidate(bookingDetailProvider(result.bookingId));
      if (!mounted) return;
      if (result.bookingId <= 0) {
        // The response carried no usable booking id: never navigate to
        // /bookings/0. Keep the draft and point the user at the list.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.bookingCreateUnconfirmed)));
        return;
      }
      if (result.kind == 'dedup') {
        // Idempotent replay — the booking already exists; jump straight to it.
        await _draftCtrl.clear();
        if (mounted) context.go('/bookings/${result.bookingId}');
        return;
      }
      await _draftCtrl.clear();
      if (!mounted) return;
      await _showSuccess(result);
      // Draft is cleared and the _seeded latch blocks a re-seed, so the checkout
      // underneath is now blank and inert. Leave for the booking on ANY sheet
      // dismissal — tap or swipe — instead of stranding the user on it. (When the
      // in-sheet button navigated, this screen is already gone → mounted false.)
      if (mounted) context.go('/bookings/${result.bookingId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorText(l, e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The key of the first required field that is empty (page order), else null.
  GlobalKey? _firstMissingField(BookingDraft draft) {
    if ((draft.scheduledDate ?? '').isEmpty) return _keys.date;
    if ((draft.scheduledTime ?? '').isEmpty) return _keys.time;
    if ((draft.wardName ?? '').isEmpty) return _keys.ward;
    if (draft.addressLine.trim().isEmpty) return _keys.street;
    return null;
  }

  Future<void> _showSuccess(CreateBookingResult r) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SuccessSheet(result: r),
    );
  }
}

class _CheckoutBody extends ConsumerWidget {
  const _CheckoutBody({required this.serviceId, required this.service, required this.keys});
  final int serviceId;
  final ServiceDetail service;
  final CheckoutFieldKeys keys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final anon = ref.watch(authControllerProvider).status != AuthStatus.signedIn;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (anon) ...[
          _AnonBanner(serviceId: serviceId),
          const SizedBox(height: 16),
        ],
        _ServiceHero(service: service),
        const SizedBox(height: 20),
        _SlotSection(serviceId: serviceId, keys: keys),
        const SizedBox(height: 20),
        Text(l.addressLineLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        CheckoutAddressFields(serviceId: serviceId, keys: keys),
        const SizedBox(height: 20),
        const _DeferredPaymentNotice(),
      ],
    );
  }
}

/// Anonymous info banner + Sign up / Sign in affordances. The draft is already
/// auto-saved, so signing in returns the guest here with every field intact.
class _AnonBanner extends StatelessWidget {
  const _AnonBanner({required this.serviceId});
  final int serviceId;

  String get _from => Uri.encodeQueryComponent('/checkout/$serviceId');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.guestCheckoutNotice,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push('/signup?from=$_from'),
                  child: Text(l.createAccount),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push('/login?from=$_from'),
                  child: Text(l.login),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.service});
  final ServiceDetail service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (service.category != null && service.category!.isNotEmpty)
          Text(service.category!.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.primary, letterSpacing: 0.8)),
        const SizedBox(height: 4),
        Text(service.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        // Wrap, not Row: price + duration wrap onto two lines at large font sizes.
        Wrap(
          spacing: 8,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PriceText(service.basePriceVnd, from: true),
            if (service.durationMinutes != null)
              Text('· ${l.minutesShort(service.durationMinutes!)}',
                  style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 4),
        Text(l.moneyEstimateNote,
            key: const ValueKey('checkout-estimate-note'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        if (service.description != null && service.description!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(service.description!, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ],
    );
  }
}

/// Free-form date + time (native pickers, no availability call — web parity).
class _SlotSection extends ConsumerWidget {
  const _SlotSection({required this.serviceId, required this.keys});
  final int serviceId;
  final CheckoutFieldKeys keys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final draft = ref.watch(draftControllerProvider(serviceId));
    final ctrl = ref.read(draftControllerProvider(serviceId).notifier);
    final showErrors = ref.watch(checkoutShowErrorsProvider(serviceId));
    String? errorFor(String? v) => showErrors && (v ?? '').isEmpty ? l.cust2Required : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PickerTile(
            key: keys.date,
            errorText: errorFor(draft?.scheduledDate),
            label: l.dateLabel,
            value: draft?.scheduledDate,
            display: (draft?.scheduledDate ?? '').isEmpty
                ? null
                : vnDateKeyLabel(context, draft!.scheduledDate),
            icon: Icons.calendar_today,
            onTap: () async {
              // "Today" is the Vietnam calendar date, not the device's.
              final now = vnToday();
              final initial = _parseDate(draft?.scheduledDate) ?? now;
              final picked = await showDatePicker(
                context: context,
                initialDate: initial.isBefore(now) ? now : initial,
                firstDate: now,
                lastDate: now.add(const Duration(days: 365)),
              );
              if (picked != null) ctrl.setDate(vnDateKey(picked));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PickerTile(
            key: keys.time,
            errorText: errorFor(draft?.scheduledTime),
            label: l.timeLabel,
            value: draft?.scheduledTime,
            display: _parseTime(draft?.scheduledTime) == null
                ? null
                : MaterialLocalizations.of(context)
                    .formatTimeOfDay(_parseTime(draft?.scheduledTime)!),
            icon: Icons.schedule,
            onTap: () async {
              final t = _parseTime(draft?.scheduledTime) ?? const TimeOfDay(hour: 9, minute: 0);
              final picked = await showTimePicker(context: context, initialTime: t);
              if (picked != null) {
                final hh = picked.hour.toString().padLeft(2, '0');
                final mm = picked.minute.toString().padLeft(2, '0');
                ctrl.setTime('$hh:$mm');
              }
            },
          ),
        ),
      ],
    );
  }

  static DateTime? _parseDate(String? v) => (v == null || v.isEmpty) ? null : DateTime.tryParse(v);
  static TimeOfDay? _parseTime(String? v) {
    if (v == null || !v.contains(':')) return null;
    final p = v.split(':');
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return (h == null || m == null) ? null : TimeOfDay(hour: h, minute: m);
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile(
      {super.key, required this.label, required this.value, required this.icon, required this.onTap, this.display, this.errorText});
  final String? errorText;
  final String label;
  final String? value;

  /// Localized text shown for [value] (the wire value stays `yyyy-MM-dd` / `HH:mm`).
  final String? display;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasValue = value != null && value!.isNotEmpty;
    return Semantics(
      button: true,
      label: label,
      value: hasValue ? (display ?? value) : null,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, size: 18),
        ),
        child: Text(
          hasValue ? (display ?? value!) : '—',
          style: TextStyle(color: hasValue ? cs.onSurface : cs.onSurfaceVariant),
        ),
      ),
    ));
  }
}

class _DeferredPaymentNotice extends StatelessWidget {
  const _DeferredPaymentNotice();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: cs.onSecondaryContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.deferredPaymentNotice,
                style: TextStyle(color: cs.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// The sticky submit bar — subtotal on the left, the login-gated submit slot on
/// the right. Anon → "Sign in to confirm"; signed-in → "Confirm booking".
class _SubmitBar extends ConsumerWidget {
  const _SubmitBar({
    required this.serviceId,
    required this.service,
    required this.submitting,
    required this.onConfirm,
  });
  final int serviceId;
  final ServiceDetail service;
  final bool submitting;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final anon = ref.watch(authControllerProvider).status != AuthStatus.signedIn;
    final from = Uri.encodeQueryComponent('/checkout/$serviceId');
    // Server quote (new backend) once the draft is complete; else the estimate.
    final draft = ref.watch(draftControllerProvider(serviceId));
    final quote = isDraftQuotable(draft)
        ? ref.watch(checkoutQuoteProvider((serviceId: serviceId, sig: quoteSignature(draft!)))).valueOrNull
        : null;

    return StickyBottomCta(
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Before the booking exists only the service BASE price is known;
              // the server adds surcharges / compensation fees at create time.
              Text(quote != null ? l.moneyQuoteLabel : l.moneyEstimateLabel,
                  key: const ValueKey('checkout-total-label'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              PriceText(quote?.totalVnd ?? service.basePriceVnd, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: anon
                ? FilledButton(
                    onPressed: () => context.push('/login?from=$from'),
                    child: Text(l.signInToConfirm, textAlign: TextAlign.center),
                  )
                : FilledButton(
                    onPressed: submitting ? null : onConfirm,
                    child: submitting
                        ? const SizedBox(
                            height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.confirmBooking, textAlign: TextAlign.center),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Success sheet after a 201 `created`. Shows the confirmation code + total and
/// the cash-after-service note. `payUrl`/`qrCodeUrl` are shown as INFO TEXT
/// only — never opened (out of scope: no in-app payment beyond cash).
class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.result});
  final CreateBookingResult result;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final r = result;
    final hasPayInfo = (r.payUrl != null && r.payUrl!.isNotEmpty) ||
        (r.qrCodeUrl != null && r.qrCodeUrl!.isNotEmpty);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle, color: cs.primary, size: 48),
          const SizedBox(height: 12),
          Text(l.bookingCreated(r.bookingId),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          if (r.confirmationCode != null && r.confirmationCode!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${l.confirmationCode}: ${r.confirmationCode}',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontFeatures: const []),
            ),
          ],
          const SizedBox(height: 16),
          if (r.totalVnd != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.totalLabel, style: TextStyle(color: cs.onSurfaceVariant)),
                PriceText(r.totalVnd!, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          const SizedBox(height: 12),
          Text(l.deferredPaymentNotice, style: TextStyle(color: cs.onSurfaceVariant)),
          if (hasPayInfo) ...[
            const SizedBox(height: 8),
            Text(
              l.onlinePaymentOnWeb,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/bookings/${r.bookingId}');
            },
            child: Text(l.viewDetails),
          ),
        ],
      ),
    );
  }
}
