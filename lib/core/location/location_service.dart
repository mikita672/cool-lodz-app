import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Why the user's position is not available.
enum LocationProblem {
  /// Location is switched off in the system.
  serviceOff,

  /// The app may ask for the permission.
  denied,

  /// Denied for good: only the system settings can change it.
  deniedForever,

  /// Permission is fine, but no fix came in time.
  noFix,
}

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.problem);

  final LocationProblem problem;

  @override
  String toString() => 'LocationUnavailable(${problem.name})';
}

/// The user's position, only while the app is in use (spec: "location only
/// while the app is in use"), no track is stored.
abstract interface class LocationService {
  /// Current position. Asks for the permission if it was not decided yet.
  /// Throws [LocationUnavailable].
  Future<LatLng> current();

  /// Null when the position can be read, otherwise the reason.
  Future<LocationProblem?> check();

  /// Shows the Android permission dialog (or the settings page when the
  /// permission is denied forever / location is off).
  Future<void> enable();
}

class GeolocatorLocationService implements LocationService {
  /// A fix older than this is not "current".
  static const maxLastKnownAge = Duration(minutes: 2);
  static const fixTimeout = Duration(seconds: 10);

  @override
  Future<LocationProblem?> check() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationProblem.serviceOff;
      }
      return switch (await Geolocator.checkPermission()) {
        LocationPermission.denied => LocationProblem.denied,
        LocationPermission.deniedForever => LocationProblem.deniedForever,
        _ => null,
      };
    } catch (e) {
      debugPrint('Location check failed: $e');
      return LocationProblem.noFix;
    }
  }

  @override
  Future<void> enable() async {
    try {
      switch (await check()) {
        case LocationProblem.serviceOff:
          await Geolocator.openLocationSettings();
        case LocationProblem.denied:
          await Geolocator.requestPermission();
        case LocationProblem.deniedForever:
          await Geolocator.openAppSettings();
        case LocationProblem.noFix || null:
          break;
      }
    } catch (e) {
      debugPrint('Enabling location failed: $e');
    }
  }

  @override
  Future<LatLng> current() async {
    var problem = await check();
    if (problem == LocationProblem.denied) {
      try {
        await Geolocator.requestPermission();
      } catch (e) {
        debugPrint('Location permission request failed: $e');
      }
      problem = await check();
    }
    if (problem != null) throw LocationUnavailable(problem);

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp) < maxLastKnownAge) {
        return LatLng(last.latitude, last.longitude);
      }
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: fixTimeout,
        ),
      );
      return LatLng(fix.latitude, fix.longitude);
    } catch (e) {
      debugPrint('No location fix: $e');
      throw const LocationUnavailable(LocationProblem.noFix);
    }
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => GeolocatorLocationService(),
);

/// Center of Śródmieście (Plac Wolności area): the map's start point when
/// the user's position is unknown (S05).
const lodzCenter = LatLng(51.7700, 19.4570);
