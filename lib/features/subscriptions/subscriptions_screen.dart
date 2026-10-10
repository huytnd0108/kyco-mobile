import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/config.dart';
import '../../core/launch.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'subscriptions_providers.dart';
import 'package:kyco_mobile/core/datetime.dart';
import 'package:kyco_mobile/core/labels.dart';

/// `/subscriptions` — GUEST-FIRST. Everyone browses the public marketing plan
/// cards (`plans()`); signed-in customers additionally see their own recurring
/// subscriptions (`subscriptions()`). Creating / pausing a plan is money-
/// adjacent and OUT OF SCOPE here — an info row points members to the web.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn =
        ref.watch(authControllerProvider).status == AuthStatus.signedIn;
    final plans = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.subscriptionsTitle)),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(plansProvider);
            if (signedIn) ref.invalidate(mySubscriptionsProvider);
            await refreshQuietly(ref.read(plansProvider.future));
          },
          child: CenteredMaxWidth(
            maxWidth: 720,
            child: plans.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(children: [
                const SizedBox(height: 120),
                ErrorRetry(
                  error: e,
                  onRetry: () => ref.invalidate(plansProvider),
                ),
              ]),
              data: (planCards) => _Body(
                plans: planCards,
                signedIn: signedIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.plans, required this.signedIn});
  final List<PlanCard> plans;
  final bool signedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Own subscriptions (signed-in only)
        if (signedIn) ...[
          SectionHeader(l.mySubscriptions),
          const _MySubscriptions(),
        ],

        // Public marketing plans (guest-browsable)
        SectionHeader(l.plansTitle),
        if (plans.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: EmptyState(message: l.noResults),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final p in plans) _PlanCardTile(p),
              ],
            ),
          ),

        // Money-adjacent management lives on the web (out of scope)
        const _ManageOnWebNote(),
      ],
    );
  }
}

class _PlanCardTile extends StatelessWidget {
  const _PlanCardTile(this.plan);
  final PlanCard plan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final price = plan.priceMonthlyVnd;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (plan.body != null && plan.body!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(plan.body!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (price != null)
                  Text(
                    l.perMonth(formatVnd(price)),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
                  ),
                const Spacer(),
                if (plan.durationMonths != null)
                  _Pill(l.monthsCount(plan.durationMonths ?? 0)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MySubscriptions extends ConsumerWidget {
  const _MySubscriptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mine = ref.watch(mySubscriptionsProvider);

    return mine.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(l.cust2LoadFailed(apiErrorText(l, e))),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: EmptyState(message: l.noResults),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [for (final s in items) _SubscriptionTile(s)],
          ),
        );
      },
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile(this.sub);
  final SubscriptionItem sub;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sub.frequency.isEmpty
                        ? '#${sub.id}'
                        : subscriptionFrequencyLabel(l, sub.frequency),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusChip(sub.status),
              ],
            ),
            const SizedBox(height: 10),
            if (sub.monthlyAmountVnd > 0)
              Text(
                l.perMonth(formatVnd(sub.monthlyAmountVnd)),
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            const SizedBox(height: 10),
            // Sessions progress x/y.
            Row(
              children: [
                Icon(Icons.event_available, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(l.sessionsProgress(sub.sessionsCompleted, sub.sessionsTotal),
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
            if (sub.sessionsTotal > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (sub.sessionsCompleted / sub.sessionsTotal).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                ),
              ),
            ],
            if (sub.nextChargeAt != null && sub.nextChargeAt!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(l.nextChargeLabel(vnDate(context, sub.nextChargeAt)),
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = status.toLowerCase() == 'active';
    final bg = active ? cs.primaryContainer : cs.surfaceContainerHighest;
    final fg = active ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(subscriptionStatusLabel(AppLocalizations.of(context), status),
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _ManageOnWebNote extends ConsumerWidget {
  const _ManageOnWebNote();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Semantics(
        button: true,
        link: true,
        label: '${l.manageOnWeb}. ${l.manageOnWebOpenLabel}',
        excludeSemantics: true,
        child: Material(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: const ValueKey('manage-on-web'),
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await ref
                  .read(urlOpenerProvider)(Uri.parse('${AppConfig.webBase}/subscriptions'));
              if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.openLinkFailed)));
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 20),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 20, color: cs.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l.manageOnWeb, style: TextStyle(color: cs.primary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
