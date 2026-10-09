import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/models.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
import 'notifications_providers.dart';

/// `/notifications` — a PUBLIC shell (web parity: notifications is public).
/// Anon sees a sign-in prompt; signed-in sees the live feed with an unread
/// badge, mark-all-read, cursor pagination and pull-to-refresh.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final signedIn =
        ref.watch(authControllerProvider).status == AuthStatus.signedIn;

    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(l.notificationsTitle)),
        body: const _SignInPrompt(),
      );
    }
    return const _NotificationsList();
  }
}

/// Anon state: prompt + a Sign-in button that carries `?from=/notifications`
/// so the user lands back here after authenticating.
class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l.signInToView,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/login?from=/notifications'),
              child: Text(l.login),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsList extends ConsumerStatefulWidget {
  const _NotificationsList();
  @override
  ConsumerState<_NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends ConsumerState<_NotificationsList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      ref.read(notificationsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(notificationsControllerProvider);
    final unread = async.valueOrNull?.unread ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.notificationsTitle),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              _UnreadBadge(unread),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: unread > 0
                ? () async {
                    final ok = await ref
                        .read(notificationsControllerProvider.notifier)
                        .markAllRead();
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(l.genericError)));
                    }
                  }
                : null,
            child: Text(l.markAllRead),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(notificationsControllerProvider);
            try { await ref.read(notificationsControllerProvider.future); } catch (_) {/* offline pull — UI recovers via .when(error:) */}
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 120),
              ErrorRetry(
                message: l.genericError,
                onRetry: () => ref.invalidate(notificationsControllerProvider),
              ),
            ]),
            data: (data) => data.items.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 80),
                    EmptyState(icon: '🔔', message: l.noResults),
                  ])
                : ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: data.items.length + (data.hasMore ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      if (i >= data.items.length) {
                        return _LoadMoreFooter(
                          loading: data.loadingMore,
                          onLoadMore: () => ref
                              .read(notificationsControllerProvider.notifier)
                              .loadMore(),
                        );
                      }
                      return _NotificationTile(data.items[i]);
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge(this.count);
  final int count;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: cs.primary, borderRadius: BorderRadius.circular(999)),
      child: Text('$count',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700)),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile(this.n);
  final NotificationItem n;

  /// Tap: mark read (POST /notifications/{id}/read), then open the in-app
  /// screen its `link` maps to (if any).
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final target = inAppRouteForLink(n.link);
    final ctrl = ref.read(notificationsControllerProvider.notifier);
    if (!n.read) {
      // Fire the mark-read before navigating; a failure never blocks the link.
      final ok = await ctrl.markRead(n.id);
      if (!ok && target == null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).genericError)));
      }
    }
    if (target != null && context.mounted) context.push(target);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final when = _formatWhen(context, n.createdAt);
    final body = (n.body?.isNotEmpty ?? false) ? n.body : null;
    final subtitleParts = <String>[?body, ?when];
    return Card(
      color: n.read ? null : cs.primaryContainer.withValues(alpha: 0.35),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: n.read ? cs.surfaceContainerHighest : cs.primary,
          child: Icon(
            n.read ? Icons.notifications_none : Icons.notifications_active,
            color: n.read ? cs.onSurfaceVariant : cs.onPrimary,
            size: 20,
          ),
        ),
        title: Text(n.title,
            style: TextStyle(
                fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
        subtitle:
            subtitleParts.isEmpty ? null : Text(subtitleParts.join('\n')),
        isThreeLine: subtitleParts.length > 1,
        onTap: () => _open(context, ref),
        trailing: inAppRouteForLink(n.link) != null
            ? Icon(Icons.chevron_right, color: cs.onSurfaceVariant)
            : null,
      ),
    );
  }

  static String? _formatWhen(BuildContext context, String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat.yMd(Localizations.localeOf(context).toString())
        .add_Hm()
        .format(dt.toLocal());
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loading, required this.onLoadMore});
  final bool loading;
  final VoidCallback onLoadMore;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(onPressed: onLoadMore, child: Text(l.loadMore)),
      ),
    );
  }
}
