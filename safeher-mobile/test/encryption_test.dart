import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/core/services/authenticated_aes_cipher.dart';

void main() {
  group('AuthenticatedAesCipher Tests (Phase 3A)', () {
    final masterKey = Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 256));
    final wrongKey = Uint8List.fromList(List<int>.generate(32, (i) => (i * 7 + 1) % 256));

    test('Encryption and Decryption Round Trip preserves exact data', () {
      final plaintext = utf8.encode('Top Secret SvaShield Evidence Data: Audio & Video 1234567890');
      final encrypted = AuthenticatedAesCipher.encrypt(
        plaintext: Uint8List.fromList(plaintext),
        masterKey: masterKey,
      );

      expect(encrypted.length, greaterThan(plaintext.length));
      // First 16 bytes must match magic header
      expect(utf8.decode(encrypted.sublist(0, 16)), equals('SVASHIELD_ENC_V1'));

      final decrypted = AuthenticatedAesCipher.decrypt(
        data: encrypted,
        masterKey: masterKey,
      );

      expect(utf8.decode(decrypted), equals('Top Secret SvaShield Evidence Data: Audio & Video 1234567890'));
    });

    test('Two encryptions of same plaintext produce different ciphertexts (unique nonces)', () {
      final plaintext = utf8.encode('Identical Plaintext');
      final enc1 = AuthenticatedAesCipher.encrypt(
        plaintext: Uint8List.fromList(plaintext),
        masterKey: masterKey,
      );
      final enc2 = AuthenticatedAesCipher.encrypt(
        plaintext: Uint8List.fromList(plaintext),
        masterKey: masterKey,
      );

      // Nonce at bytes 16..32 must differ
      expect(enc1.sublist(16, 32), isNot(equals(enc2.sublist(16, 32))));
      // Ciphertext must differ
      expect(enc1.sublist(64), isNot(equals(enc2.sublist(64))));

      // Both decrypt to identical plaintext
      expect(utf8.decode(AuthenticatedAesCipher.decrypt(data: enc1, masterKey: masterKey)), equals('Identical Plaintext'));
      expect(utf8.decode(AuthenticatedAesCipher.decrypt(data: enc2, masterKey: masterKey)), equals('Identical Plaintext'));
    });

    test('Decryption with wrong key throws SecurityException', () {
      final plaintext = utf8.encode('Sensitive Evidence Content');
      final encrypted = AuthenticatedAesCipher.encrypt(
        plaintext: Uint8List.fromList(plaintext),
        masterKey: masterKey,
      );

      expect(
        () => AuthenticatedAesCipher.decrypt(data: encrypted, masterKey: wrongKey),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('SecurityException'))),
      );
    });

    test('Tampered ciphertext throws SecurityException', () {
      final plaintext = utf8.encode('Untampered Evidence Content');
      final encrypted = AuthenticatedAesCipher.encrypt(
        plaintext: Uint8List.fromList(plaintext),
        masterKey: masterKey,
      );

      // Tamper one byte in the ciphertext payload
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;

      expect(
        () => AuthenticatedAesCipher.decrypt(data: tampered, masterKey: masterKey),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('SecurityException'))),
      );
    });

    test('Legacy unencrypted data passes through safely without corruption', () {
      final legacyData = Uint8List.fromList(utf8.encode('Legacy Plaintext JPG/MP4 header'));
      final result = AuthenticatedAesCipher.decrypt(data: legacyData, masterKey: masterKey);
      expect(utf8.decode(result), equals('Legacy Plaintext JPG/MP4 header'));
    });
  });
}
