import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rain/core/utils/location_label.dart';

/// Wraps Geolocator and geocoding — the only layer that talks to platform GPS APIs.
///
/// Callers enabling location should check [isServiceEnabled] before
/// [getCurrentPlace] or [determinePosition] so the UI can prompt the user.
class LocationService {
  /// Returns the current GPS position after requesting permissions if needed.
  Future<Position> determinePosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }
    return Geolocator.getCurrentPosition();
  }

  /// Resolves coordinates and a human-readable address.
  ///
  /// Platform reverse geocoding runs first; when it fails, [resolveLabels] (e.g.
  /// Nominatim) is used. Returns `null` only when labels cannot be resolved.
  Future<({double lat, double lon, String city, String district, String address})?>
  getCurrentPlace({
    Future<({String city, String district, String address})?> Function(
      double lat,
      double lon,
    )?
    resolveLabels,
  }) async {
    final position = await determinePosition();

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = parsePlaceFromPlacemarks(position, placemarks);
      if (place != null) return place;
    } catch (_) {
      // Platform geocoder failed; network fallback may still resolve labels.
    }

    if (resolveLabels != null) {
      try {
        final labels = await resolveLabels(
          position.latitude,
          position.longitude,
        );
        if (labels != null &&
            (hasNonEmptyLocationText(labels.city) ||
                hasNonEmptyLocationText(labels.district) ||
                hasNonEmptyLocationText(labels.address))) {
          return (
            lat: position.latitude,
            lon: position.longitude,
            city: labels.city,
            district: labels.district,
            address: labels.address,
          );
        }
      } catch (_) {
        // Ignore fallback failures; caller handles unresolved place below.
      }
    }

    return null;
  }

  /// Builds a place record from GPS coordinates and geocoding results.
  @visibleForTesting
  static ({double lat, double lon, String city, String district, String address})?
  parsePlaceFromPlacemarks(Position position, List<Placemark> placemarks) {
    if (placemarks.isEmpty) return null;
    final place = placemarks.first;
    final city = firstNonEmptyLocationLabel([
      place.locality,
      place.subAdministrativeArea,
      place.subLocality,
      place.name,
    ]);
    final district = firstNonEmptyLocationLabel([
      place.administrativeArea,
      place.subAdministrativeArea,
    ]);
    final address = formatPlacemarkAddress(place);
    if (city.isEmpty && district.isEmpty && address.isEmpty) return null;
    return (
      lat: position.latitude,
      lon: position.longitude,
      city: city,
      district: district,
      address: address,
    );
  }

  /// Orders the most useful placemark parts for a compact widget address.
  @visibleForTesting
  static String formatPlacemarkAddress(Placemark place) {
    final street = firstNonEmptyLocationLabel([
      place.thoroughfare,
      place.street,
    ]);
    final name = place.name?.trim() ?? '';
    final houseNumber = firstNonEmptyLocationLabel([
      place.subThoroughfare,
      RegExp(r'\d').hasMatch(name) ? name : null,
    ]);
    final placeName =
        name.isNotEmpty && name != houseNumber && name != street ? name : null;
    final parts = [
      place.subLocality,
      place.administrativeArea,
      place.locality,
      place.subAdministrativeArea,
      placeName,
      street,
      houseNumber,
    ];
    final unique = <String>[];
    for (final value in parts) {
      final text = value?.trim();
      if (text == null || text.isEmpty || unique.contains(text)) continue;
      unique.add(text);
    }
    return unique.join(' ');
  }

  /// Whether the device location service is enabled at the OS level.
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Opens the system location settings screen.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
