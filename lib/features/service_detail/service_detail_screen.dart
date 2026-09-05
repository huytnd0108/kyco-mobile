import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Foundation stub — a parallel work-unit replaces the body. Compiles + renders
/// so every route resolves.
class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
