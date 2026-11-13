import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/services/location_autosave_service.dart';

class LocationService {
  /// Obtains a FRESH current GPS location fix with high accuracy and bounded timeout (Section 2 & 4).
  /// Strictly does NOT fall back to stale OS getLastKnownPosition().
  /// Automatically writes every fix to LocationAutoSaveService (Section 2a).
  static Future<Position?> getCurrentLocation({
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    return getFreshCurrentLocation(timeLimit: timeLimit);
  }

  /// Obtains a FRESH GPS fix without stale cache fallback
  static Future<Position?> getFreshCurrentLocation({
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location services disabled on device');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] Location permission denied by user');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission permanently denied');
        return null;
      }

      // Fresh reading only — no getLastKnownPosition()
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeLimit,
      );

      // Section 2a: Local auto-save of every obtained reading
      await LocationAutoSaveService.saveLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );

      return position;
    } catch (e) {
      debugPrint('[LocationService] Error acquiring fresh GPS fix: $e');
      return null;
    }
  }

  /// Returns a location stream with concrete distance filter (15-20 meters per Section 6)
  static Stream<Position> getPositionStream({
    int distanceFilter = 15,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
