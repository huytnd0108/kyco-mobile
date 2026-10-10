import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import '../../core/api/problem.dart';
import '../../core/models.dart';
import '../../core/widgets.dart';
import 'account_providers.dart';

/// `/help` — the public customer FAQ (`GET /v1/help` → `faq`).
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(helpFaqProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.faqs)),
      body: SafeArea(
        child: CenteredMaxWidth(
          maxWidth: 720,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorRetry(
              error: e,
              onRetry: () => ref.invalidate(helpFaqProvider),
            ),
            data: (items) => items.isEmpty
                ? EmptyState(icon: Icons.help_outline, message: l.cust2HelpEmpty)
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => Card(
                      child: ExpansionTile(
                        title: Text(items[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                        children: [SelectableText(items[i].body ?? '')],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// `/legal/:doc` — a curated public document (`GET /v1/legal/{doc}`; the
/// backend allow-lists `about` and `contact`). A 404 (unseeded section) reads
/// as "not available yet", not as an error.
class LegalDocScreen extends ConsumerWidget {
  const LegalDocScreen({super.key, required this.doc});
  final String doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(legalDocProvider(doc));
    final fallbackTitle = switch (doc) {
      'about' => l.aboutKyco,
      'contact' => l.contactUs,
      _ => 'Kyco',
    };
    return Scaffold(
      appBar: AppBar(title: Text(async.valueOrNull?.title.isNotEmpty == true ? async.value!.title : fallbackTitle)),
      body: SafeArea(
        child: CenteredMaxWidth(
          maxWidth: 720,
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => (e is ApiException && (e.code == 'NOT_FOUND' || e.status == 404))
                ? EmptyState(icon: Icons.description_outlined, message: l.cust2DocUnavailable)
                : ErrorRetry(
                    error: e,
                    onRetry: () => ref.invalidate(legalDocProvider(doc)),
                  ),
            data: (ContentSection s) => ListView(
              padding: const EdgeInsets.all(20),
              children: [SelectableText(s.body ?? '', style: const TextStyle(height: 1.5))],
            ),
          ),
        ),
      ),
    );
  }
}
