class PasswordValidator {
  /// Permitted special characters matching Spring Boot backend RegisterRequest regex:
  /// [@$!%*?&#^()-_+=]
  static const String permittedSpecialChars = '@\$!%*?&#^()-_+=';

  /// Validates an account password against the SvaShield backend password policy.
  /// Returns null if valid, or a descriptive validation message if invalid.
  static String? validate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an account password.';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (value.length > 128) {
      return 'Password must not exceed 128 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter (A-Z).';
    }

    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter (a-z).';
    }

    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must contain at least one digit (0-9).';
    }

    if (!RegExp(r'[@$!%*?&#^()\-_+=]').hasMatch(value)) {
      return 'Password must contain at least one special character (@\$!%*?&#^()-_+=).';
    }

    // Check that all characters are within the allowed set [A-Za-z\d@$!%*?&#^()\-_+=]
    if (!RegExp(r'^[A-Za-z\d@$!%*?&#^()\-_+=]+$').hasMatch(value)) {
      return 'Password contains unsupported characters.';
    }

    return null;
  }
}
