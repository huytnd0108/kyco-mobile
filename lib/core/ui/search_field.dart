import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

/// Pill search field mirroring the web SearchBar. Submits to the caller (which
/// routes to /services?q=… — the web has no /search page).
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onSubmitted, this.hint, this.controller});
  final ValueChanged<String> onSubmitted;
  final String? hint;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint ?? AppLocalizations.of(context).searchHint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(999),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
