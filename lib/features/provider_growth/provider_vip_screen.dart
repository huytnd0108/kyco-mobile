import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/adaptive.dart';
import 'provider_growth_providers.dart';

/// `/p/vip` — VIP perks board. When the provider's tier is known and below
/// platinum, an upsell explains how to reach it; otherwise (platinum, or tier
/// unavailable) the perks list is shown. Tier comes from [providerTierProvider],
/// a read this unit owns; no money is displayed or computed here.
class ProviderVipScreen extends ConsumerWidget {
  const ProviderVipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(providerTierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.provVipTitle)),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // Tier read failing is non-fatal — fall back to the perks list.
          error: (_, _) => const _PerksView(isPlatinum: false),
          data: (tier) {
            // Known, below platinum → upsell. Platinum / unknown → perks.
            if (tier != null && tier != 'platinum') {
              return _UpsellView(tier: tier);
            }
            return _PerksView(isPlatinum: tier == 'platinum');
          },
        ),
      ),
    );
  }
}

class _Perk {
  const _Perk(this.emoji, this.title, this.body);
  final String emoji;
  final String title;
  final String body;
}

// MISSING-ARB: all perk titles/bodies are inlined (no l10n keys exist yet).
const _perks = <_Perk>[
  _Perk('🎯', 'Ưu tiên nhận đơn',
      'Được ưu tiên phân bổ các đơn giá trị cao trước các CTV khác.'),
  _Perk('📍', 'Mở rộng khu vực',
      'Nhận đơn ở nhiều quận/khu vực hơn để tối đa thu nhập.'),
  _Perk('📞', 'Hỗ trợ VIP riêng',
      'Đường dây hỗ trợ riêng 1900-VIP-XX, phản hồi nhanh 24/7.'),
  _Perk('🏆', 'Huy hiệu VIP',
      'Hiển thị huy hiệu Bạch kim với khách hàng để tăng độ tin cậy.'),
  _Perk('🎁', 'Quà & ưu đãi',
      'Nhận quà tri ân và các ưu đãi độc quyền dành cho CTV VIP.'),
  _Perk('🚀', 'Thưởng cao hơn',
      'Hệ số thưởng cao hơn cho cùng một mức thành tích.'),
];

class _PerksView extends StatelessWidget {
  const _PerksView({required this.isPlatinum});
  final bool isPlatinum;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return CenteredMaxWidth(
      maxWidth: 720,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.primary),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // MISSING-ARB: 'Đặc quyền VIP' / 'VIP perks'
                        isPlatinum ? 'Chào mừng CTV VIP 💎' : 'Đặc quyền VIP',
                        style: tt.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        // MISSING-ARB: subtitle
                        'Những quyền lợi dành cho CTV hạng Bạch kim.',
                        style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
                const Text('💎', style: TextStyle(fontSize: 44)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoUp = constraints.maxWidth >= 480;
              final width =
                  twoUp ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final p in _perks)
                    SizedBox(width: width, child: _PerkCard(p)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  const _PerkCard(this.perk);
  final _Perk perk;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(perk.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 8),
          Text(perk.title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(perk.body,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _UpsellView extends StatelessWidget {
  const _UpsellView({required this.tier});
  final String tier;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // MISSING-ARB: requirement lines
    const reqs = <String>[
      'Hoàn thành ≥ 800 đơn',
      'Điểm đánh giá ≥ 4.85',
      'Duy trì tỉ lệ hoàn thành cao',
      'Không có khiếu nại nghiêm trọng',
    ];
    return CenteredMaxWidth(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: Text('💎', style: TextStyle(fontSize: 64))),
          const SizedBox(height: 12),
          Text(
            // MISSING-ARB: 'Mở khoá đặc quyền VIP' / 'Unlock VIP'
            'Mở khoá đặc quyền VIP',
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            // MISSING-ARB: upsell body referencing current tier
            'Đạt hạng Bạch kim để nhận toàn bộ quyền lợi VIP. Hạng hiện tại: ${_tierLabel(tier)}.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // MISSING-ARB: 'Điều kiện' / 'Requirements'
                  'Điều kiện lên hạng',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (final r in reqs)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(r, style: tt.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/p'),
            // MISSING-ARB: 'Về trang chủ CTV' / 'Back to dashboard'
            child: const Text('Về trang chủ CTV'),
          ),
        ],
      ),
    );
  }
}

/// Vietnamese tier labels (mirrors the web `PROVIDER_TIER_LABELS`). MISSING-ARB.
String _tierLabel(String tier) {
  switch (tier) {
    case 'platinum':
      return 'Bạch kim';
    case 'gold':
      return 'Vàng';
    case 'silver':
      return 'Bạc';
    case 'bronze':
      return 'Đồng';
    default:
      return tier;
  }
}
