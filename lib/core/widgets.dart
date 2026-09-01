import 'package:flutter/material.dart';

/// Kyco gradient mark + wordmark, reused on the auth screens.
class KycoBrand extends StatelessWidget {
  const KycoBrand({super.key});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.cleaning_services, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          const Text('Kyco', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      );
}

/// Inline error banner for form/API failures.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFFCA5A5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF991B1B)))),
          ],
        ),
      );
}

/// Full-screen error state with a retry action (used by data screens).
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Thử lại')),
            ],
          ),
        ),
      );
}
