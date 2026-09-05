// Reviews, providers, subscriptions, plans and notifications — the "social"
// + account-adjacent read models. All parsing tolerant.

class Review {
  const Review({
    required this.id,
    required this.rating,
    this.comment,
    required this.displayName,
    required this.createdAt,
  });
  final int id;
  final int rating;
  final String? comment;
  final String displayName;
  final String createdAt;

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: (j['id'] as num?)?.toInt() ?? 0,
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        comment: j['comment'] as String?,
        displayName: (j['displayName'] as String?) ?? 'Khách',
        createdAt: (j['createdAt'] as String?) ?? '',
      );
}

class ReviewAggregate {
  const ReviewAggregate({required this.count, required this.average});
  final int count;
  final double average;

  factory ReviewAggregate.fromJson(Map<String, dynamic>? j) => ReviewAggregate(
        count: (j?['count'] as num?)?.toInt() ?? 0,
        average: (j?['average'] as num?)?.toDouble() ?? 0,
      );

  static const empty = ReviewAggregate(count: 0, average: 0);
}

class ReviewPage {
  const ReviewPage({required this.reviews, required this.aggregate, this.nextCursor});
  final List<Review> reviews;
  final ReviewAggregate aggregate;
  final int? nextCursor; // numeric review id keyset cursor

  factory ReviewPage.fromJson(Map<String, dynamic> j) => ReviewPage(
        reviews: ((j['reviews'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Review.fromJson)
            .toList(growable: false),
        aggregate: ReviewAggregate.fromJson(j['aggregate'] as Map<String, dynamic>?),
        nextCursor: (j['nextCursor'] as num?)?.toInt(),
      );
}

class ProviderPublicProfile {
  const ProviderPublicProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.tier,
    required this.verified,
    required this.rating,
    required this.jobsCompleted,
    this.joinedAt,
    required this.reviewSummary,
  });
  final int id;
  final String displayName;
  final String? avatarUrl;
  final String tier;
  final bool verified;
  final double rating;
  final int jobsCompleted;
  final String? joinedAt;
  final ReviewAggregate reviewSummary;

  factory ProviderPublicProfile.fromJson(Map<String, dynamic> j) => ProviderPublicProfile(
        id: (j['id'] as num?)?.toInt() ?? 0,
        displayName: (j['displayName'] as String?) ?? (j['name'] as String?) ?? '',
        avatarUrl: j['avatarUrl'] as String?,
        tier: (j['tier'] as String?) ?? 'bronze',
        verified: j['verified'] == true,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        jobsCompleted: (j['jobsCompleted'] as num?)?.toInt() ?? 0,
        joinedAt: j['joinedAt'] as String?,
        reviewSummary: ReviewAggregate.fromJson(j['reviewSummary'] as Map<String, dynamic>?),
      );
}

class SubscriptionItem {
  const SubscriptionItem({
    required this.id,
    this.serviceId,
    required this.frequency,
    required this.status,
    required this.packageMonths,
    required this.monthlyAmountVnd,
    required this.totalAmountVnd,
    this.slotDayOfWeek,
    this.slotTimeMinutes,
    required this.sessionsTotal,
    required this.sessionsCompleted,
    required this.flexCreditsTotal,
    required this.flexCreditsUsed,
    this.nextChargeAt,
    this.startedAt,
  });
  final int id;
  final int? serviceId;
  final String frequency;
  final String status;
  final int packageMonths;
  final int monthlyAmountVnd;
  final int totalAmountVnd;
  final int? slotDayOfWeek;
  final int? slotTimeMinutes;
  final int sessionsTotal;
  final int sessionsCompleted;
  final int flexCreditsTotal;
  final int flexCreditsUsed;
  final String? nextChargeAt;
  final String? startedAt;

  factory SubscriptionItem.fromJson(Map<String, dynamic> j) => SubscriptionItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        serviceId: (j['serviceId'] as num?)?.toInt(),
        frequency: (j['frequency'] as String?) ?? '',
        status: (j['status'] as String?) ?? '',
        packageMonths: (j['packageMonths'] as num?)?.toInt() ?? 0,
        monthlyAmountVnd: (j['monthlyAmountVnd'] as num?)?.toInt() ?? 0,
        totalAmountVnd: (j['totalAmountVnd'] as num?)?.toInt() ?? 0,
        slotDayOfWeek: (j['slotDayOfWeek'] as num?)?.toInt(),
        slotTimeMinutes: (j['slotTimeMinutes'] as num?)?.toInt(),
        sessionsTotal: (j['sessionsTotal'] as num?)?.toInt() ?? 0,
        sessionsCompleted: (j['sessionsCompleted'] as num?)?.toInt() ?? 0,
        flexCreditsTotal: (j['flexCreditsTotal'] as num?)?.toInt() ?? 0,
        flexCreditsUsed: (j['flexCreditsUsed'] as num?)?.toInt() ?? 0,
        nextChargeAt: j['nextChargeAt'] as String?,
        startedAt: j['startedAt'] as String?,
      );
}

/// A public marketing plan card from /v1/plans. Copy fields are snake_case
/// (`title_vi`/`body_vi`); price/duration are optional camelCase. Tolerant of
/// both spellings.
class PlanCard {
  const PlanCard({
    required this.id,
    required this.slug,
    required this.title,
    this.body,
    this.priceMonthlyVnd,
    this.durationMonths,
  });
  final int id;
  final String slug;
  final String title;
  final String? body;
  final int? priceMonthlyVnd;
  final int? durationMonths;

  factory PlanCard.fromJson(Map<String, dynamic> j) => PlanCard(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slug: (j['slug'] as String?) ?? '',
        title: (j['title'] as String?) ??
            (j['title_vi'] as String?) ??
            (j['titleVi'] as String?) ??
            '',
        body: j['body'] as String? ?? j['body_vi'] as String? ?? j['bodyVi'] as String?,
        priceMonthlyVnd: (j['priceMonthlyVnd'] as num?)?.toInt(),
        durationMonths: (j['durationMonths'] as num?)?.toInt(),
      );
}

/// An account notification. Actual API shape: `title`, `body`, `link`,
/// `isRead`, `createdAt`. Tolerant of `subject`/`readAt`/`read` legacy spellings.
class NotificationItem {
  const NotificationItem({
    required this.id,
    this.type,
    required this.title,
    this.body,
    this.link,
    this.createdAt,
    required this.read,
  });
  final int id;
  final String? type;
  final String title;
  final String? body;
  final String? link;
  final String? createdAt;
  final bool read;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: j['type'] as String?,
        title: (j['title'] as String?) ??
            (j['subject'] as String?) ??
            (j['body'] as String?) ??
            '',
        body: j['body'] as String?,
        link: j['link'] as String?,
        createdAt: j['createdAt'] as String?,
        read: j['isRead'] == true || j['readAt'] != null || j['read'] == true,
      );
}
