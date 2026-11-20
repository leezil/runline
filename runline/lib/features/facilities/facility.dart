import 'dart:math' as math;

import 'package:kakao_map_sdk/kakao_map_sdk.dart' show LatLng;

enum FacilityType {
  toilet('화장실'),
  cctv('CCTV');

  const FacilityType(this.label);
  final String label;
}

class Facility {
  const Facility({
    required this.id,
    required this.type,
    required this.name,
    required this.position,
    required this.address,
    required this.description,
    this.sourceDate,
    this.coordinateSource,
  });
  final String id, name, address, description;
  final FacilityType type;
  final LatLng position;
  final String? sourceDate, coordinateSource;

  factory Facility.fromJson(Map<String, dynamic> json) {
    final coordinates = json['location'] as List;
    if (coordinates.length != 2) throw const FormatException('coordinates');
    final lng = (coordinates[0] as num).toDouble();
    final lat = (coordinates[1] as num).toDouble();
    if (!lng.isFinite ||
        !lat.isFinite ||
        lng < 124 ||
        lng > 132 ||
        lat < 32 ||
        lat > 39) {
      throw const FormatException('coordinates');
    }
    final type = FacilityType.values.byName(json['type'] as String);
    final address = json['address'] as Map<String, dynamic>;
    final details = json['details'] as Map<String, dynamic>;
    return Facility(
      id: json['id'] as String,
      type: type,
      name: json['name'] as String,
      position: LatLng(lat, lng),
      address: (address['road'] ?? address['lot'] ?? '') as String,
      description: type == FacilityType.toilet
          ? [
              details['opening_hours_text'],
              details['opening_hours_detail'],
            ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · ')
          : (details['purpose_raw'] as String? ?? ''),
      sourceDate: json['source_date'] as String?,
      coordinateSource: json['coordinate_source'] as String?,
    );
  }
}

class FacilityBounds {
  const FacilityBounds(this.west, this.south, this.east, this.north);
  final double west, south, east, north;
  bool get valid =>
      [west, south, east, north].every((v) => v.isFinite) &&
      124 <= west &&
      west < east &&
      east <= 132 &&
      32 <= south &&
      south < north &&
      north <= 39;
  bool get queryable =>
      valid &&
      (north - south) * 111195 < 9900 &&
      (east - west) * 111195 * math.cos(south * math.pi / 180) < 9900;
  bool contains(FacilityBounds other) =>
      west <= other.west &&
      south <= other.south &&
      east >= other.east &&
      north >= other.north;
  bool containsPoint(LatLng point) =>
      point.longitude >= west &&
      point.longitude <= east &&
      point.latitude >= south &&
      point.latitude <= north;
  String get key =>
      [west, south, east, north].map((v) => v.toStringAsFixed(5)).join(',');
  FacilityBounds get expanded {
    final dx = (east - west) * .15, dy = (north - south) * .15;
    final result = FacilityBounds(
      math.max(124, west - dx),
      math.max(32, south - dy),
      math.min(132, east + dx),
      math.min(39, north + dy),
    );
    return result.queryable ? result : this;
  }
}
