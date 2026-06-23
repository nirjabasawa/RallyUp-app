import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';

import '../models/user_location.dart';

enum LocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  geocodingFailed,
  unknown,
}

class LocationFailure implements Exception {
  final LocationFailureReason reason;
  final String? detail;
  const LocationFailure(this.reason, [this.detail]);

  @override
  String toString() =>
      'LocationFailure($reason${detail != null ? ': $detail' : ''})';
}

/// One-call GPS capture + reverse geocode → [UserLocation].
class LocationService {
  Future<UserLocation> captureCurrent() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationFailure(LocationFailureReason.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        LocationFailureReason.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure(LocationFailureReason.permissionDenied);
    }

    // Medium accuracy is plenty for a city label and saves battery.
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // Reverse-geocode is best-effort — offline emulators throw.
    String city = '';
    String region = '';
    String country = '';
    try {
      final placemarks = await gc.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality ?? p.subAdministrativeArea ?? p.subLocality ?? '';
        region = p.administrativeArea ?? '';
        country = p.country ?? '';
      }
    } catch (_) {}

    return UserLocation(
      lat: pos.latitude,
      lng: pos.longitude,
      city: city,
      region: region,
      country: country,
      source: LocationSource.gps,
      updatedAt: DateTime.now(),
    );
  }

  /// Resolve a user-picked label (e.g. "Cupertino, CA") into a
  /// [UserLocation] with real lat/lng. Forward-geocodes the label,
  /// reverse-geocodes the coordinates for city/region/country, and
  /// falls back to parsing the label itself when reverse-geocode
  /// returns nothing.
  ///
  /// Throws [LocationFailureReason.geocodingFailed] when the label
  /// can't be resolved at all, so the caller can show a targeted
  /// message rather than silently persisting (0, 0).
  Future<UserLocation> resolveManualLocation(String label) async {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw const LocationFailure(
        LocationFailureReason.geocodingFailed,
        'Empty label',
      );
    }

    List<gc.Location> locations;
    try {
      locations = await gc.locationFromAddress(trimmed);
    } catch (e) {
      throw LocationFailure(
        LocationFailureReason.geocodingFailed,
        e.toString(),
      );
    }
    if (locations.isEmpty) {
      throw const LocationFailure(
        LocationFailureReason.geocodingFailed,
        'No results for label',
      );
    }

    final first = locations.first;
    final lat = first.latitude;
    final lng = first.longitude;

    String city = '';
    String region = '';
    String country = '';
    try {
      final placemarks = await gc.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        city = p.locality ?? p.subAdministrativeArea ?? p.subLocality ?? '';
        region = p.administrativeArea ?? '';
        country = p.country ?? '';
      }
    } catch (_) {}

    if (city.isEmpty && region.isEmpty && country.isEmpty) {
      final parsed = UserLocation.manual(trimmed);
      city = parsed.city;
      region = parsed.region;
      country = parsed.country;
    }

    return UserLocation(
      lat: lat,
      lng: lng,
      city: city,
      region: region,
      country: country,
      source: LocationSource.manual,
      updatedAt: DateTime.now(),
    );
  }
}
