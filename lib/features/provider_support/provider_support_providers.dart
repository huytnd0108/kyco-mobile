import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// The signed-in provider's own support tickets (A7 — `GET /provider/support`).
///
/// Backed by the frozen [KycoApiProvider.supportTickets]. That route lands with
/// Section A7 and returns 503 until the `api_mobile_v1_enabled` flag flips, so
/// the screen renders this as an [AsyncValue] and treats the error/503 as an
/// empty-history hint (a fresh provider legitimately has none) rather than a
/// hard failure. Refresh = `ref.invalidate(myTicketsProvider)` (also fired after
/// a successful [createSupportTicket]).
final myTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(kycoApiProvider).supportTickets(),
);
