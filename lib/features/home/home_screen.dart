import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../../theme/app_semantics.dart';
import '../auth/auth_controller.dart';
import 'home_providers.dart';

/// Home landing - a full web-mirror of app/[locale]/page.tsx, driven entirely by
/// the live GET /v1/home composite (categories + services + content + geo). No
/// mock data, no login prompts: guests get the full page, signed-in users get a
/// personalized greeting.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final home = ref.watch(homeProvider);
    final auth = ref.watch(authControllerProvider);
    final signedIn = auth.status == AuthStatus.signedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Kyco')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeProvider);
          try { await ref.read(homeProvider.future); } catch (_) {/* offline pull — UI recovers via .when(error:) */}
        },
        child: home.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            ErrorRetry(
              message: l.homeLoadError(e.toString()),
              onRetry: () => ref.invalidate(homeProvider),
            ),
          ]),
          data: (h) => _HomeBody(home: h, greeting: signedIn ? auth.user?.name : null),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.home, this.greeting});
  final HomeComposite home;
  final String? greeting;

  void _goSearch(BuildContext context, String q) {
    final t = q.trim();
    context.push(t.isEmpty
        ? '/services'
        : Uri(path: '/services', queryParameters: {'q': t}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cats = home.categories;
    return CenteredMaxWidth(
      maxWidth: 900,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(
              greeting: greeting,
              onSubmitted: (q) => _goSearch(context, q),
            ),
          ),
          SliverToBoxAdapter(child: SectionHeader(l.popularCategories,
              trailing: _ViewAll(onTap: () => context.push('/services')))),
          if (cats.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(message: l.noServicesYet),
            )
          else
            SliverToBoxAdapter(child: _CategoryBento(categories: cats)),
          if (home.services.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.exploreServices,
                trailing: _ViewAll(onTap: () => context.push('/services')))),
            SliverToBoxAdapter(child: _ServiceRail(services: home.services)),
          ],
          if (home.how.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.howItWorks)),
            SliverToBoxAdapter(child: _HowSection(steps: home.how)),
          ],
          if (home.why.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.whyKyco)),
            SliverToBoxAdapter(child: _WhySection(cards: home.why)),
          ],
          SliverToBoxAdapter(child: _BottomCtas()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.onSubmitted, this.greeting});
  final ValueChanged<String> onSubmitted;
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title = greeting != null ? l.helloGreeting(greeting!) : l.homeTagline;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: context.semantics.brandGradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (greeting != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l.bookNowKicker.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 16),
            SearchField(onSubmitted: onSubmitted),
          ],
        ),
      ),
    );
  }
}

class _CategoryBento extends StatelessWidget {
  const _CategoryBento({required this.categories});
  final List<ServiceCategory> categories;

  void _open(BuildContext context, ServiceCategory c) {
    final slug = c.slug;
    context.push(slug == null || slug.isEmpty
        ? '/services'
        : Uri(path: '/services', queryParameters: {'category': slug}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final shown = categories.take(5).toList(growable: false);
    final lead = shown.first;
    final rest = shown.skip(1).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: CategoryTile(lead, big: true, onTap: () => _open(context, lead)),
          ),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 4 / 3,
              children: [
                for (final c in rest)
                  CategoryTile(c, onTap: () => _open(context, c)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ServiceRail extends StatelessWidget {
  const _ServiceRail({required this.services});
  final List<ServiceSummary> services;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 296,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        itemCount: services.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final s = services[i];
          return SizedBox(
            width: 250,
            child: ServiceCard(s, onTap: () => context.push('/services/${s.id}')),
          );
        },
      ),
    );
  }
}

class _HowSection extends StatelessWidget {
  const _HowSection({required this.steps});
  final List<ContentSection> steps;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ordered = [...steps]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          for (var i = 0; i < ordered.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == ordered.length - 1 ? 0 : 12),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 32,
                        width: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                color: cs.onPrimary, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ordered[i].title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 15)),
                            if (ordered[i].body != null && ordered[i].body!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(ordered[i].body!,
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WhySection extends StatelessWidget {
  const _WhySection({required this.cards});
  final List<ContentSection> cards;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ordered = [...cards]..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          for (var i = 0; i < ordered.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == ordered.length - 1 ? 0 : 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ordered[i].title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    if (ordered[i].body != null && ordered[i].body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(ordered[i].body!,
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomCtas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push('/book-now'),
              icon: const Text('⚡', style: TextStyle(fontSize: 16)),
              label: Text(l.bookNow),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/locations'),
              icon: const Icon(Icons.location_on_outlined),
              label: Text(l.locationsTitle),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewAll extends StatelessWidget {
  const _ViewAll({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TextButton(onPressed: onTap, child: Text(l.viewAll));
  }
}
