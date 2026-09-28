import 'package:flutter/services.dart';

class BatteryService {
  static const MethodChannel _channel = MethodChannel('com.safeher.app/battery');

  /**
   * Solves Blocker 3: Detects OEM battery management (Xiaomi, Vivo, Oppo, OnePlus)
   * and deep-links the user to the device's battery exemption settings.
   */
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final bool? isIgnored = await _channel.invokeMethod<bool>('isBatteryOptimizationDisabled');
      return isIgnored ?? false;
    } catch (e) {
      return true; // Default to safe if unsupported
    }
  }

  static Future<void> requestDisableBatteryOptimization() async {
    try {
      await _channel.invokeMethod('requestDisableBatteryOptimization');
    } catch (e) {
      // Fallback
    }
  }

  static Future<void> openAutoStartSettings() async {
    try {
      await _channel.invokeMethod('openAutoStartSettings');
    } catch (e) {
      // Fallback
    }
  }
}
