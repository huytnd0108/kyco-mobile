import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final home = ref.watch(homeProvider);
    final auth = ref.watch(authControllerProvider);
    final signedIn = auth.status == AuthStatus.signedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kyco'),
        actions: [
          if (!signedIn)
            TextButton(onPressed: () => context.go('/login'), child: Text(l.login)),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeProvider);
            await ref.read(homeProvider.future);
          },
          child: home.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 120),
              ErrorRetry(message: l.homeLoadError(e.toString()), onRetry: () => ref.invalidate(homeProvider)),
            ]),
            data: (h) => _HomeBody(home: h, greeting: auth.user?.name),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.home, this.greeting});
  final HomeComposite home;
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cats = home.categories;
    return CenteredMaxWidth(
      maxWidth: 1200,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                greeting != null ? l.helloGreeting(greeting!) : l.homeTagline,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (cats.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l.noServicesYet, textAlign: TextAlign.center),
              )),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _CategoryCard(cats[i]),
                  childCount: cats.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(this.category);
  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                ? Image.network(
                    category.imageUrl!,
                    fit: BoxFit.cover,
                    semanticLabel: category.name,
                    errorBuilder: (_, _, _) => const _CardPlaceholder(),
                    loadingBuilder: (c, child, p) =>
                        p == null ? child : const _CardPlaceholder(loading: true),
                  )
                : const _CardPlaceholder(),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(category.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder({this.loading = false});
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.primaryContainer,
      child: Center(
        child: loading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.cleaning_services, color: cs.onPrimaryContainer, size: 34),
      ),
    );
  }
}
