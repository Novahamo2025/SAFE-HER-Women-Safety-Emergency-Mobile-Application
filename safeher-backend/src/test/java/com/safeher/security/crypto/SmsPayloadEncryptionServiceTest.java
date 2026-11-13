package com.safeher.security.crypto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.util.Base64;
import java.util.HashSet;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SmsPayloadEncryptionServiceTest {

    private static final String TEST_AES_KEY_HEX = "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210";
    private static final String ROTATION_KEY_HEX = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    private SmsPayloadEncryptionService encryptionService;
    private SecretKey testKey;

    @BeforeEach
    void setUp() {
        testKey = OtpCryptoProperties.parseAndCreateAes256Key(TEST_AES_KEY_HEX, "TEST_AES");
        encryptionService = new SmsPayloadEncryptionService(testKey, "v1");
    }

    @Test
    @DisplayName("AES-GCM encrypt/decrypt round trip succeeds with identical plaintext output")
    void testEncryptDecrypt_RoundTrip_Succeeds() {
        String plaintext = "Your SafeHer verification code is 482915. Valid for 5 minutes.";
        EncryptedPayload encrypted = encryptionService.encrypt(plaintext);

        assertThat(encrypted).isNotNull();
        assertThat(encrypted.keyVersion()).isEqualTo("v1");
        assertThat(encrypted.encryptedPayload()).isNotBlank();
        assertThat(encrypted.payloadNonce()).isNotBlank();
        assertThat(encrypted.payloadTag()).isNotBlank();

        String decrypted = encryptionService.decrypt(encrypted);
        assertThat(decrypted).isEqualTo(plaintext);
    }

    @Test
    @DisplayName("Round trip succeeds for complex JSON payloads and unicode characters")
    void testEncryptDecrypt_JsonAndUnicodePayloads_Succeeds() {
        String jsonPayload = "{\"recipient\":\"+919876543210\",\"otp\":\"654321\",\"template\":\"DLT_120716\",\"symbol\":\"नमस्ते 🛡️\"}";
        EncryptedPayload encrypted = encryptionService.encrypt(jsonPayload);
        String decrypted = encryptionService.decrypt(encrypted);

        assertThat(decrypted).isEqualTo(jsonPayload);
    }

    @Test
    @DisplayName("Each encryption produces a fresh 96-bit (12-byte) nonce and distinct ciphertext")
    void testEncrypt_AlwaysUsesFreshNonce() {
        String plaintext = "654321";
        Set<String> nonces = new HashSet<>();
        Set<String> ciphertexts = new HashSet<>();
        int sampleSize = 100;

        for (int i = 0; i < sampleSize; i++) {
            EncryptedPayload encrypted = encryptionService.encrypt(plaintext);
            nonces.add(encrypted.payloadNonce());
            ciphertexts.add(encrypted.encryptedPayload());

            byte[] decodedNonce = Base64.getDecoder().decode(encrypted.payloadNonce());
            assertThat(decodedNonce).hasSize(12); // Exactly 96 bits / 12 bytes
        }

        // 100 unique nonces and 100 unique ciphertexts for identical plaintext
        assertThat(nonces).hasSize(sampleSize);
        assertThat(ciphertexts).hasSize(sampleSize);
    }

    @Test
    @DisplayName("GCM authentication tag is exactly 128 bits (16 bytes)")
    void testEncrypt_TagIs128Bits() {
        EncryptedPayload encrypted = encryptionService.encrypt("998877");
        byte[] decodedTag = Base64.getDecoder().decode(encrypted.payloadTag());
        assertThat(decodedTag).hasSize(16); // 128 bits = 16 bytes
    }

    @Test
    @DisplayName("Modified ciphertext is rejected with CryptoException (authentication tag mismatch)")
    void testDecrypt_ModifiedCiphertext_ThrowsCryptoException() {
        EncryptedPayload original = encryptionService.encrypt("Confidential OTP 847291");

        // Tamper with ciphertext by altering first byte
        byte[] cipherBytes = Base64.getDecoder().decode(original.encryptedPayload());
        cipherBytes[0] = (byte) (cipherBytes[0] ^ 0xFF);
        String tamperedCipher = Base64.getEncoder().encodeToString(cipherBytes);

        EncryptedPayload tampered = new EncryptedPayload(
                original.keyVersion(),
                tamperedCipher,
                original.payloadNonce(),
                original.payloadTag()
        );

        assertThatThrownBy(() -> encryptionService.decrypt(tampered))
                .isInstanceOf(CryptoException.class)
                .hasMessageContaining("Decryption failed: authentication tag verification failed");
    }

    @Test
    @DisplayName("Modified authentication tag is rejected with CryptoException")
    void testDecrypt_ModifiedTag_ThrowsCryptoException() {
        EncryptedPayload original = encryptionService.encrypt("Confidential OTP 847291");

        // Tamper with tag
        byte[] tagBytes = Base64.getDecoder().decode(original.payloadTag());
        tagBytes[tagBytes.length - 1] = (byte) (tagBytes[tagBytes.length - 1] ^ 0xFF);
        String tamperedTag = Base64.getEncoder().encodeToString(tagBytes);

        EncryptedPayload tampered = new EncryptedPayload(
                original.keyVersion(),
                original.encryptedPayload(),
                original.payloadNonce(),
                tamperedTag
        );

        assertThatThrownBy(() -> encryptionService.decrypt(tampered))
                .isInstanceOf(CryptoException.class)
                .hasMessageContaining("Decryption failed: authentication tag verification failed");
    }

    @Test
    @DisplayName("Modified nonce is rejected with CryptoException")
    void testDecrypt_ModifiedNonce_ThrowsCryptoException() {
        EncryptedPayload original = encryptionService.encrypt("Confidential OTP 847291");

        // Tamper with nonce
        byte[] nonceBytes = Base64.getDecoder().decode(original.payloadNonce());
        nonceBytes[0] = (byte) (nonceBytes[0] ^ 0xFF);
        String tamperedNonce = Base64.getEncoder().encodeToString(nonceBytes);

        EncryptedPayload tampered = new EncryptedPayload(
                original.keyVersion(),
                original.encryptedPayload(),
                tamperedNonce,
                original.payloadTag()
        );

        assertThatThrownBy(() -> encryptionService.decrypt(tampered))
                .isInstanceOf(CryptoException.class)
                .hasMessageContaining("Decryption failed: authentication tag verification failed");
    }

    @Test
    @DisplayName("Invalid or corrupt Base64 values throw CryptoException")
    void testDecrypt_MalformedBase64_ThrowsCryptoException() {
        EncryptedPayload malformed = new EncryptedPayload(
                "v1",
                "not-valid-base64!@#$",
                Base64.getEncoder().encodeToString(new byte[12]),
                Base64.getEncoder().encodeToString(new byte[16])
        );

        assertThatThrownBy(() -> encryptionService.decrypt(malformed))
                .isInstanceOf(CryptoException.class)
                .hasMessageContaining("Malformed Base64 payload component");
    }

    @Test
    @DisplayName("Invalid nonce length throws CryptoException")
    void testDecrypt_InvalidNonceLength_ThrowsCryptoException() {
        EncryptedPayload invalidNonce = new EncryptedPayload(
                "v1",
                Base64.getEncoder().encodeToString("ciphertext".getBytes()),
                Base64.getEncoder().encodeToString(new byte[8]), // Only 8 bytes, expected 12
                Base64.getEncoder().encodeToString(new byte[16])
        );

        assertThatThrownBy(() -> encryptionService.decrypt(invalidNonce))
                .isInstanceOf(CryptoException.class)
                .hasMessageContaining("Invalid nonce length");
    }

    @Test
    @DisplayName("Unsupported key version throws CryptoException")
    void testDecrypt_UnsupportedKeyVersion_ThrowsCryptoException() {
        EncryptedPayload unknownKeyVersion = new EncryptedPayload(
                "v99",
                Base64.getEncoder().encodeToString("ciphertext".getBytes()),
                Base64.getEncoder().encodeToString(new byte[12]),
                Base64.getEncoder().encodeToString(new byte[16])
        );

        assertThatThrownBy(() -> encryptionService.decrypt(unknownKeyVersion))
                .isInstanceOf(CryptoException.class)
                .hasMessageContaining("Unsupported or unregistered encryption key version: v99");
    }

    @Test
    @DisplayName("Key rotation: Decrypting payload encrypted with previous key succeeds after registering old key")
    void testKeyRotation_SupportsMultipleKeyVersions() {
        // Encrypt with v1
        String plaintext = "Rotating secret payload 123456";
        EncryptedPayload v1Payload = encryptionService.encrypt(plaintext);

        // Create new service with active key v2
        SecretKey v2Key = OtpCryptoProperties.parseAndCreateAes256Key(ROTATION_KEY_HEX, "KEY_V2");
        SmsPayloadEncryptionService rotatedService = new SmsPayloadEncryptionService(v2Key, "v2");

        // Before registering v1 key, decryption fails with unsupported version
        assertThatThrownBy(() -> rotatedService.decrypt(v1Payload))
                .isInstanceOf(CryptoException.class)
                .hasMessageContaining("Unsupported or unregistered encryption key version: v1");

        // Register historical v1 key for rotation support
        rotatedService.registerKeyVersion("v1", testKey);

        // Decryption of v1 payload now succeeds seamlessly
        String decryptedV1 = rotatedService.decrypt(v1Payload);
        assertThat(decryptedV1).isEqualTo(plaintext);

        // New encryptions use v2 key version
        EncryptedPayload v2Payload = rotatedService.encrypt(plaintext);
        assertThat(v2Payload.keyVersion()).isEqualTo("v2");
        assertThat(rotatedService.decrypt(v2Payload)).isEqualTo(plaintext);
    }

    @Test
    @DisplayName("EncryptedPayload toString redacts ciphertext and sensitive material")
    void testEncryptedPayload_ToStringRedactsSensitiveData() {
        EncryptedPayload payload = encryptionService.encrypt("secret_otp_code");
        String stringRep = payload.toString();

        assertThat(stringRep).contains("[REDACTED");
        assertThat(stringRep).doesNotContain(payload.encryptedPayload());
        assertThat(stringRep).doesNotContain(payload.payloadNonce());
        assertThat(stringRep).doesNotContain(payload.payloadTag());
    }
}
