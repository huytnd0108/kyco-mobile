import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Foundation stub — a parallel work-unit replaces the body. Compiles + renders
/// so every route resolves.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key, this.category, this.subcategory, this.q});
  final String? category;
  final String? subcategory;
  final String? q;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.servicesTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
