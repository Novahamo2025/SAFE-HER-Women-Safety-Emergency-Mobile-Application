class PhoneValidator {
  /// Validates a mobile number for OTP and registration.
  /// Returns null if valid, or an error message string if invalid.
  static String? validate(String? value) {
    if (value == null) {
      return 'Please enter your mobile number.';
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Please enter your mobile number.';
    }

    // Check for invalid characters (only digits, spaces, dashes, parens, and leading plus allowed)
    if (!RegExp(r'^\+?[0-9\s\-()]+$').hasMatch(trimmed)) {
      return 'Please enter a valid 10-digit mobile number.';
    }

    // Clean all formatting characters
    final cleaned = trimmed.replaceAll(RegExp(r'[\s\-()]'), '');

    // Case A: 10-digit Indian number (starts with 6, 7, 8, 9)
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return null;
    }

    // Case B: 10-digit Indian number with +91 prefix (+91XXXXXXXXXX = 13 chars)
    if (RegExp(r'^\+91[6-9]\d{9}$').hasMatch(cleaned)) {
      return null;
    }

    // Case C: 10-digit Indian number with 91 prefix without plus (91XXXXXXXXXX = 12 digits)
    if (RegExp(r'^91[6-9]\d{9}$').hasMatch(cleaned)) {
      return null;
    }

    // Case D: 10-digit Indian number with leading 0 (0XXXXXXXXXX = 11 digits)
    if (RegExp(r'^0[6-9]\d{9}$').hasMatch(cleaned)) {
      return null;
    }

    // Case E: General international phone number matching backend format (^\+?[0-9]{10,15}$)
    // Must start with country code + followed by 10 to 14 digits
    if (RegExp(r'^\+[1-9]\d{9,14}$').hasMatch(cleaned)) {
      return null;
    }

    return 'Please enter a valid 10-digit mobile number.';
  }

  /// Normalizes a valid mobile number to canonical international format (+91XXXXXXXXXX for India).
  /// If input cannot be normalized, returns the trimmed original string.
  static String normalize(String value) {
    final trimmed = value.trim();
    final cleaned = trimmed.replaceAll(RegExp(r'[\s\-()]'), '');

    // 10-digit Indian number -> +91XXXXXXXXXX
    if (RegExp(r'^[6-9]\d{9}$').hasMatch(cleaned)) {
      return '+91$cleaned';
    }

    // Indian number with 91 prefix -> +91XXXXXXXXXX
    if (RegExp(r'^91[6-9]\d{9}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }

    // Indian number with 0 prefix -> +91XXXXXXXXXX
    if (RegExp(r'^0[6-9]\d{9}$').hasMatch(cleaned)) {
      return '+91${cleaned.substring(1)}';
    }

    // Already has +
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    return cleaned;
  }
}
