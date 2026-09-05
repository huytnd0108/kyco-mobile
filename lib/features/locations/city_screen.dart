import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Foundation stub — a parallel work-unit replaces the body. Compiles + renders
/// so every route resolves.
class CityScreen extends StatelessWidget {
  const CityScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.locationsTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
