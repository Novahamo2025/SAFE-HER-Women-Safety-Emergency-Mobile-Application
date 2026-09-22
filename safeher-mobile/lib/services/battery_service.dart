import 'package:disable_battery_optimization/disable_battery_optimization.dart';

class BatteryService {
  /**
   * Solves Blocker 3: Detects OEM battery management (Xiaomi, Vivo, Oppo, OnePlus)
   * and deep-links the user to the device's battery exemption settings.
   */
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      bool? isIgnored = await DisableBatteryOptimization.isBatteryOptimizationDisabled;
      return isIgnored ?? false;
    } catch (e) {
      return true; // Default to safe if unsupported
    }
  }

  static Future<void> requestDisableBatteryOptimization() async {
    try {
      await DisableBatteryOptimization.showDisableBatteryOptimizationSettings();
    } catch (e) {
      // Fallback
    }
  }

  static Future<void> openAutoStartSettings() async {
    try {
      await DisableBatteryOptimization.showDisableManufacturerBatteryOptimizationSettings();
    } catch (e) {
      // Fallback
    }
  }
}
