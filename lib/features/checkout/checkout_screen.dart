import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Foundation stub — a parallel work-unit replaces the body. Compiles + renders
/// so every route resolves.
class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key, required this.serviceId});
  final int serviceId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.checkoutTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
