import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/widgets.dart';
import '../home/home_providers.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn của tôi'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/')),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bookingsProvider);
          await ref.read(bookingsProvider.future);
        },
        child: bookings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            ErrorRetry(message: 'Không tải được đơn.\n$e', onRetry: () => ref.invalidate(bookingsProvider)),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 140),
                  Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Chưa có đơn nào.', textAlign: TextAlign.center),
                  )),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _BookingTile(list[i]),
                ),
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile(this.b);
  final Booking b;

  @override
  Widget build(BuildContext context) {
    final vnd = b.totalVnd != null
        ? NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(b.totalVnd)
        : null;
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('#${b.id}')),
        title: Text(b.serviceName ?? 'Đơn #${b.id}'),
        subtitle: Text(<String>[?vnd, ?b.createdAt].join(' • ')),
        trailing: _StatusChip(b.status),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status.toUpperCase()) {
      'SETTLED' || 'COMPLETED' || 'CONFIRMED' => (const Color(0xFFDCFCE7), const Color(0xFF166534)),
      'CANCELLED' || 'BAD_DEBT' => (const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
      _ => (const Color(0xFFE0F2FE), const Color(0xFF075985)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
