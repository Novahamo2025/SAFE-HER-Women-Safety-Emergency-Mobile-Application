import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _secureStorage = FlutterSecureStorage();

  static const String _keyAccessToken = 'safeher_access_token';
  static const String _keyRefreshToken = 'safeher_refresh_token';
  static const String _keyUserPin = 'safeher_user_pin';
  static const String _keyOfflineSosQueue = 'safeher_offline_sos_queue';

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _keyAccessToken);
  }

  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
  }

  static Future<void> saveUserPin(String pin) async {
    await _secureStorage.write(key: _keyUserPin, value: pin);
  }

  static Future<String?> getUserPin() async {
    return await _secureStorage.read(key: _keyUserPin);
  }

  // Offline SOS queue persistence (Blocker 4: Dead zone resiliency)
  static Future<void> queueOfflineEmergency(Map<String, dynamic> eventData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_keyOfflineSosQueue) ?? [];
    queue.add(jsonEncode(eventData));
    await prefs.setStringList(_keyOfflineSosQueue, queue);
  }

  static Future<List<Map<String, dynamic>>> getOfflineEmergencyQueue() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_keyOfflineSosQueue) ?? [];
    return queue.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }

  static Future<void> clearOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOfflineSosQueue);
  }
}
