import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart'; // KycoApiTasker extension (fines/appeal/…)
import '../../core/di.dart';
import '../../core/models.dart';

/// Read-only compliance data providers (Section A3/A4/A5/A6). Each watches the
/// frozen [kycoApiProvider] surface; the routes 503 until the backend lands, so
/// every consuming screen surfaces the error via AsyncValue.error + retry.
///
/// MONEY IS DISPLAY-ONLY here. The single write in this folder is the fine
/// appeal text (`appealFine`), fired imperatively from the appeal screen.

/// GET /tasker/fines (A3) — pending/charged/refunded totals + per-fine rows.
final finesProvider =
    FutureProvider.autoDispose<FinesView>((ref) => ref.watch(kycoApiProvider).fines());

/// GET /tasker/fines/[id] (A4) — the fine + its existing appeal (if any).
final fineDetailProvider = FutureProvider.autoDispose
    .family<FineDetailView, int>((ref, id) => ref.watch(kycoApiProvider).fineDetail(id));

/// GET /tasker/cancellations (A6) — history + penaltyScore + 30-day count.
final cancellationsProvider = FutureProvider.autoDispose<CancellationsView>(
    (ref) => ref.watch(kycoApiProvider).cancellations());

/// GET /tasker/referrals (A5) — own code + program + referrals + earnedExtra.
final referralsProvider = FutureProvider.autoDispose<ReferralsView>(
    (ref) => ref.watch(kycoApiProvider).referrals());
