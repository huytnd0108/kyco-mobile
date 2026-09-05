import 'package:flutter/material.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../format.dart';

/// Bold primary-coloured VND price. When [from] is set it renders the web's
/// "từ {price}" affordance (a base/starting price).
class PriceText extends StatelessWidget {
  const PriceText(this.vnd, {super.key, this.from = false, this.style});
  final int vnd;
  final bool from;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = (style ?? Theme.of(context).textTheme.titleMedium)
        ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700);
    final money = formatVnd(vnd);
    return Text(from ? AppLocalizations.of(context).fromPrice(money) : money, style: base);
  }
}
