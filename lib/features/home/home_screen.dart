import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final auth = ref.watch(authControllerProvider);
    final signedIn = auth.status == AuthStatus.signedIn;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kyco'),
        actions: [
          if (signedIn)
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle),
              tooltip: 'Tài khoản',
              onSelected: (v) async {
                if (v == 'bookings') {
                  context.go('/bookings');
                } else if (v == 'logout') {
                  await ref.read(authControllerProvider.notifier).logout();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(auth.user?.name ?? 'Tài khoản của tôi',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const PopupMenuItem(value: 'bookings', child: Text('Đơn của tôi')),
                const PopupMenuItem(value: 'logout', child: Text('Đăng xuất')),
              ],
            )
          else
            TextButton(onPressed: () => context.go('/login'), child: const Text('Đăng nhập')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeProvider);
          await ref.read(homeProvider.future);
        },
        child: home.when(
          loading: () => const _Loading(),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            ErrorRetry(message: 'Không tải được trang chủ.\n$e', onRetry: () => ref.invalidate(homeProvider)),
          ]),
          data: (h) => _HomeBody(home: h, signedIn: signedIn, greeting: auth.user?.name),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.home, required this.signedIn, this.greeting});
  final HomeComposite home;
  final bool signedIn;
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    final cats = home.categories;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              greeting != null ? 'Xin chào, $greeting 👋' : 'Dịch vụ vệ sinh nhà cửa',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (cats.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Chưa có dịch vụ nào — sắp ra mắt.', textAlign: TextAlign.center),
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
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFEFF6FF),
        child: Center(
          child: loading
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cleaning_services, color: Color(0xFF60A5FA), size: 34),
        ),
      );
}
