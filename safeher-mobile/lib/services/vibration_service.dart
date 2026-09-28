import 'package:flutter/services.dart';

class VibrationService {
  static const MethodChannel _channel = MethodChannel('com.safeher.app/vibrate');

  static Future<void> vibratePattern() async {
    try {
      await _channel.invokeMethod('vibratePattern');
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }

  static Future<void> vibrateEmergency() async {
    try {
      await _channel.invokeMethod('vibrateEmergency');
    } catch (_) {
      await HapticFeedback.heavyImpact();
    }
  }
}
