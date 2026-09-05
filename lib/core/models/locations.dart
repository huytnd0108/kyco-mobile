import 'catalog.dart';

/// Active service-area geography (from /v1/locations/tree and /v1/city/:slug).
class ActiveWard {
  const ActiveWard({
    required this.code,
    required this.name,
    this.divisionType,
    required this.provinceCode,
  });
  final int code;
  final String name;
  final String? divisionType;
  final int provinceCode;

  factory ActiveWard.fromJson(Map<String, dynamic> j) => ActiveWard(
        code: (j['code'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        divisionType: j['divisionType'] as String? ?? j['division_type'] as String?,
        provinceCode: (j['provinceCode'] as num?)?.toInt() ??
            (j['province_code'] as num?)?.toInt() ??
            0,
      );
}

class ActiveCity {
  const ActiveCity({
    required this.id,
    this.code,
    required this.slug,
    required this.name,
    this.divisionType,
    this.wards = const [],
  });
  final int id;
  final int? code;
  final String slug;
  final String name;
  final String? divisionType;
  final List<ActiveWard> wards;

  factory ActiveCity.fromJson(Map<String, dynamic> j) => ActiveCity(
        id: (j['id'] as num?)?.toInt() ?? 0,
        code: (j['code'] as num?)?.toInt(),
        slug: (j['slug'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        divisionType: j['divisionType'] as String? ?? j['division_type'] as String?,
        wards: ((j['wards'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ActiveWard.fromJson)
            .toList(growable: false),
      );
}

class Neighborhood {
  const Neighborhood({required this.id, required this.name, this.kind});
  final int id;
  final String name;
  final String? kind;

  factory Neighborhood.fromJson(Map<String, dynamic> j) => Neighborhood(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] as String?) ?? '',
        kind: j['kind'] as String?,
      );
}

class CityInfo {
  const CityInfo({required this.id, required this.slug, required this.name, this.code});
  final int id;
  final String slug;
  final String name;
  final int? code;

  factory CityInfo.fromJson(Map<String, dynamic> j) => CityInfo(
        id: (j['id'] as num?)?.toInt() ?? 0,
        slug: (j['slug'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        code: (j['code'] as num?)?.toInt(),
      );
}

class CityLanding {
  const CityLanding({required this.city, this.services = const []});
  final CityInfo city;
  final List<ServiceSummary> services;

  factory CityLanding.fromJson(Map<String, dynamic> j) => CityLanding(
        city: CityInfo.fromJson(
            (j['city'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
        services: ((j['services'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ServiceSummary.fromJson)
            .toList(growable: false),
      );
}
