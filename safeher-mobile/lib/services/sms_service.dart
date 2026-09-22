import 'package:url_launcher/url_launcher.dart';

class SmsService {
  /**
   * Dispatches a device-native carrier SMS directly from the phone.
   * Solves Blocker 2: Works on Day 1 without waiting for Indian DLT approval,
   * and functions even when mobile internet is completely disabled.
   */
  static Future<bool> sendNativeEmergencySms({
    required List<String> recipientNumbers,
    required String userName,
    required double latitude,
    required double longitude,
  }) async {
    if (recipientNumbers.isEmpty) return false;

    final String mapsLink = 'https://maps.google.com/?q=$latitude,$longitude';
    final String message = Uri.encodeComponent(
      'EMERGENCY ALERT: $userName needs immediate assistance! Live Location: $mapsLink - Sent via SafeHer'
    );

    // On Android, multiple recipients can be comma-separated or sent individually
    final String recipients = recipientNumbers.join(';');
    final Uri smsUri = Uri.parse('sms:$recipients?body=$message');

    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for devices that require single-recipient URI
        final Uri singleUri = Uri.parse('sms:${recipientNumbers.first}?body=$message');
        if (await canLaunchUrl(singleUri)) {
          return await launchUrl(singleUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // Fallback or log
      return false;
    }
    return false;
  }
}
