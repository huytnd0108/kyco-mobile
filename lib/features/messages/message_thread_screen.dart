import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/widgets.dart';

/// A single conversation thread (deep-linked from the Messages list). v1 has no
/// customer-messages API (see plan Risk R1), so a thread is booking-derived: it
/// shows a placeholder and links straight to the booking it mirrors. When a
/// future `GET /v1/messages/:id` lands it drops in behind [MessagesRepo].
class MessageThreadScreen extends StatelessWidget {
  const MessageThreadScreen({super.key, required this.id});

  /// The booking id this conversation is derived from.
  final int id;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.bookingNumber(id))),
      body: SafeArea(
        child: EmptyState(
          icon: '💬',
          message: l.noMessages,
          action: FilledButton.icon(
            onPressed: () => context.push('/bookings/$id'),
            icon: const Icon(Icons.receipt_long),
            label: Text(l.viewDetails),
          ),
        ),
      ),
    );
  }
}
