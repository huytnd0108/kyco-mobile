import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Friendly dead-end for an unknown route (stale deep link / notification).
/// Never shows the raw URI — the router logs it instead.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.notFoundTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.travel_explore, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(l.notFoundBody, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('not-found-home'),
                onPressed: () => context.go('/'),
                child: Text(l.goHomeAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
