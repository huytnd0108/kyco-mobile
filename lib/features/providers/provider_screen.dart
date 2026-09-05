import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/api/problem.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'provider_providers.dart';

/// `/providers/:id` — the PUBLIC pre-booking view of a partner. Fully guest-
/// browsable (`providerPublic(id)`, anon). A 404 (unknown / inactive /
/// unverified) renders a friendly not-found rather than an error.
class ProviderScreen extends ConsumerWidget {
  const ProviderScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(providerPublicProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(l.providerTitle)),
      body: SafeArea(
        top: false,
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            final notFound = e is ApiException && e.status == 404;
            if (notFound) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  // TODO-i18n: "Partner not found" (no ARB key) — reuse noResults copy
                  child: EmptyState(icon: '🔍', message: l.partnerNotFound),
                ),
              );
            }
            return ErrorRetry(
              message: l.homeLoadError(e.toString()),
              onRetry: () => ref.invalidate(providerPublicProvider(id)),
            );
          },
          data: (p) => _ProfileBody(profile: p),
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});
  final ProviderPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final avatar = profile.avatarUrl;

    return CenteredMaxWidth(
      maxWidth: 600,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: cs.primaryContainer,
                foregroundImage: (avatar != null && avatar.isNotEmpty)
                    ? NetworkImage(avatar)
                    : null,
                child: Text(
                  _initials(profile.displayName),
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TierBadge(profile.tier),
                        if (profile.verified) _VerifiedBadge(label: l.verifiedBadge),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          RatingStars(
            profile.reviewSummary.average > 0
                ? profile.reviewSummary.average
                : profile.rating,
            count: profile.reviewSummary.count,
            size: 22,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  value: '${profile.jobsCompleted}',
                  label: l.jobsCompleted(profile.jobsCompleted),
                ),
              ),
              if (profile.joinedAt != null && profile.joinedAt!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.calendar_today_outlined,
                    value: _year(profile.joinedAt!),
                    label: l.memberSince(_shortDate(profile.joinedAt!)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge(this.tier);
  final String tier;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // tier is a backend reputation enum (bronze/silver/gold/…) — shown raw,
    // capitalized. No localized mapping exists yet.
    final label = tier.isEmpty
        ? ''
        : '${tier[0].toUpperCase()}${tier.substring(1)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: cs.onSecondaryContainer, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 24),
          const SizedBox(height: 10),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
}

String _year(String iso) {
  final dt = DateTime.tryParse(iso);
  return dt != null ? '${dt.year}' : (iso.length >= 4 ? iso.substring(0, 4) : iso);
}

/// Best-effort ISO to dd/MM/yyyy. Falls back to the first 10 chars.
String _shortDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso.length >= 10 ? iso.substring(0, 10) : iso;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
}
