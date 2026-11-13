import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SosPersistedSession {
  final int emergencyId;
  final String idempotencyKey;
  final DateTime startedAt;
  final double latitude;
  final double longitude;
  final double accuracy;

  SosPersistedSession({
    required this.emergencyId,
    required this.idempotencyKey,
    required this.startedAt,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  Map<String, dynamic> toJson() => {
    'emergencyId': emergencyId,
    'idempotencyKey': idempotencyKey,
    'startedAt': startedAt.toIso8601String(),
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
  };

  factory SosPersistedSession.fromJson(Map<String, dynamic> json) => SosPersistedSession(
    emergencyId: json['emergencyId'] as int,
    idempotencyKey: json['idempotencyKey'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    accuracy: (json['accuracy'] as num).toDouble(),
  );
}

/// Service for synchronously persisting active SOS state for crash recovery (Section 16a).
class SosPersistenceService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _sessionKey = 'sos_persisted_active_session';

  /// Synchronously persists active SOS state to local secure storage upon activation
  static Future<void> saveActiveSession({
    required int emergencyId,
    required String idempotencyKey,
    required DateTime startedAt,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final session = SosPersistedSession(
      emergencyId: emergencyId,
      idempotencyKey: idempotencyKey,
      startedAt: startedAt,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
    );

    final jsonStr = jsonEncode(session.toJson());

    try {
      await _secureStorage.write(key: _sessionKey, value: jsonStr);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonStr);
    } catch (_) {}
  }

  /// Retrieves persisted active session if process was killed during SOS
  static Future<SosPersistedSession?> getActiveSession() async {
    try {
      final str = await _secureStorage.read(key: _sessionKey);
      if (str != null && str.isNotEmpty) {
        return SosPersistedSession.fromJson(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_sessionKey);
      if (str != null && str.isNotEmpty) {
        return SosPersistedSession.fromJson(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {}

    return null;
  }

  /// Clears persisted session when emergency is cleanly cancelled or resolved
  static Future<void> clearActiveSession() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }
}
