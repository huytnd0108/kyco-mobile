import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/problem.dart';
import '../../core/datetime.dart';
import '../../core/di.dart';
import '../../core/models.dart';
import '../../core/ui/error_text.dart';
import '../../core/visible_poller.dart';
import '../../core/widgets.dart';
import '../home/home_providers.dart';

/// How often a visible thread re-reads the booking composite for new messages.
const Duration kChatPollInterval = Duration(seconds: 15);

/// The booking's chat thread (UX-M11).
///
/// Backend contract at f036f85: the thread is READ from the owner-scoped
/// `GET /v1/bookings/{id}/page` composite (`messages: [{id, fromRole, body,
/// createdAt}]`, oldest first) and WRITTEN with `POST /v1/bookings/{id}/messages
/// {body}` (participant only, <= 4000 chars; `fromRole` is derived server-side).
/// There is no separate list endpoint, so polling re-reads the composite while
/// the screen is visible.
class MessageThreadScreen extends ConsumerStatefulWidget {
  const MessageThreadScreen({super.key, required this.id});

  /// The booking id whose thread this is.
  final int id;

  @override
  ConsumerState<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends ConsumerState<MessageThreadScreen> {
  final _input = TextEditingController();
  late final VisiblePoller _poller;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _poller = VisiblePoller(
      interval: kChatPollInterval,
      isVisible: () => mounted && !_sending && TickerMode.valuesOf(context).enabled,
      onTick: () => ref.invalidate(bookingDetailProvider(widget.id)),
    )..start();
  }

  @override
  void dispose() {
    _poller.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return; // in-flight guard: a double tap never double-posts
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(kycoApiProvider).sendBookingMessage(widget.id, text);
      _input.clear();
      ref.invalidate(bookingDetailProvider(widget.id));
      try {
        await ref.read(bookingDetailProvider(widget.id).future);
      } catch (_) {/* the poll / pull-to-refresh recovers */}
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(l, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(bookingDetailProvider(widget.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(l.bookingNumber(widget.id)),
        actions: [
          IconButton(
            tooltip: l.viewDetails,
            icon: const Icon(Icons.receipt_long),
            onPressed: () => context.push('/bookings/${widget.id}'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: async.when(
                skipLoadingOnReload: true, // polling must not flash a spinner
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => (e is ApiException && (e.code == 'NOT_FOUND' || e.status == 404))
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline,
                        message: l.bookingNotFound(widget.id),
                        action: OutlinedButton(
                          onPressed: () => context.go('/bookings'),
                          child: Text(l.backToMyBookings),
                        ),
                      )
                    : ErrorRetry(
                        error: e,
                        onRetry: () => ref.invalidate(bookingDetailProvider(widget.id)),
                      ),
                data: (b) => b.messages.isEmpty
                    ? EmptyState(
                        key: const ValueKey('chat-empty'),
                        icon: Icons.chat_bubble_outline,
                        message: l.chatEmpty,
                      )
                    : _MessageList(messages: b.messages),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: ErrorBanner(_error!),
              ),
            _Composer(controller: _input, sending: _sending, onSend: _send),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});
  final List<BookingMessage> messages;

  @override
  Widget build(BuildContext context) {
    // Newest at the bottom; `reverse` keeps the view pinned there.
    final ordered = messages.reversed.toList(growable: false);
    return ListView.builder(
      key: const ValueKey('chat-list'),
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: ordered.length,
      itemBuilder: (context, i) => _Bubble(ordered[i]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.m);
  final BookingMessage m;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final mine = m.fromCustomer;
    final who = mine ? l.chatFromYou : l.chatFromTasker;
    final when = vnDateTime(context, m.createdAt);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Semantics(
        container: true,
        label: '$who, $when',
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: mine ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.body, style: TextStyle(color: mine ? cs.onPrimaryContainer : cs.onSurface)),
                const SizedBox(height: 2),
                Text('$who - $when',
                    style: TextStyle(
                        fontSize: 11,
                        color: (mine ? cs.onPrimaryContainer : cs.onSurfaceVariant).withValues(alpha: 0.8))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('chat-input'),
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: l.chatInputHint,
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('chat-send'),
            tooltip: l.chatSend,
            onPressed: sending ? null : onSend,
            icon: sending
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
