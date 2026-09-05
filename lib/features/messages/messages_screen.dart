import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Foundation stub — U6 replaces the body. Compiles so the Messages tab and
/// its thread route resolve.
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.messagesTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// A single conversation thread (deep-linked from the Messages list).
class MessageThreadScreen extends StatelessWidget {
  const MessageThreadScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.messagesTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
