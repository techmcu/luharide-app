import 'package:geolocator/geolocator.dart';

/// Result of a current-location request.
class LocationResult {
  final double? lat;
  final double? lng;
  final String? error; // user-friendly message when lat/lng is null
  const LocationResult({this.lat, this.lng, this.error});
  bool get ok => lat != null && lng != null;
}

/// Thin wrapper around geolocator for the "use my current location" feature.
/// Handles the service-enabled check + permission flow and returns a friendly
/// error string instead of throwing, so the UI stays simple.
class LocationService {
  /// Fast, silent last-known location (no permission prompt, no GPS fix).
  /// Used only to bias suggestions toward the user. Returns null if unavailable.
  Future<LocationResult> getLastKnownQuiet() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return const LocationResult(error: 'no-permission');
      }
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return const LocationResult(error: 'no-fix');
      return LocationResult(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return const LocationResult(error: 'error');
    }
  }

  Future<LocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(error: 'Location is off. Turn on GPS and try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(error: 'Location permission denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          error: 'Location permission is blocked. Enable it in app settings.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // enough for nearby matching, faster + battery-friendly
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LocationResult(lat: pos.latitude, lng: pos.longitude);
    } catch (e) {
      return const LocationResult(error: 'Could not get your location. Try again.');
    }
  }
}
