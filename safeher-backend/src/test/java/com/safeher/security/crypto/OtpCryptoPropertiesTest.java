package com.safeher.security.crypto;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.util.Base64;
import java.util.HexFormat;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OtpCryptoPropertiesTest {

    private static final String VALID_64_HEX = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

    @Test
    @DisplayName("Valid 64-char hex key parses into 32-byte (256-bit) SecretKey")
    void testParseAndCreateKeys_ValidHex() {
        SecretKey hmacKey = OtpCryptoProperties.parseAndCreateHmacKey(VALID_64_HEX, "OTP_PEPPER_KEY");
        assertThat(hmacKey).isNotNull();
        assertThat(hmacKey.getAlgorithm()).isEqualTo("HmacSHA256");
        assertThat(hmacKey.getEncoded()).hasSize(32);

        SecretKey aesKey = OtpCryptoProperties.parseAndCreateAes256Key(VALID_64_HEX, "SMS_ENCRYPTION_KEY_V1");
        assertThat(aesKey).isNotNull();
        assertThat(aesKey.getAlgorithm()).isEqualTo("AES");
        assertThat(aesKey.getEncoded()).hasSize(32);
    }

    @Test
    @DisplayName("Valid 32-byte Base64 key parses into 32-byte SecretKey")
    void testParseAndCreateKeys_ValidBase64() {
        byte[] raw32 = new byte[32];
        for (int i = 0; i < 32; i++) {
            raw32[i] = (byte) (i + 1);
        }
        String base64Key = Base64.getEncoder().encodeToString(raw32);

        SecretKey hmacKey = OtpCryptoProperties.parseAndCreateHmacKey(base64Key, "OTP_PEPPER_KEY");
        assertThat(hmacKey.getEncoded()).isEqualTo(raw32);

        SecretKey aesKey = OtpCryptoProperties.parseAndCreateAes256Key(base64Key, "SMS_ENCRYPTION_KEY_V1");
        assertThat(aesKey.getEncoded()).isEqualTo(raw32);
    }

    @Test
    @DisplayName("Valid raw 32-byte UTF-8 string parses into 32-byte SecretKey")
    void testParseAndCreateKeys_ValidRawUtf8() {
        String raw32CharString = "12345678901234567890123456789012"; // Exactly 32 chars
        SecretKey aesKey = OtpCryptoProperties.parseAndCreateAes256Key(raw32CharString, "SMS_ENCRYPTION_KEY_V1");
        assertThat(aesKey.getEncoded()).hasSize(32);
    }

    @Test
    @DisplayName("Missing or null key throws IllegalStateException with clear guidance")
    void testParseKey_NullKey_ThrowsIllegalStateException() {
        assertThatThrownBy(() -> OtpCryptoProperties.parseAndCreateHmacKey(null, "OTP_PEPPER_KEY"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Cryptographic key 'OTP_PEPPER_KEY' is absent or blank");

        assertThatThrownBy(() -> OtpCryptoProperties.parseAndCreateAes256Key(null, "SMS_ENCRYPTION_KEY_V1"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Cryptographic key 'SMS_ENCRYPTION_KEY_V1' is absent or blank");
    }

    @Test
    @DisplayName("Blank or whitespace key throws IllegalStateException")
    void testParseKey_BlankKey_ThrowsIllegalStateException() {
        assertThatThrownBy(() -> OtpCryptoProperties.parseAndCreateHmacKey("   ", "OTP_PEPPER_KEY"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("Cryptographic key 'OTP_PEPPER_KEY' is absent or blank");
    }

    @Test
    @DisplayName("Key with insufficient length (< 32 bytes) is rejected for HMAC pepper")
    void testParseHmacKey_ShortKey_ThrowsIllegalStateException() {
        String shortKey = "short_key_16_byt";
        assertThatThrownBy(() -> OtpCryptoProperties.parseAndCreateHmacKey(shortKey, "OTP_PEPPER_KEY"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("requires at least 32 bytes (256 bits) of entropy");
    }

    @Test
    @DisplayName("Key with length != 32 bytes is rejected for AES-256")
    void testParseAesKey_InvalidLength_ThrowsIllegalStateException() {
        // 16 bytes is AES-128, must be rejected for AES-256
        String key16Bytes = "1234567890123456";
        assertThatThrownBy(() -> OtpCryptoProperties.parseAndCreateAes256Key(key16Bytes, "SMS_ENCRYPTION_KEY_V1"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("must decode to exactly 32 bytes (256 bits) for AES-256");

        // 40 bytes is too long for AES-256
        String key40Bytes = "1234567890123456789012345678901234567890";
        assertThatThrownBy(() -> OtpCryptoProperties.parseAndCreateAes256Key(key40Bytes, "SMS_ENCRYPTION_KEY_V1"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("must decode to exactly 32 bytes (256 bits) for AES-256");
    }

    @Test
    @DisplayName("Error messages never contain the secret key value")
    void testErrorMessages_NeverContainSecretKey() {
        String sensitiveKey = "super_secret_compromised_password_123456";
        try {
            OtpCryptoProperties.parseAndCreateAes256Key(sensitiveKey, "TEST_KEY");
        } catch (IllegalStateException e) {
            assertThat(e.getMessage()).doesNotContain("super_secret_compromised_password_123456");
            assertThat(e.getMessage()).contains("TEST_KEY");
        }
    }

    @Test
    @DisplayName("OtpCryptoProperties toString redacts keys with [PROTECTED]")
    void testToString_ProtectsKeys() {
        OtpCryptoProperties props = new OtpCryptoProperties();
        props.setOtpPepperKey(VALID_64_HEX);
        props.setSmsEncryptionKeyV1(VALID_64_HEX);

        String output = props.toString();
        assertThat(output).contains("[PROTECTED]");
        assertThat(output).doesNotContain(VALID_64_HEX);
    }
}
