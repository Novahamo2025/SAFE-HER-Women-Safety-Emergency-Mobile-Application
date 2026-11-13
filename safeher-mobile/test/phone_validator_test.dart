import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/core/utils/phone_validator.dart';

void main() {
  group('PhoneValidator Tests', () {
    test('Empty or null mobile number returns specific empty validation message', () {
      expect(PhoneValidator.validate(null), 'Please enter your mobile number.');
      expect(PhoneValidator.validate(''), 'Please enter your mobile number.');
      expect(PhoneValidator.validate('   '), 'Please enter your mobile number.');
    });

    test('Too short numbers are rejected with 10-digit requirement message', () {
      expect(PhoneValidator.validate('123'), 'Please enter a valid 10-digit mobile number.');
      expect(PhoneValidator.validate('987654321'), 'Please enter a valid 10-digit mobile number.'); // 9 digits
      expect(PhoneValidator.validate('+9198765'), 'Please enter a valid 10-digit mobile number.');
    });

    test('Too long numbers are rejected', () {
      expect(PhoneValidator.validate('9876543210123456789'), 'Please enter a valid 10-digit mobile number.');
      expect(PhoneValidator.validate('+919876543210999999'), 'Please enter a valid 10-digit mobile number.');
    });

    test('Letters, special characters or malformed inputs are rejected', () {
      expect(PhoneValidator.validate('98765abcde'), 'Please enter a valid 10-digit mobile number.');
      expect(PhoneValidator.validate('user@example.com'), 'Please enter a valid 10-digit mobile number.');
      expect(PhoneValidator.validate('phone#12345'), 'Please enter a valid 10-digit mobile number.');
      expect(PhoneValidator.validate('++919876543210'), 'Please enter a valid 10-digit mobile number.');
    });

    test('Invalid Indian mobile starting digits (0-5) for 10-digit format are rejected', () {
      expect(PhoneValidator.validate('1234567890'), 'Please enter a valid 10-digit mobile number.');
      expect(PhoneValidator.validate('0123456789'), 'Please enter a valid 10-digit mobile number.');
      expect(PhoneValidator.validate('5555555555'), 'Please enter a valid 10-digit mobile number.');
    });

    test('Valid 10-digit Indian mobile numbers (starting with 6,7,8,9) pass validation', () {
      expect(PhoneValidator.validate('9876543210'), isNull);
      expect(PhoneValidator.validate('8123456789'), isNull);
      expect(PhoneValidator.validate('7012345678'), isNull);
      expect(PhoneValidator.validate('6999999999'), isNull);
    });

    test('Valid Indian numbers with +91 prefix pass validation', () {
      expect(PhoneValidator.validate('+919876543210'), isNull);
      expect(PhoneValidator.validate('+91 98765 43210'), isNull);
      expect(PhoneValidator.validate('+91-98765-43210'), isNull);
    });

    test('Valid Indian numbers with 91 or 0 prefix pass validation', () {
      expect(PhoneValidator.validate('919876543210'), isNull);
      expect(PhoneValidator.validate('09876543210'), isNull);
    });

    test('Normalization canonicalizes Indian numbers to +91XXXXXXXXXX', () {
      expect(PhoneValidator.normalize('9876543210'), '+919876543210');
      expect(PhoneValidator.normalize('+91 98765 43210'), '+919876543210');
      expect(PhoneValidator.normalize('919876543210'), '+919876543210');
      expect(PhoneValidator.normalize('09876543210'), '+919876543210');
      expect(PhoneValidator.normalize('  +91-98765-43210  '), '+919876543210');
    });
  });
}
