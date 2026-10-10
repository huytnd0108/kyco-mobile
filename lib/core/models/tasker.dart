// Tasker (tasker / CTV) models — the mobile mirror of the kyco /api/v1/tasker
// surface. Tolerant parsing throughout (`(j['x'] as num?)?.toInt() ?? 0`), so a
// field the backend adds or omits never crashes a screen. Money is always an
// integer VND (`*Vnd`) that the SERVER derives — the app never computes amounts.
//
// Exported from `core/models.dart`. Field names taken verbatim from the server
// interfaces (tasker route handlers + lib/tasker/** cores).

import 'catalog.dart' show Paged;

// ── small helpers ───────────────────────────────────────────────────────────
int? _int(dynamic v) => (v as num?)?.toInt();
int _intd(dynamic v, [int d = 0]) => (v as num?)?.toInt() ?? d;
double? _dbl(dynamic v) => (v as num?)?.toDouble();
String? _str(dynamic v) => v?.toString();
bool _bool(dynamic v) => v == true;

List<Map<String, dynamic>> _mapList(dynamic v) => (v is List ? v : const [])
    .whereType<Map<String, dynamic>>()
    .toList(growable: false);

// ── jobs ────────────────────────────────────────────────────────────────────

/// One row of the tasker's job list (= server `TaskerJobItem`).
class TaskerJob {
  const TaskerJob({
    required this.jobId,
    this.jobStatus,
    this.isCrewLeader,
    this.bookingId,
    this.scheduledAt,
    this.addressLine,
    this.district,
    this.ward,
    this.totalVnd,
    this.paymentMethod,
    this.confirmationCode,
    this.serviceName,
    this.durationMinutes,
  });

  final int jobId;
  final String? jobStatus;
  final bool? isCrewLeader;
  final int? bookingId;
  final String? scheduledAt;
  final String? addressLine;
  final String? district;
  final String? ward;
  final int? totalVnd;
  final String? paymentMethod;
  final String? confirmationCode;
  final String? serviceName;
  final int? durationMinutes;

  factory TaskerJob.fromJson(Map<String, dynamic> j) => TaskerJob(
        jobId: _intd(j['jobId']),
        jobStatus: _str(j['jobStatus']),
        isCrewLeader: j['isCrewLeader'] as bool?,
        bookingId: _int(j['bookingId']),
        scheduledAt: _str(j['scheduledAt']),
        addressLine: _str(j['addressLine']),
        district: _str(j['district']),
        ward: _str(j['ward']),
        totalVnd: _int(j['totalVnd']),
        paymentMethod: _str(j['paymentMethod']),
        confirmationCode: _str(j['confirmationCode']),
        serviceName: _str(j['serviceName']),
        durationMinutes: _int(j['durationMinutes']),
      );
}

/// A pool / assigned-pipeline job (A9). Superset row covering both `listPoolJobs`
/// and `listAssignedPipeline` — extra keys are simply ignored.
class PoolJob {
  const PoolJob({
    required this.jobId,
    this.bookingId,
    this.scheduledAt,
    this.addressLine,
    this.district,
    this.ward,
    this.totalVnd,
    this.notes,
    this.serviceName,
    this.serviceId,
    this.durationMinutes,
    this.jobStatus,
    this.confirmationCode,
    this.claimDeadline,
    this.distanceKm,
    this.taskerNetVnd,
  });

  final int jobId;
  final int? bookingId;
  final String? scheduledAt;
  final String? addressLine;
  final String? district;
  final String? ward;
  final int? totalVnd;
  final String? notes;
  final String? serviceName;
  final int? serviceId;
  final int? durationMinutes;
  final String? jobStatus;
  final String? confirmationCode;
  final String? claimDeadline;

  /// Pool rows only (Z2): great-circle km from the tasker's last location ping,
  /// computed server-side. Pre-claim rows carry ward/district + this distance,
  /// never [addressLine] / [notes]; those appear once the tasker owns the job.
  final double? distanceKm;

  /// Server-computed estimate of the tasker's net for this job
  /// (resolveCommission, 8edc05d). Display as-is — the app never derives it
  /// from [totalVnd]. Final settlement still resolves at check-out.
  final int? taskerNetVnd;

  factory PoolJob.fromJson(Map<String, dynamic> j) => PoolJob(
        jobId: _intd(j['jobId']),
        bookingId: _int(j['bookingId']),
        scheduledAt: _str(j['scheduledAt']),
        addressLine: _str(j['addressLine']),
        district: _str(j['district']),
        ward: _str(j['ward']),
        totalVnd: _int(j['totalVnd']),
        notes: _str(j['notes']),
        serviceName: _str(j['serviceName']),
        serviceId: _int(j['serviceId']),
        durationMinutes: _int(j['durationMinutes']),
        jobStatus: _str(j['jobStatus']),
        confirmationCode: _str(j['confirmationCode']),
        claimDeadline: _str(j['claimDeadline']),
        distanceKm: _dbl(j['distanceKm']),
        taskerNetVnd: _int(j['taskerNetVnd']),
      );
}

/// The available-jobs view (A9): pool + assigned + claim gate.
class PoolView {
  const PoolView({
    this.pool = const [],
    this.assigned = const [],
    this.canClaim = false,
    this.banReason,
  });

  final List<PoolJob> pool;
  final List<PoolJob> assigned;
  final bool canClaim;
  final String? banReason;

  factory PoolView.fromJson(Map<String, dynamic> j) => PoolView(
        pool: _mapList(j['pool']).map(PoolJob.fromJson).toList(growable: false),
        assigned: _mapList(j['assigned']).map(PoolJob.fromJson).toList(growable: false),
        canClaim: _bool(j['canClaim']),
        banReason: _str(j['banReason']),
      );
}

/// The lifecycle-hub read (A8). Kept intentionally loose: the payment/photo/
/// violation detail is exposed as pass-through maps so the W3 unit can bind the
/// exact fields it needs without this shared contract churning.
class TaskerJobDetail {
  const TaskerJobDetail({
    required this.job,
    this.booking,
    this.service,
    this.customer,
    this.hasCheckedIn = false,
    this.hasCheckedOut = false,
    this.thread = const [],
    this.openViolation,
  });

  final Map<String, dynamic> job;
  final Map<String, dynamic>? booking;
  final Map<String, dynamic>? service;
  final Map<String, dynamic>? customer;
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final List<Map<String, dynamic>> thread;
  final Map<String, dynamic>? openViolation;

  int? get jobId => _int(job['id'] ?? job['jobId']);
  int? get bookingId => _int((booking?['id']) ?? job['bookingId']);
  int? get totalVnd => _int(booking?['totalVnd']);
  String? get paymentMethod => _str(booking?['paymentMethod']);
  String? get paymentStatus => _str(booking?['status']);

  static Map<String, dynamic>? _asMap(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  factory TaskerJobDetail.fromJson(Map<String, dynamic> j) => TaskerJobDetail(
        job: _asMap(j['job']) ?? const {},
        booking: _asMap(j['booking']),
        service: _asMap(j['service']),
        customer: _asMap(j['customer']),
        hasCheckedIn: _bool(j['hasCheckedIn']),
        hasCheckedOut: _bool(j['hasCheckedOut']),
        thread: _mapList(j['thread']),
        openViolation: _asMap(j['openViolation']),
      );
}

// ── dashboard / workspace ────────────────────────────────────────────────────

class TaskerEarnings {
  const TaskerEarnings({this.lifetimeVnd = 0, this.monthVnd = 0, this.balanceVnd = 0});
  final int lifetimeVnd;
  final int monthVnd;
  final int balanceVnd;

  factory TaskerEarnings.fromJson(Map<String, dynamic> j) => TaskerEarnings(
        lifetimeVnd: _intd(j['lifetimeVnd']),
        monthVnd: _intd(j['monthVnd']),
        balanceVnd: _intd(j['balanceVnd']),
      );
}

class TaskerJobCounts {
  const TaskerJobCounts({this.active = 0, this.total = 0});
  final int active;
  final int total;

  factory TaskerJobCounts.fromJson(Map<String, dynamic> j) => TaskerJobCounts(
        active: _intd(j['active']),
        total: _intd(j['total']),
      );
}

/// Dashboard. `kpi` is a pass-through map (acceptance/completion/rating/
/// punctuality objects) — the W1 unit reads the nested tone/raw fields directly.
class TaskerDashboard {
  const TaskerDashboard({
    this.kpi = const {},
    this.jobs = const TaskerJobCounts(),
    this.earnings = const TaskerEarnings(),
  });

  final Map<String, dynamic> kpi;
  final TaskerJobCounts jobs;
  final TaskerEarnings earnings;

  factory TaskerDashboard.fromJson(Map<String, dynamic> j) => TaskerDashboard(
        kpi: j['kpi'] is Map<String, dynamic> ? j['kpi'] as Map<String, dynamic> : const {},
        jobs: TaskerJobCounts.fromJson(
            j['jobs'] is Map<String, dynamic> ? j['jobs'] as Map<String, dynamic> : const {}),
        earnings: TaskerEarnings.fromJson(
            j['earnings'] is Map<String, dynamic> ? j['earnings'] as Map<String, dynamic> : const {}),
      );
}

/// Single-hop home read: dashboard + first jobs page + goals. `/workspace`
/// nests the jobs page (`items`/`nextCursor`/`hasMore`) INSIDE `data.jobs`,
/// unlike `/jobs` which puts the array in `data` and cursor in `meta`.
class TaskerWorkspace {
  const TaskerWorkspace({
    required this.dashboard,
    required this.jobs,
    this.goals = const [],
  });

  final TaskerDashboard dashboard;
  final Paged<TaskerJob> jobs;
  final List<Goal> goals;

  factory TaskerWorkspace.fromJson(Map<String, dynamic> j) {
    final jobsObj = j['jobs'] is Map<String, dynamic> ? j['jobs'] as Map<String, dynamic> : const {};
    final items = _mapList(jobsObj['items']).map(TaskerJob.fromJson).toList(growable: false);
    return TaskerWorkspace(
      dashboard: TaskerDashboard.fromJson(
          j['dashboard'] is Map<String, dynamic> ? j['dashboard'] as Map<String, dynamic> : const {}),
      jobs: Paged<TaskerJob>(
        items: items,
        nextCursor: jobsObj['nextCursor'] is String ? jobsObj['nextCursor'] as String : null,
        hasMore: jobsObj['hasMore'] == true,
      ),
      goals: _mapList(j['goals']).map(Goal.fromJson).toList(growable: false),
    );
  }
}

// ── wallet ───────────────────────────────────────────────────────────────────

class WalletSummary {
  const WalletSummary({
    this.balanceVnd = 0,
    this.currency = 'VND',
    this.lifetimeEarningVnd = 0,
    this.lifetimeFeeVnd = 0,
    this.jobCount = 0,
    this.monthEarningVnd = 0,
  });

  final int balanceVnd;
  final String currency;
  final int lifetimeEarningVnd;
  final int lifetimeFeeVnd;
  final int jobCount;
  final int monthEarningVnd;

  factory WalletSummary.fromJson(Map<String, dynamic> j) => WalletSummary(
        balanceVnd: _intd(j['balanceVnd']),
        currency: _str(j['currency']) ?? 'VND',
        lifetimeEarningVnd: _intd(j['lifetimeEarningVnd']),
        lifetimeFeeVnd: _intd(j['lifetimeFeeVnd']),
        jobCount: _intd(j['jobCount']),
        monthEarningVnd: _intd(j['monthEarningVnd']),
      );
}

class Payout {
  const Payout({
    required this.id,
    this.bookingId,
    this.amountVnd = 0,
    this.platformFeeVnd = 0,
    this.status,
    this.releasedAt,
    this.createdAt,
  });

  final int id;
  final int? bookingId;
  final int amountVnd;
  final int platformFeeVnd;
  final String? status;
  final String? releasedAt;
  final String? createdAt;

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        id: _intd(j['id']),
        bookingId: _int(j['bookingId']),
        amountVnd: _intd(j['amountVnd']),
        platformFeeVnd: _intd(j['platformFeeVnd']),
        status: _str(j['status']),
        releasedAt: _str(j['releasedAt']),
        createdAt: _str(j['createdAt']),
      );
}

class WalletTxn {
  const WalletTxn({
    required this.id,
    this.type,
    this.amountVnd = 0,
    this.reason,
    this.balanceAfterVnd = 0,
    this.createdAt,
  });

  final int id;
  final String? type; // credit | debit
  final int amountVnd;
  final String? reason;
  final int balanceAfterVnd;
  final String? createdAt;

  factory WalletTxn.fromJson(Map<String, dynamic> j) => WalletTxn(
        id: _intd(j['id']),
        type: _str(j['type']),
        amountVnd: _intd(j['amountVnd']),
        reason: _str(j['reason']),
        balanceAfterVnd: _intd(j['balanceAfterVnd']),
        createdAt: _str(j['createdAt']),
      );
}

/// Bank snapshot of a withdrawal request (`bank` on `GET /tasker/payout-requests`).
/// [masked] is server-built (e.g. `VCB ••••1234`) — shown as-is.
class PayoutRequestBank {
  const PayoutRequestBank({this.code, this.accountTail, this.masked});

  final String? code;
  final String? accountTail;
  final String? masked;

  factory PayoutRequestBank.fromJson(Map<String, dynamic> j) => PayoutRequestBank(
        code: _str(j['code']),
        accountTail: _str(j['accountTail']),
        masked: _str(j['masked']),
      );
}

/// One withdrawal request (`GET /tasker/payout-requests[/{id}]`, MQA-69).
/// [status] is `pending` | `paid` | `rejected`; an unknown value is kept raw and
/// the UI falls back to the server's [statusLabel]. Money is displayed as given.
class PayoutRequest {
  const PayoutRequest({
    required this.id,
    this.amountVnd,
    this.status,
    this.statusLabel,
    this.createdAt,
    this.decidedAt,
    this.rejectReason,
    this.bank,
  });

  final int id;

  /// Server value; null if absent — rendered as "—", never as 0₫.
  final int? amountVnd;
  final String? status;
  final String? statusLabel;
  final String? createdAt;
  final String? decidedAt;
  final String? rejectReason;
  final PayoutRequestBank? bank;

  factory PayoutRequest.fromJson(Map<String, dynamic> j) => PayoutRequest(
        id: _intd(j['id']),
        amountVnd: _int(j['amountVnd']),
        status: _str(j['status']),
        statusLabel: _str(j['statusLabel']),
        createdAt: _str(j['createdAt']),
        decidedAt: _str(j['decidedAt']),
        rejectReason: _str(j['rejectReason']),
        bank: j['bank'] is Map<String, dynamic>
            ? PayoutRequestBank.fromJson(j['bank'] as Map<String, dynamic>)
            : null,
      );
}

/// The A1 201 body of a successful payout request (server-derived echo).
class PayoutRequestResult {
  const PayoutRequestResult({
    this.id,
    this.status,
    this.amountVnd = 0,
    this.bankCode,
    this.accountTail,
  });

  final int? id;
  final String? status;
  final int amountVnd;
  final String? bankCode;
  final String? accountTail;

  factory PayoutRequestResult.fromJson(Map<String, dynamic> j) => PayoutRequestResult(
        id: _int(j['id']),
        status: _str(j['status']),
        amountVnd: _intd(j['amountVnd']),
        bankCode: _str(j['bankCode']),
        accountTail: _str(j['accountTail']),
      );
}

// ── bonuses / goals / leaderboard ────────────────────────────────────────────

/// A computed bonus preview (`BonusOutput`). Its inner shape lives in the web's
/// `lib/bonus` and is not fixed here — the common fields are surfaced, and the
/// full map is kept for the W6 unit.
class Bonus {
  const Bonus({this.kind, this.amountVnd = 0, this.eligible = false, this.raw = const {}});
  final String? kind;
  final int amountVnd;
  final bool eligible;
  final Map<String, dynamic> raw;

  factory Bonus.fromJson(Map<String, dynamic> j) => Bonus(
        kind: _str(j['kind']),
        amountVnd: _intd(j['amountVnd']),
        eligible: _bool(j['eligible']),
        raw: j,
      );
}

class BonusHistoryItem {
  const BonusHistoryItem({
    required this.id,
    this.kind,
    this.amountVnd = 0,
    this.status,
    this.periodStart,
    this.periodEnd,
    this.paidAt,
  });

  final int id;
  final String? kind;
  final int amountVnd;
  final String? status;
  final String? periodStart;
  final String? periodEnd;
  final String? paidAt;

  factory BonusHistoryItem.fromJson(Map<String, dynamic> j) => BonusHistoryItem(
        id: _intd(j['id']),
        kind: _str(j['kind']),
        amountVnd: _intd(j['amountVnd']),
        status: _str(j['status']),
        periodStart: _str(j['periodStart']),
        periodEnd: _str(j['periodEnd']),
        paidAt: _str(j['paidAt']),
      );
}

class TaskerBonuses {
  const TaskerBonuses({this.weekly = const [], this.monthly = const [], this.history = const []});
  final List<Bonus> weekly;
  final List<Bonus> monthly;
  final List<BonusHistoryItem> history;

  factory TaskerBonuses.fromJson(Map<String, dynamic> j) => TaskerBonuses(
        weekly: _mapList(j['weekly']).map(Bonus.fromJson).toList(growable: false),
        monthly: _mapList(j['monthly']).map(Bonus.fromJson).toList(growable: false),
        history: _mapList(j['history']).map(BonusHistoryItem.fromJson).toList(growable: false),
      );
}

class Goal {
  const Goal({
    required this.id,
    this.periodKind,
    this.periodKey,
    this.targetJobs = 0,
    this.targetVnd = 0,
    this.createdAt,
  });

  final int id;
  final String? periodKind; // week | month
  final String? periodKey;
  final int targetJobs;
  final int targetVnd;
  final String? createdAt;

  factory Goal.fromJson(Map<String, dynamic> j) => Goal(
        id: _intd(j['id']),
        periodKind: _str(j['periodKind']),
        periodKey: _str(j['periodKey']),
        targetJobs: _intd(j['targetJobs']),
        targetVnd: _intd(j['targetVnd']),
        createdAt: _str(j['createdAt']),
      );
}

class LeaderboardRow {
  const LeaderboardRow({
    required this.taskerId,
    this.name,
    this.district,
    this.tier,
    this.jobs = 0,
    this.revenueVnd,
    this.rank = 0,
  });

  final int taskerId;
  final String? name;
  final String? district;
  final String? tier;
  final int jobs;

  /// Only the caller's OWN row carries revenue (MQA-68 data minimisation);
  /// other taskers' rows omit it (null) — never render it as 0₫.
  final int? revenueVnd;
  final int rank;

  factory LeaderboardRow.fromJson(Map<String, dynamic> j) => LeaderboardRow(
        taskerId: _intd(j['taskerId']),
        name: _str(j['name']),
        district: _str(j['district']),
        tier: _str(j['tier']),
        jobs: _intd(j['jobs']),
        revenueVnd: _int(j['revenueVnd']),
        rank: _intd(j['rank']),
      );
}

class LeaderboardView {
  const LeaderboardView({
    this.scope = 'week',
    this.districts = const [],
    this.rows = const [],
    this.myRank = 0,
  });

  final String scope;
  final List<String> districts;
  final List<LeaderboardRow> rows;
  final int myRank;

  factory LeaderboardView.fromJson(Map<String, dynamic> j) => LeaderboardView(
        scope: _str(j['scope']) ?? 'week',
        districts: (j['districts'] is List ? j['districts'] as List : const [])
            .map((e) => e.toString())
            .toList(growable: false),
        rows: _mapList(j['rows']).map(LeaderboardRow.fromJson).toList(growable: false),
        myRank: _intd(j['myRank']),
      );
}

// ── fines / cancellations / referrals ────────────────────────────────────────

class Fine {
  const Fine({
    required this.id,
    this.amountVnd = 0,
    this.status,
    this.kind,
    this.reason,
    this.jobId,
    this.bookingId,
    this.createdAt,
    this.chargedAt,
    this.refundedAt,
    this.appealId,
  });

  final int id;
  final int amountVnd;
  final String? status; // pending | charged | refunded
  final String? kind;
  final String? reason;
  final int? jobId;
  final int? bookingId;
  final String? createdAt;
  final String? chargedAt;
  final String? refundedAt;
  final int? appealId;

  factory Fine.fromJson(Map<String, dynamic> j) => Fine(
        id: _intd(j['id']),
        amountVnd: _intd(j['amountVnd']),
        status: _str(j['status']),
        kind: _str(j['kind']),
        reason: _str(j['reason']),
        jobId: _int(j['jobId']),
        bookingId: _int(j['bookingId']),
        createdAt: _str(j['createdAt']),
        chargedAt: _str(j['chargedAt']),
        refundedAt: _str(j['refundedAt']),
        appealId: _int(j['appealId']),
      );
}

class FinesView {
  const FinesView({
    this.rows = const [],
    this.totalChargedVnd = 0,
    this.totalPendingVnd = 0,
    this.totalRefundedVnd = 0,
  });

  final List<Fine> rows;
  final int totalChargedVnd;
  final int totalPendingVnd;
  final int totalRefundedVnd;

  factory FinesView.fromJson(Map<String, dynamic> j) => FinesView(
        rows: _mapList(j['rows']).map(Fine.fromJson).toList(growable: false),
        totalChargedVnd: _intd(j['totalChargedVnd']),
        totalPendingVnd: _intd(j['totalPendingVnd']),
        totalRefundedVnd: _intd(j['totalRefundedVnd']),
      );
}

class FineAppeal {
  const FineAppeal({
    required this.id,
    this.fineId,
    this.status,
    this.body,
    this.createdAt,
  });

  final int id;
  final int? fineId;
  final String? status; // open | reviewed | accepted | rejected
  final String? body;
  final String? createdAt;

  factory FineAppeal.fromJson(Map<String, dynamic> j) => FineAppeal(
        id: _intd(j['id']),
        fineId: _int(j['fineId']),
        status: _str(j['status']),
        body: _str(j['body']),
        createdAt: _str(j['createdAt']),
      );
}

/// GET /tasker/fines/[id] (A4): the fine + its existing appeal (if any).
class FineDetailView {
  const FineDetailView({this.fine, this.existing});
  final Fine? fine;
  final FineAppeal? existing;

  factory FineDetailView.fromJson(Map<String, dynamic> j) => FineDetailView(
        fine: j['fine'] is Map<String, dynamic>
            ? Fine.fromJson(j['fine'] as Map<String, dynamic>)
            : null,
        existing: j['existing'] is Map<String, dynamic>
            ? FineAppeal.fromJson(j['existing'] as Map<String, dynamic>)
            : null,
      );
}

class Cancellation {
  const Cancellation({
    required this.id,
    this.reasonCode,
    this.reasonText,
    this.penaltyScore,
    this.createdAt,
    this.bookingId,
    this.scheduledAt,
  });

  final int id;
  final String? reasonCode;
  final String? reasonText;
  final int? penaltyScore;
  final String? createdAt;
  final int? bookingId;
  final String? scheduledAt;

  factory Cancellation.fromJson(Map<String, dynamic> j) => Cancellation(
        id: _intd(j['id']),
        reasonCode: _str(j['reasonCode']),
        reasonText: _str(j['reasonText']),
        penaltyScore: _int(j['penaltyScore']),
        createdAt: _str(j['createdAt']),
        bookingId: _int(j['bookingId']),
        scheduledAt: _str(j['scheduledAt']),
      );
}

class CancellationsView {
  const CancellationsView({
    this.rows = const [],
    this.countInWindow = 0,
    this.penaltyScore = 0,
  });

  final List<Cancellation> rows;
  final int countInWindow;
  final int penaltyScore;

  factory CancellationsView.fromJson(Map<String, dynamic> j) => CancellationsView(
        rows: _mapList(j['rows']).map(Cancellation.fromJson).toList(growable: false),
        countInWindow: _intd(j['countInWindow']),
        penaltyScore: _intd(j['penaltyScore']),
      );
}

class Referral {
  const Referral({
    required this.referralId,
    this.status,
    this.jobsDone,
    this.activatedAt,
    this.completedAt,
    this.refereeName,
    this.refereeDistrict,
  });

  final int referralId;
  final String? status;
  final int? jobsDone;
  final String? activatedAt;
  final String? completedAt;
  final String? refereeName;
  final String? refereeDistrict;

  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
        referralId: _intd(j['referralId']),
        status: _str(j['status']),
        jobsDone: _int(j['jobsDone']),
        activatedAt: _str(j['activatedAt']),
        completedAt: _str(j['completedAt']),
        refereeName: _str(j['refereeName']),
        refereeDistrict: _str(j['refereeDistrict']),
      );
}

class ReferralsView {
  const ReferralsView({
    this.referralCode,
    this.program,
    this.referrals = const [],
    this.earnedExtraVnd = 0,
  });

  final String? referralCode;
  final Map<String, dynamic>? program;
  final List<Referral> referrals;

  /// Documented APPROXIMATION (sum of ALL payouts) — label it as such in the UI.
  final int earnedExtraVnd;

  factory ReferralsView.fromJson(Map<String, dynamic> j) => ReferralsView(
        referralCode: _str(j['referralCode']),
        program: j['program'] is Map<String, dynamic> ? j['program'] as Map<String, dynamic> : null,
        referrals: _mapList(j['referrals']).map(Referral.fromJson).toList(growable: false),
        earnedExtraVnd: _intd(j['earnedExtraVnd']),
      );
}

// ── availability ─────────────────────────────────────────────────────────────

class AvailabilitySlot {
  const AvailabilitySlot({required this.start, required this.end});
  final int start; // minutes from midnight
  final int end;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> j) =>
      AvailabilitySlot(start: _intd(j['start']), end: _intd(j['end']));

  Map<String, int> toJson() => {'start': start, 'end': end};
}

class AvailabilityDateOverride {
  const AvailabilityDateOverride({required this.date, this.slots = const []});
  final String date; // YYYY-MM-DD
  final List<AvailabilitySlot> slots;

  factory AvailabilityDateOverride.fromJson(Map<String, dynamic> j) => AvailabilityDateOverride(
        date: _str(j['date']) ?? '',
        slots: _mapList(j['slots']).map(AvailabilitySlot.fromJson).toList(growable: false),
      );
}

/// Weekly availability (A10). Tolerant to either `weekly`/`slotsByDow` maps
/// (dow → slots) and a `dates`/`rows` override list.
class AvailabilityWeek {
  const AvailabilityWeek({this.weekly = const {}, this.dates = const []});
  final Map<int, List<AvailabilitySlot>> weekly;
  final List<AvailabilityDateOverride> dates;

  factory AvailabilityWeek.fromJson(Map<String, dynamic> j) {
    final rawWeekly = j['weekly'] ?? j['slotsByDow'];
    final weekly = <int, List<AvailabilitySlot>>{};
    if (rawWeekly is Map) {
      rawWeekly.forEach((k, v) {
        final dow = int.tryParse(k.toString());
        if (dow != null) {
          weekly[dow] = _mapList(v).map(AvailabilitySlot.fromJson).toList(growable: false);
        }
      });
    }
    return AvailabilityWeek(
      weekly: weekly,
      dates: _mapList(j['dates']).map(AvailabilityDateOverride.fromJson).toList(growable: false),
    );
  }
}

/// PUT /availability/{weekly,date} response: `{ saved, conflicts }`.
class SaveAvailabilityResult {
  const SaveAvailabilityResult({this.saved = false, this.conflicts = const []});
  final bool saved;
  final List<int> conflicts; // uncovered jobIds

  factory SaveAvailabilityResult.fromJson(Map<String, dynamic> j) => SaveAvailabilityResult(
        saved: _bool(j['saved']),
        conflicts: (j['conflicts'] is List ? j['conflicts'] as List : const [])
            .map((e) => (e as num?)?.toInt() ?? 0)
            .toList(growable: false),
      );
}

// ── support ──────────────────────────────────────────────────────────────────

class SupportTicket {
  const SupportTicket({
    required this.id,
    this.subject,
    this.body,
    this.category,
    this.priority,
    this.status,
    this.createdAt,
  });

  final int id;
  final String? subject;
  final String? body;
  final String? category;
  final String? priority;
  final String? status;
  final String? createdAt;

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: _intd(j['id']),
        subject: _str(j['subject']),
        body: _str(j['body']),
        category: _str(j['category']),
        priority: _str(j['priority']),
        status: _str(j['status']),
        createdAt: _str(j['createdAt']),
      );
}

// ── job lifecycle results (display-only, server-derived) ─────────────────────

class LateFine {
  const LateFine({this.fine = 0, this.severity});
  final int fine;
  final String? severity;

  factory LateFine.fromJson(Map<String, dynamic> j) =>
      LateFine(fine: _intd(j['fine']), severity: _str(j['severity']));
}

class CheckInResult {
  const CheckInResult({
    this.bookingId,
    this.userId,
    this.lateMinutes = 0,
    this.lateFine = const LateFine(),
    this.verdict,
    this.score = 0,
    this.geofenceWithin = false,
    this.distanceM,
  });

  final int? bookingId;
  final int? userId;
  final int lateMinutes;
  final LateFine lateFine;
  final String? verdict; // clean | soft-flag | block
  final int score;
  final bool geofenceWithin;
  final double? distanceM;

  factory CheckInResult.fromJson(Map<String, dynamic> j) => CheckInResult(
        bookingId: _int(j['bookingId']),
        userId: _int(j['userId']),
        lateMinutes: _intd(j['lateMinutes']),
        lateFine: j['lateFine'] is Map<String, dynamic>
            ? LateFine.fromJson(j['lateFine'] as Map<String, dynamic>)
            : const LateFine(),
        verdict: _str(j['verdict']),
        score: _intd(j['score']),
        geofenceWithin: _bool(j['geofenceWithin']),
        distanceM: _dbl(j['distanceM']),
      );
}

class CheckOutResult {
  const CheckOutResult({
    this.checkoutAt,
    this.sessionId,
    this.earningsVnd,
    this.platformFeeVnd = 0,
    this.bookingId,
  });

  final String? checkoutAt;
  final int? sessionId;
  final int? earningsVnd;
  final int platformFeeVnd;
  final int? bookingId;

  factory CheckOutResult.fromJson(Map<String, dynamic> j) => CheckOutResult(
        checkoutAt: _str(j['checkoutAt']),
        sessionId: _int(j['sessionId']),
        earningsVnd: _int(j['earningsVnd']),
        platformFeeVnd: _intd(j['platformFeeVnd']),
        bookingId: _int(j['bookingId']),
      );
}

class StartTrackingResult {
  const StartTrackingResult({this.sessionId, this.sessionStartedAt, this.bookingId});
  final int? sessionId;
  final String? sessionStartedAt;
  final int? bookingId;

  factory StartTrackingResult.fromJson(Map<String, dynamic> j) => StartTrackingResult(
        sessionId: _int(j['sessionId']),
        sessionStartedAt: _str(j['sessionStartedAt']),
        bookingId: _int(j['bookingId']),
      );
}

// ── step-up ──────────────────────────────────────────────────────────────────

/// GET /auth/step-up (A2): whether a fresh grant exists + whether the account
/// can use a password (false → phone-only account, must use OTP).
class StepUpStatus {
  const StepUpStatus({this.fresh = false, this.hasUsablePassword = false});
  final bool fresh;
  final bool hasUsablePassword;

  factory StepUpStatus.fromJson(Map<String, dynamic> j) => StepUpStatus(
        fresh: _bool(j['fresh']),
        hasUsablePassword: _bool(j['hasUsablePassword']),
      );
}
