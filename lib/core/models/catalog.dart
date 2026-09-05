// Catalog + service-listing models. Field names mirror the /v1 handlers
// (ServiceItem / RelatedService / MegamenuCategory). All parsing tolerant.

/// A service list/summary row (services list, related, home rail, city landing).
class ServiceSummary {
  const ServiceSummary({
    required this.id,
    this.slug,
    required this.name,
    this.category,
    this.subcategory,
    required this.basePriceVnd,
    this.durationMinutes,
    this.imageUrl,
  });
  final int id;
  final String? slug;
  final String name;
  final String? category;
  final String? subcategory;
  final int basePriceVnd;
  final int? durationMinutes;
  final String? imageUrl;

  factory ServiceSummary.fromJson(Map<String, dynamic> j) => ServiceSummary(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slug: j['slug'] as String?,
        name: (j['name'] as String?) ?? '',
        category: j['category'] as String?,
        subcategory: j['subcategory'] as String?,
        basePriceVnd: (j['basePriceVnd'] as num?)?.toInt() ??
            (j['base_price_vnd'] as num?)?.toInt() ??
            0,
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ??
            (j['duration_minutes'] as num?)?.toInt(),
        imageUrl: j['imageUrl'] as String? ?? j['image_url'] as String?,
      );
}

/// Full service detail — a [ServiceSummary] plus a description.
class ServiceDetail extends ServiceSummary {
  const ServiceDetail({
    required super.id,
    super.slug,
    required super.name,
    super.category,
    super.subcategory,
    required super.basePriceVnd,
    super.durationMinutes,
    super.imageUrl,
    this.description,
  });
  final String? description;

  factory ServiceDetail.fromJson(Map<String, dynamic> j) {
    final s = ServiceSummary.fromJson(j);
    return ServiceDetail(
      id: s.id,
      slug: s.slug,
      name: s.name,
      category: s.category,
      subcategory: s.subcategory,
      basePriceVnd: s.basePriceVnd,
      durationMinutes: s.durationMinutes,
      imageUrl: s.imageUrl,
      description: j['description'] as String?,
    );
  }
}

/// A leaf service in the catalog megamenu tree.
class CatalogService {
  const CatalogService({required this.id, required this.name, this.nameEn});
  final int id;
  final String name;
  final String? nameEn;

  String displayName(String locale) =>
      (locale == 'en' && nameEn != null && nameEn!.isNotEmpty) ? nameEn! : name;

  factory CatalogService.fromJson(Map<String, dynamic> j) => CatalogService(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? (j['nameVi'] as String?) ?? '',
        nameEn: j['nameEn'] as String?,
      );
}

class CatalogSubcategory {
  const CatalogSubcategory({
    required this.slug,
    required this.nameVi,
    this.nameEn,
    this.services = const [],
  });
  final String slug;
  final String nameVi;
  final String? nameEn;
  final List<CatalogService> services;

  String displayName(String locale) =>
      (locale == 'en' && nameEn != null && nameEn!.isNotEmpty) ? nameEn! : nameVi;

  factory CatalogSubcategory.fromJson(Map<String, dynamic> j) => CatalogSubcategory(
        slug: (j['slug'] as String?) ?? '',
        nameVi: (j['nameVi'] as String?) ?? (j['name'] as String?) ?? '',
        nameEn: j['nameEn'] as String?,
        services: ((j['services'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogService.fromJson)
            .toList(growable: false),
      );
}

class CatalogCategory {
  const CatalogCategory({
    required this.slug,
    required this.nameVi,
    this.nameEn,
    this.icon,
    this.subcategories = const [],
    this.looseServices = const [],
  });
  final String slug;
  final String nameVi;
  final String? nameEn;
  final String? icon;
  final List<CatalogSubcategory> subcategories;
  final List<CatalogService> looseServices;

  String displayName(String locale) =>
      (locale == 'en' && nameEn != null && nameEn!.isNotEmpty) ? nameEn! : nameVi;

  factory CatalogCategory.fromJson(Map<String, dynamic> j) => CatalogCategory(
        slug: (j['slug'] as String?) ?? '',
        nameVi: (j['nameVi'] as String?) ?? (j['name'] as String?) ?? '',
        nameEn: j['nameEn'] as String?,
        icon: j['icon'] as String?,
        subcategories: ((j['subcategories'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogSubcategory.fromJson)
            .toList(growable: false),
        looseServices: ((j['looseServices'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogService.fromJson)
            .toList(growable: false),
      );
}

/// A search hit from /v1/search (kind = service|provider|city).
class SearchHit {
  const SearchHit({
    required this.kind,
    required this.id,
    required this.title,
    this.snippet,
    required this.href,
    required this.score,
  });
  final String kind;
  final int id;
  final String title;
  final String? snippet;
  final String href;
  final double score;

  factory SearchHit.fromJson(Map<String, dynamic> j) => SearchHit(
        kind: (j['kind'] as String?) ?? 'service',
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] as String?) ?? '',
        snippet: j['snippet'] as String?,
        href: (j['href'] as String?) ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
      );
}

/// Generic cursor-paginated page (envelope `meta:{nextCursor,hasMore}`).
class Paged<T> {
  const Paged({required this.items, this.nextCursor, this.hasMore = false});
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  static Paged<T> of<T>(List<T> items, Map<String, dynamic> meta) => Paged<T>(
        items: items,
        nextCursor: meta['nextCursor'] is String ? meta['nextCursor'] as String : null,
        hasMore: meta['hasMore'] == true,
      );
}
