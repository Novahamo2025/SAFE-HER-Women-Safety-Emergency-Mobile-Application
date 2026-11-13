package com.safeher.security.crypto;

import jakarta.annotation.PostConstruct;
import lombok.Getter;
import lombok.Setter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.HexFormat;

/**
 * Configuration properties for OTP HMAC hashing and AES-256-GCM outbox encryption.
 * Keys are loaded from environment variables (OTP_PEPPER_KEY and SMS_ENCRYPTION_KEY_V1).
 *
 * Validates key presence, format, and required 256-bit entropy without exposing key values in logs.
 */
@Configuration
@ConfigurationProperties(prefix = "app.crypto")
@Getter
@Setter
public class OtpCryptoProperties {

    /**
     * Server-side pepper for HMAC-SHA256 OTP hashing (loaded from OTP_PEPPER_KEY).
     * Must decode to at least 32 bytes (256 bits).
     */
    @Value("${app.crypto.otp-pepper-key:${OTP_PEPPER_KEY:}}")
    private String otpPepperKey;

    /**
     * Active version for OTP pepper (default: 'v1').
     */
    @Value("${app.crypto.otp-pepper-version:${OTP_PEPPER_VERSION:v1}}")
    private String otpPepperVersion = "v1";

    /**
     * Active AES-256 key for SMS outbox payload encryption (loaded from SMS_ENCRYPTION_KEY_V1).
     * Must decode to exactly 32 bytes (256 bits).
     */
    @Value("${app.crypto.sms-encryption-key-v1:${SMS_ENCRYPTION_KEY_V1:}}")
    private String smsEncryptionKeyV1;

    /**
     * Active version for SMS encryption key (default: 'v1').
     */
    @Value("${app.crypto.sms-encryption-key-version:${SMS_ENCRYPTION_KEY_VERSION:v1}}")
    private String smsEncryptionKeyVersion = "v1";

    /**
     * Controls whether strict validation executes at Spring context initialization.
     * Default: true.
     */
    @Value("${app.crypto.validate-on-startup:${CRYPTO_VALIDATE_ON_STARTUP:true}}")
    private boolean validateOnStartup = true;

    private SecretKey resolvedPepperKey;
    private SecretKey resolvedEncryptionKey;

    @PostConstruct
    public void initAndValidate() {
        if (!validateOnStartup) {
            return;
        }
        // If keys are provided, validate and resolve them immediately
        if (otpPepperKey != null && !otpPepperKey.isBlank()) {
            this.resolvedPepperKey = parseAndCreateHmacKey(otpPepperKey, "OTP_PEPPER_KEY");
        }
        if (smsEncryptionKeyV1 != null && !smsEncryptionKeyV1.isBlank()) {
            this.resolvedEncryptionKey = parseAndCreateAes256Key(smsEncryptionKeyV1, "SMS_ENCRYPTION_KEY_V1");
        }
    }

    /**
     * Parses and validates a 256-bit HMAC key (hex, base64, or UTF-8).
     */
    public static SecretKey parseAndCreateHmacKey(String rawKey, String keyName) {
        byte[] keyBytes = parseKeyBytes(rawKey, 32, keyName, false);
        return new SecretKeySpec(keyBytes, "HmacSHA256");
    }

    /**
     * Parses and validates an exact 256-bit (32 bytes) AES key.
     */
    public static SecretKey parseAndCreateAes256Key(String rawKey, String keyName) {
        byte[] keyBytes = parseKeyBytes(rawKey, 32, keyName, true);
        return new SecretKeySpec(keyBytes, "AES");
    }

    private static byte[] parseKeyBytes(String rawKey, int expectedBytes, String keyName, boolean exactLength) {
        if (rawKey == null || rawKey.isBlank()) {
            throw new IllegalStateException("Cryptographic key '" + keyName + "' is absent or blank. "
                    + "Please configure a valid 256-bit key via environment variable.");
        }

        String trimmed = rawKey.trim();
        byte[] keyBytes = null;

        // 1. Try 64-character Hex format (standard 32 bytes / 256 bits)
        if (trimmed.length() >= 64 && trimmed.matches("^[0-9a-fA-F]+$") && trimmed.length() % 2 == 0) {
            try {
                keyBytes = HexFormat.of().parseHex(trimmed);
            } catch (Exception ignored) {
                // fallback to base64 or raw
            }
        }

        // 2. Try Base64 format if not hex
        if (keyBytes == null) {
            try {
                byte[] decoded = Base64.getDecoder().decode(trimmed);
                if (exactLength && decoded.length == expectedBytes) {
                    keyBytes = decoded;
                } else if (!exactLength && decoded.length >= expectedBytes) {
                    keyBytes = decoded;
                }
            } catch (IllegalArgumentException ignored) {
                // fallback to UTF-8
            }
        }

        // 3. Fallback to raw UTF-8 bytes
        if (keyBytes == null) {
            keyBytes = trimmed.getBytes(StandardCharsets.UTF_8);
        }

        // Validate length requirements
        if (exactLength && keyBytes.length != expectedBytes) {
            throw new IllegalStateException("Cryptographic key '" + keyName + "' must decode to exactly "
                    + expectedBytes + " bytes (256 bits) for AES-256, but decoded to " + keyBytes.length + " bytes.");
        }

        if (!exactLength && keyBytes.length < expectedBytes) {
            throw new IllegalStateException("Cryptographic key '" + keyName + "' requires at least "
                    + expectedBytes + " bytes (256 bits) of entropy, but decoded to " + keyBytes.length + " bytes.");
        }

        return keyBytes;
    }

    @Override
    public String toString() {
        return "OtpCryptoProperties[otpPepperVersion=" + otpPepperVersion
                + ", smsEncryptionKeyVersion=" + smsEncryptionKeyVersion
                + ", otpPepperKey=[PROTECTED], smsEncryptionKeyV1=[PROTECTED]]";
    }
}
