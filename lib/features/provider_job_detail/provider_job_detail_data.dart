import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kyco_mobile/l10n/app_localizations.dart';

import '../../core/api/kyco_api.dart';
import '../../core/di.dart';
import '../../core/models.dart';

/// The lifecycle-hub read (A8). `.family` on the job id; `.autoDispose` so a
/// pushed-then-popped detail doesn't keep a stale payload alive. Backend route
/// A8 is dark-launched (503 until `api_mobile_v1_enabled`) — the screen renders
/// the AsyncValue loading/error states until it deploys.
final providerJobDetailProvider =
    FutureProvider.autoDispose.family<ProviderJobDetail, int>((ref, id) async {
  return ref.watch(kycoApiProvider).providerJobDetail(id);
});

// ── pure lifecycle helpers (mirror lib/jobs/photo-count.ts + the web page) ────

/// Per-slot photo quota (owner 2026-06-08 spec): check-OUT needs ≥2 "before";
/// mark-COMPLETE needs ≥2 before + ≥1 mid + ≥2 after. Server re-enforces both;
/// these drive the inline gate UI so the CTV sees what's short before tapping.
const int kBeforePhotosRequired = 2;
const int kMidPhotosRequired = 1;
const int kAfterPhotosRequired = 2;
int get kPhotosTotalRequired =>
    kBeforePhotosRequired + kMidPhotosRequired + kAfterPhotosRequired;

/// The three capture slots. `before` maps to the check-in category, `mid`/`after`
/// to check-out — mirrors the web uploader's slot→category mapping.
enum PhotoSlot { before, mid, after }

extension PhotoSlotApi on PhotoSlot {
  String get wire => switch (this) {
        PhotoSlot.before => 'before',
        PhotoSlot.mid => 'mid',
        PhotoSlot.after => 'after',
      };
}

/// Counts valid entries in one slot's JSONB array. Accepts the union the web
/// migration produced: legacy `string` URL entries and `{mediaId:int}` objects.
int countSlotPhotos(dynamic value) {
  if (value is! List) return 0;
  var n = 0;
  for (final p in value) {
    if (p is String && p.isNotEmpty) {
      n += 1;
    } else if (p is Map && p['mediaId'] is num) {
      n += 1;
    }
  }
  return n;
}

/// Per-slot + total photo counts read off the job map.
class PhotoCounts {
  const PhotoCounts(this.before, this.mid, this.after);
  final int before, mid, after;
  int get total => before + mid + after;

  factory PhotoCounts.ofJob(Map<String, dynamic> job) => PhotoCounts(
        countSlotPhotos(job['beforePhotos']),
        countSlotPhotos(job['midPhotos']),
        countSlotPhotos(job['afterPhotos']),
      );

  int get missingBefore => (kBeforePhotosRequired - before).clamp(0, kBeforePhotosRequired);
  int get missingMid => (kMidPhotosRequired - mid).clamp(0, kMidPhotosRequired);
  int get missingAfter => (kAfterPhotosRequired - after).clamp(0, kAfterPhotosRequired);

  bool get meetsCheckout => before >= kBeforePhotosRequired;
  bool get meetsComplete =>
      before >= kBeforePhotosRequired &&
      mid >= kMidPhotosRequired &&
      after >= kAfterPhotosRequired;
}

/// The lifecycle "phase" the hub renders around. Derived from the loose job +
/// booking maps exactly like the web page's cascade of guards — never computed
/// from money and never trusted as authoritative (the server gates every action).
enum JobPhase {
  pending, // job.status == 'pending' — confirm / decline / cancel
  enRoute, // active, not yet checked in — start-tracking + check-in
  onSite, // active, checked in, not checked out — photos / face / check-out
  wrapUp, // active, checked in + out — mark-complete (photo-gated)
  awaitingCustomer, // booking AWAITING_CUSTOMER_CONFIRMATION
  awaitingCash, // booking AWAITING_CASH_CONFIRM (cash → cash-received)
  awaitingPayment, // booking AWAITING_PAYMENT
  settled, // booking SETTLED — "Kyco đã trả 80%"
  closed, // job.status == 'closed' / booking CLOSED|COMPLETED
  cancelled, // booking CANCELLED / job cancelled
  unknown,
}

String _s(dynamic v) => v == null ? '' : v.toString();

JobPhase deriveJobPhase(ProviderJobDetail d) {
  final jobStatus = _s(d.job['status']).toLowerCase();
  final bookingStatus = _s(d.booking?['status']).toUpperCase();

  if (bookingStatus == 'CANCELLED' || jobStatus == 'cancelled') return JobPhase.cancelled;
  if (bookingStatus == 'SETTLED') return JobPhase.settled;
  if (bookingStatus == 'AWAITING_CASH_CONFIRM') return JobPhase.awaitingCash;
  if (bookingStatus == 'AWAITING_PAYMENT') return JobPhase.awaitingPayment;
  if (bookingStatus == 'AWAITING_CUSTOMER_CONFIRMATION') return JobPhase.awaitingCustomer;

  if (jobStatus == 'pending') return JobPhase.pending;
  if (jobStatus == 'closed' || bookingStatus == 'CLOSED' || bookingStatus == 'COMPLETED') {
    return JobPhase.closed;
  }
  if (jobStatus == 'active') {
    if (!d.hasCheckedIn) return JobPhase.enRoute;
    if (!d.hasCheckedOut) return JobPhase.onSite;
    return JobPhase.wrapUp;
  }
  return JobPhase.unknown;
}

/// The booking has moved past the point where SOS / check-out / live-share are
/// meaningful. Mirrors the web `bookingDone` gate.
bool bookingIsDone(ProviderJobDetail d) {
  const done = {
    'AWAITING_CUSTOMER_CONFIRMATION', 'AWAITING_PAYMENT', 'AWAITING_CASH_CONFIRM',
    'IN_DISPUTE', 'SETTLED', 'CLOSED', 'COMPLETED', 'BAD_DEBT', 'CANCELLED',
  };
  return done.contains(_s(d.booking?['status']).toUpperCase());
}

/// The check-out window is still open. Mirrors the web PAST_CHECKOUT guard.
bool checkoutWindowOpen(ProviderJobDetail d) {
  const past = {
    'COMPLETED', 'CANCELLED', 'AWAITING_CUSTOMER_CONFIRMATION', 'AWAITING_PAYMENT',
    'AWAITING_CASH_CONFIRM', 'IN_DISPUTE', 'SETTLED', 'BAD_DEBT', 'CLOSED',
  };
  return !past.contains(_s(d.booking?['status']).toUpperCase());
}

/// Whether the SOS safety channel is live (active + on-site + booking not done).
bool sosEnabled(ProviderJobDetail d) =>
    _s(d.job['status']).toLowerCase() == 'active' && d.hasCheckedIn && !bookingIsDone(d);

/// Pull the server-derived money figures out of a mutation response WITHOUT ever
/// computing one locally. Returns the `*Vnd` integer keys present in [resp],
/// preserving insertion order so the panel can list exactly what the server sent.
Map<String, int> serverMoneyFields(Map<String, dynamic> resp) {
  final out = <String, int>{};
  void scan(Map<String, dynamic> m) {
    for (final e in m.entries) {
      final v = e.value;
      if (e.key.toLowerCase().endsWith('vnd') && v is num) {
        out[e.key] = v.toInt();
      } else if (v is Map<String, dynamic>) {
        scan(v);
      }
    }
  }

  scan(resp);
  return out;
}

/// A human label for a `*Vnd` money key (localized). Falls back to the raw key.
String moneyFieldLabel(String key, AppLocalizations l) {
  switch (key) {
    case 'commissionVnd':
    case 'cashCommissionVnd':
      return l.provJdCommission20;
    case 'payoutVnd':
    case 'netVnd':
    case 'earningsVnd':
      return l.provJdYourEarnings;
    case 'balanceVnd':
    case 'newBalanceVnd':
      return l.provJdWalletBalance;
    case 'totalVnd':
      return l.provJdOrderTotal;
    case 'fineVnd':
    case 'penaltyVnd':
      return l.provJdFine;
    default:
      return key;
  }
}

/// Localized date/time for an ISO string (dd/MM · HH:mm), matching the web
/// `fmtMs`. Falls back to the raw string / em-dash.
String fmtJobTime(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  final l = d.toLocal();
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${p2(l.day)}/${p2(l.month)} · ${p2(l.hour)}:${p2(l.minute)}';
}
