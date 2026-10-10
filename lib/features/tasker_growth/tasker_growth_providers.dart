import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// Riverpod surface for the four tasker_growth screens (bonuses, goals,
/// leaderboard, vip). Every read is API-backed through [kycoApiProvider] and
/// exposed as an [AsyncValue] so each screen is loading/error/refresh tolerant.
///
/// MONEY IS DISPLAY-ONLY: nothing here computes or posts a VND amount. The one
/// mutation ([setGoal]) sends tasker-chosen *targets* (jobs + income goal),
/// never a payout figure — the server derives all real money.

// ── period keys (ported from web lib/time.ts, ISO-8601, Monday-start) ────────

/// `YYYY-MM` for the calendar month containing [now].
String monthKeyOf(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

/// `YYYY-Www` ISO week key — matches the web's `isoWeekKey`, so a goal set on
/// mobile lands in the same period bucket the CTV portal reads.
String isoWeekKeyOf(DateTime now) {
  final dt = DateTime.utc(now.year, now.month, now.day);
  final dayNum = dt.weekday; // Mon=1 .. Sun=7
  final thursday = dt.add(Duration(days: 4 - dayNum));
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  final week = (thursday.difference(yearStart).inDays / 7).floor() + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

// ── bonuses ──────────────────────────────────────────────────────────────────

/// `GET /tasker/bonuses` — weekly + monthly bonus preview + payout history.
/// All amounts are server-computed (`TaskerBonuses`); the screen only renders.
final bonusesProvider = FutureProvider.autoDispose<TaskerBonuses>(
  (ref) => ref.watch(kycoApiProvider).bonuses(),
);

// ── goals ────────────────────────────────────────────────────────────────────

/// A tasker's goal targets plus the best-effort live month progress.
///
/// The frozen `GET /tasker/goals` carries only the *targets* (the web reads
/// achieved figures via a separate progress endpoint that `/v1` does not expose
/// yet). So live income progress for the current month is sourced from the
/// dashboard's server-derived `earnings.monthVnd`; weekly achieved and monthly
/// job counts have no frozen source and render as "—".
class GoalsData {
  const GoalsData({
    required this.goals,
    this.monthVndAchieved,
  });

  final List<Goal> goals;

  /// Server-derived income earned this month (VND) — display only. Null when
  /// the dashboard read failed / is unavailable.
  final int? monthVndAchieved;

  Goal? forPeriod(String kind, String key) {
    for (final g in goals) {
      if (g.periodKind == kind && g.periodKey == key) return g;
    }
    return null;
  }
}

final goalsProvider = FutureProvider.autoDispose<GoalsData>((ref) async {
  final api = ref.watch(kycoApiProvider);
  final goals = await api.goals();
  int? monthVnd;
  try {
    final dash = await api.taskerDashboard();
    monthVnd = dash.earnings.monthVnd;
  } catch (_) {
    monthVnd = null; // targets still render without live progress
  }
  return GoalsData(goals: goals, monthVndAchieved: monthVnd);
});

/// Persists a tasker-chosen target (jobs + income goal) for a period, then
/// refreshes [goalsProvider]. No money amount is *computed* — `targetVnd` is the
/// user's own goal, validated server-side. Returns true on success.
Future<bool> saveGoal(
  WidgetRef ref, {
  required String periodKind,
  required String periodKey,
  required int targetJobs,
  required int targetVnd,
}) async {
  try {
    await ref.read(kycoApiProvider).setGoal(
          periodKind: periodKind,
          periodKey: periodKey,
          targetJobs: targetJobs,
          targetVnd: targetVnd,
        );
    ref.invalidate(goalsProvider);
    return true;
  } catch (_) {
    return false;
  }
}

// ── leaderboard ──────────────────────────────────────────────────────────────

/// Selected scope: `week` | `month`.
final leaderboardScopeProvider = StateProvider.autoDispose<String>((ref) => 'week');

/// Selected district filter (null = nationwide).
final leaderboardDistrictProvider = StateProvider.autoDispose<String?>((ref) => null);

/// `GET /tasker/leaderboard?scope=&district=` — ranked rows by server-provided
/// revenue, plus the district roster and this tasker's own rank.
final leaderboardProvider = FutureProvider.autoDispose<LeaderboardView>((ref) {
  final scope = ref.watch(leaderboardScopeProvider);
  final district = ref.watch(leaderboardDistrictProvider);
  return ref.watch(kycoApiProvider).leaderboard(scope: scope, district: district);
});

// ── vip ──────────────────────────────────────────────────────────────────────

/// Best-effort read of the signed-in tasker's tier for the VIP gate.
///
/// `/v1` has no dedicated "my tier" read, so this derives it from the monthly
/// leaderboard self-row (server-computed `tier`). Returns null when the tasker
/// is unranked / the read fails — the VIP screen then shows the perks list, per
/// spec ("if unavailable show the perks list").
final taskerTierProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    final view = await ref.watch(kycoApiProvider).leaderboard(scope: 'month');
    if (view.myRank > 0) {
      for (final r in view.rows) {
        if (r.rank == view.myRank) return r.tier;
      }
    }
  } catch (_) {
    // fall through → null → perks list
  }
  return null;
});
