import 'package:cloud_firestore/cloud_firestore.dart';

enum LocationSource { gps, manual }

class UserLocation {
  final double lat;
  final double lng;
  final String city;
  final String region;
  final String country;
  final LocationSource source;
  final DateTime updatedAt;

  const UserLocation({
    required this.lat,
    required this.lng,
    required this.city,
    required this.region,
    required this.country,
    required this.source,
    required this.updatedAt,
  });

  /// Parses a "City, Region, Country" label. Lat/lng default to 0 —
  /// the LocationService forward-geocode path is the supported way
  /// to get real coordinates from a label.
  factory UserLocation.manual(String label) {
    final parts = label
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final city = parts.isNotEmpty ? parts[0] : label.trim();
    final region = parts.length >= 2 ? parts[1] : '';
    final country = parts.length >= 3 ? parts[2] : 'US';
    return UserLocation(
      lat: 0,
      lng: 0,
      city: city,
      region: region,
      country: country,
      source: LocationSource.manual,
      updatedAt: DateTime.now(),
    );
  }

  /// "City, Region", with graceful fallback when reverse-geocoding
  /// only returned partial data.
  String get displayLabel {
    if (city.isNotEmpty && region.isNotEmpty) return '$city, $region';
    if (city.isNotEmpty) return city;
    if (region.isNotEmpty) return region;
    if (country.isNotEmpty) return country;
    return 'Location set';
  }

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'city': city,
    'region': region,
    'country': country,
    'source': source.name,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    final sourceStr = map['source'] as String?;
    return UserLocation(
      lat: (map['lat'] as num?)?.toDouble() ?? 0,
      lng: (map['lng'] as num?)?.toDouble() ?? 0,
      city: (map['city'] as String?) ?? '',
      region: (map['region'] as String?) ?? '',
      country: (map['country'] as String?) ?? '',
      source: LocationSource.values.firstWhere(
        (s) => s.name == sourceStr,
        orElse: () => LocationSource.gps,
      ),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
