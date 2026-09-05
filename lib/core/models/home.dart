import 'catalog.dart';

/// A service category from the /v1/home composite (image resolved server-side).
class ServiceCategory {
  const ServiceCategory({required this.id, required this.name, this.imageUrl, this.slug});
  final int id;
  final String name;
  final String? imageUrl;
  final String? slug;

  factory ServiceCategory.fromJson(Map<String, dynamic> j) => ServiceCategory(
        id: (j['id'] as num).toInt(),
        name: (j['name'] as String?) ?? '',
        imageUrl: j['imageUrl'] as String? ?? j['image_url'] as String?,
        slug: j['slug'] as String?,
      );
}

/// A why-Kyco / how-it-works content block. Locale already resolved server-side
/// but tolerate both `title`/`titleVi` and `body`/`bodyVi` spellings.
class ContentSection {
  const ContentSection({
    required this.id,
    required this.slug,
    required this.title,
    this.body,
    this.orderIndex = 0,
  });
  final int id;
  final String slug;
  final String title;
  final String? body;
  final int orderIndex;

  factory ContentSection.fromJson(Map<String, dynamic> j) => ContentSection(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slug: (j['slug'] as String?) ?? '',
        title: (j['title'] as String?) ?? (j['titleVi'] as String?) ?? '',
        body: j['body'] as String? ?? j['bodyVi'] as String?,
        orderIndex: (j['orderIndex'] as num?)?.toInt() ??
            (j['order_index'] as num?)?.toInt() ??
            0,
      );
}

class HomeGeoProvince {
  const HomeGeoProvince({required this.code, required this.name});
  final int code;
  final String name;

  factory HomeGeoProvince.fromJson(Map<String, dynamic> j) => HomeGeoProvince(
        code: (j['code'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
      );
}

class HomeGeoWard {
  const HomeGeoWard({required this.code, required this.name, required this.provinceCode});
  final int code;
  final String name;
  final int provinceCode;

  factory HomeGeoWard.fromJson(Map<String, dynamic> j) => HomeGeoWard(
        code: (j['code'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        provinceCode: (j['provinceCode'] as num?)?.toInt() ??
            (j['province_code'] as num?)?.toInt() ??
            0,
      );
}

class HomeSearchGeo {
  const HomeSearchGeo({this.provinces = const [], this.wardRows = const []});
  final List<HomeGeoProvince> provinces;
  final List<HomeGeoWard> wardRows;

  factory HomeSearchGeo.fromJson(Map<String, dynamic> j) => HomeSearchGeo(
        provinces: ((j['provinces'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(HomeGeoProvince.fromJson)
            .toList(growable: false),
        wardRows: ((j['wardRows'] as List?) ?? (j['wards'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(HomeGeoWard.fromJson)
            .toList(growable: false),
      );
}

/// The home landing composite. Parsed leniently — every extended block defaults
/// empty so a missing section never throws.
class HomeComposite {
  const HomeComposite({
    required this.categories,
    this.greetingName,
    this.services = const [],
    this.why = const [],
    this.how = const [],
    this.geo,
  });
  final List<ServiceCategory> categories;
  final String? greetingName;
  final List<ServiceSummary> services;
  final List<ContentSection> why;
  final List<ContentSection> how;
  final HomeSearchGeo? geo;

  factory HomeComposite.fromJson(Map<String, dynamic> j) {
    List<ContentSection> content(String key) {
      final c = j['content'];
      if (c is! Map) return const [];
      final list = c[key];
      if (list is! List) return const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(ContentSection.fromJson)
          .toList(growable: false);
    }

    return HomeComposite(
      categories: ((j['categories'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ServiceCategory.fromJson)
          .toList(growable: false),
      greetingName: j['greetingName'] as String? ?? j['greeting'] as String?,
      services: ((j['services'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ServiceSummary.fromJson)
          .toList(growable: false),
      why: content('why'),
      how: content('how'),
      geo: j['geo'] is Map<String, dynamic>
          ? HomeSearchGeo.fromJson(j['geo'] as Map<String, dynamic>)
          : null,
    );
  }
}
