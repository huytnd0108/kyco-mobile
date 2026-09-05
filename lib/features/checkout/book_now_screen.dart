import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Foundation stub — a parallel work-unit replaces the body. Compiles + renders
/// so every route resolves.
class BookNowScreen extends StatelessWidget {
  const BookNowScreen({super.key, this.category, this.q});
  final String? category;
  final String? q;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.bookNow)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
