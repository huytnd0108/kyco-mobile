import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Foundation stub — a parallel work-unit replaces the body. Compiles + renders
/// so every route resolves.
class CityServiceScreen extends StatelessWidget {
  const CityServiceScreen({super.key, required this.citySlug, required this.service});
  final String citySlug;
  final String service;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.locationsTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
