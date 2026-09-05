import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/widgets.dart';
// Re-export so app.dart (which imports only messages_screen.dart) resolves the
// thread route target alongside the list.
export 'message_thread_screen.dart';

/// One conversation row. v1 is booking-derived (Risk R1: no customer-messages
/// API yet), so a "conversation" is a booking: its id, service name, status.
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

/// The conversations source. v1 derives them from `bookings()`; a future
/// `GET /v1/messages` drops in as a second impl behind this same interface —
/// the screen never changes.
abstract class MessagesRepo {
  Future<List<MessageConversation>> conversations();
}

/// v1 implementation: one conversation per booking (Bearer read).
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
  (ref) => ref.watch(messagesRepoProvider).conversations(),
);

/// `/messages` — route-gated (anon is redirected to login before reaching it).
/// v1 shows a booking-derived conversation list; each row opens a thread that
/// links to the booking detail.
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
            await ref.read(conversationsProvider.future);
          },
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ListView(children: [
              const SizedBox(height: 120),
              ErrorRetry(
                message: e.toString(),
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
            ]),
            data: (items) => items.isEmpty
                ? ListView(children: [
                    const SizedBox(height: 80),
                    EmptyState(icon: '💬', message: l.noMessages),
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
        subtitle: Text(_statusLabel(l, c.status)),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  /// Local status label (no cross-unit import). Falls back to the raw value for
  /// statuses the app doesn't know, so it keeps working if the backend adds one.
  static String _statusLabel(AppLocalizations l, String status) =>
      switch (status.toUpperCase()) {
        'PENDING' => l.statusPending,
        'CONFIRMED' => l.statusConfirmed,
        'COMPLETED' => l.statusCompleted,
        'SETTLED' => l.statusSettled,
        'CANCELLED' => l.statusCancelled,
        'BAD_DEBT' => l.statusBadDebt,
        _ => status,
      };
}
