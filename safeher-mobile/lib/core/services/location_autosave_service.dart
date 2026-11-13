import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedLocationRecord {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final bool isFresh;

  SavedLocationRecord({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.isFresh = true,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
    'isFresh': isFresh,
  };

  factory SavedLocationRecord.fromJson(Map<String, dynamic> json) => SavedLocationRecord(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    accuracy: (json['accuracy'] as num).toDouble(),
    timestamp: DateTime.parse(json['timestamp'] as String),
    isFresh: json['isFresh'] as bool? ?? false,
  );
}

/// Independent local safety record service (Section 2a).
/// Every location reading obtained by the app is written to local secure storage
/// immediately, tagged with timestamp and accuracy.
class LocationAutoSaveService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _keyLat = 'autosave_last_latitude';
  static const String _keyLng = 'autosave_last_longitude';
  static const String _keyAccuracy = 'autosave_last_accuracy';
  static const String _keyTimestamp = 'autosave_last_timestamp';

  /// Save location reading immediately to secure storage (with SharedPreferences fallback)
  static Future<void> saveLocation({
    required double latitude,
    required double longitude,
    required double accuracy,
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    try {
      await _secureStorage.write(key: _keyLat, value: latitude.toString());
      await _secureStorage.write(key: _keyLng, value: longitude.toString());
      await _secureStorage.write(key: _keyAccuracy, value: accuracy.toString());
      await _secureStorage.write(key: _keyTimestamp, value: now.toIso8601String());
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_keyLat, latitude);
        await prefs.setDouble(_keyLng, longitude);
        await prefs.setDouble(_keyAccuracy, accuracy);
        await prefs.setString(_keyTimestamp, now.toIso8601String());
      } catch (_) {}
    }
  }

  /// Retrieve the most recent saved location record
  static Future<SavedLocationRecord?> getLastSavedLocation() async {
    try {
      final latStr = await _secureStorage.read(key: _keyLat);
      final lngStr = await _secureStorage.read(key: _keyLng);
      final accStr = await _secureStorage.read(key: _keyAccuracy);
      final timeStr = await _secureStorage.read(key: _keyTimestamp);

      if (latStr != null && lngStr != null && accStr != null && timeStr != null) {
        final timestamp = DateTime.parse(timeStr);
        final age = DateTime.now().difference(timestamp);
        final isFresh = age.inSeconds < 30;

        return SavedLocationRecord(
          latitude: double.parse(latStr),
          longitude: double.parse(lngStr),
          accuracy: double.parse(accStr),
          timestamp: timestamp,
          isFresh: isFresh,
        );
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_keyLat);
      final lng = prefs.getDouble(_keyLng);
      final acc = prefs.getDouble(_keyAccuracy);
      final timeStr = prefs.getString(_keyTimestamp);

      if (lat != null && lng != null && acc != null && timeStr != null) {
        final timestamp = DateTime.parse(timeStr);
        final age = DateTime.now().difference(timestamp);
        final isFresh = age.inSeconds < 30;

        return SavedLocationRecord(
          latitude: lat,
          longitude: lng,
          accuracy: acc,
          timestamp: timestamp,
          isFresh: isFresh,
        );
      }
    } catch (_) {}

    return null;
  }
}
