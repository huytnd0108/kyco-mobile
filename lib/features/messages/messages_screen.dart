import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/widgets.dart';
import '../auth/auth_controller.dart';
// Re-export so app.dart (which imports only messages_screen.dart) resolves the
// thread route target alongside the list.
export 'message_thread_screen.dart';
import 'package:kyco_mobile/core/labels.dart';

/// One conversation row. A booking IS the conversation (the backend threads
/// messages per booking: `/bookings/{id}/messages`), so a row is a booking: its
/// id, service name and status.
class MessageConversation {
  const MessageConversation({
    required this.bookingId,
    this.serviceName,
    required this.status,
  });
  final int bookingId;
  final String? serviceName;
  final String status;
}

/// The conversations source: one per booking. There is no cross-booking inbox
/// endpoint, so the list is the bookings list.
abstract class MessagesRepo {
  Future<List<MessageConversation>> conversations();
}

/// One conversation per booking (Bearer read).
class BookingsDerivedMessagesRepo implements MessagesRepo {
  BookingsDerivedMessagesRepo(this._api);
  final KycoApi _api;

  @override
  Future<List<MessageConversation>> conversations() async {
    final bookings = await _api.bookings();
    return [
      for (final b in bookings)
        MessageConversation(
          bookingId: b.id,
          serviceName: b.serviceName,
          status: b.status,
        ),
    ];
  }
}

final messagesRepoProvider = Provider<MessagesRepo>(
  (ref) => BookingsDerivedMessagesRepo(ref.watch(kycoApiProvider)),
);

/// The signed-in customer's conversations. The `/messages` route is gated
/// (redirect handles anon), so this is only ever read while signed in.
final conversationsProvider =
    FutureProvider.autoDispose<List<MessageConversation>>(
  (ref) {
    // Refetch on account switch; drop (no Bearer call) once signed out.
    if (ref.watch(authUserIdProvider) == null) return Future.value(const <MessageConversation>[]);
    return ref.watch(messagesRepoProvider).conversations();
  },
);

/// `/messages` - route-gated (anon is redirected to login before reaching it).
/// One row per booking; each opens that booking's real chat thread.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.messagesTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(conversationsProvider);
            try { await ref.read(conversationsProvider.future); } catch (_) {/* offline pull — UI recovers via .when(error:) */}
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 120),
              ErrorRetry(
                error: e,
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
            ]),
            data: (items) => items.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 80),
                    EmptyState(icon: Icons.chat_bubble_outline, message: l.chatNoConversations),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _ConversationTile(items[i]),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile(this.c);
  final MessageConversation c;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        onTap: () => context.push('/messages/${c.bookingId}'),
        leading: CircleAvatar(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FittedBox(child: Text('#${c.bookingId}')),
          ),
        ),
        title: Text(c.serviceName ?? l.bookingNumber(c.bookingId)),
        subtitle: Text(bookingStatusLabel(l, c.status)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
