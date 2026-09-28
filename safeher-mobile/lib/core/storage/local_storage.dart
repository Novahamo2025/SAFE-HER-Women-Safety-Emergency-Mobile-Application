import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _secureStorage = FlutterSecureStorage();

  static const String _keyAccessToken = 'safeher_access_token';
  static const String _keyRefreshToken = 'safeher_refresh_token';
  static const String _keyUserPin = 'safeher_user_pin';
  static const String _keyUserData = 'safeher_user_data';
  static const String _keyOfflineSosQueue = 'safeher_offline_sos_queue';

  // --- Token Management ---

  static Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
  }

  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _keyRefreshToken);
  }

  static Future<void> clearTokens() async {
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
  }

  // --- User Data ---

  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _secureStorage.write(key: _keyUserData, value: jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    final data = await _secureStorage.read(key: _keyUserData);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearUserData() async {
    await _secureStorage.delete(key: _keyUserData);
  }

  // --- PIN Management ---

  static Future<void> saveUserPin(String pin) async {
    await _secureStorage.write(key: _keyUserPin, value: pin);
  }

  static Future<String?> getUserPin() async {
    return await _secureStorage.read(key: _keyUserPin);
  }

  // --- Offline SOS Queue ---

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

  // --- Clear All ---

  static Future<void> clearAll() async {
    await clearTokens();
    await clearUserData();
    await _secureStorage.delete(key: _keyUserPin);
  }
}
