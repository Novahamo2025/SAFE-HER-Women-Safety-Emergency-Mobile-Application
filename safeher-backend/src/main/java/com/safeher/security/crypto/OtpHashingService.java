package com.safeher.security.crypto;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.HexFormat;

/**
 * Service for generating cryptographically secure, uniformly distributed 6-digit OTPs
 * and computing context-bound HMAC-SHA256 hashes using a server-side pepper and per-record salt.
 *
 * Implements constant-time hash comparison and never logs plaintext OTPs, salts, or peppers.
 */
@Service
@Slf4j
public class OtpHashingService {

    private static final String HMAC_SHA256_ALGORITHM = "HmacSHA256";
    private static final int OTP_BOUND = 1_000_000; // 000000 to 999999
    private static final int SALT_BYTE_LENGTH = 16;  // 16 bytes = 32 hex chars

    private final SecretKey pepperKey;
    private final String pepperVersion;
    private final SecureRandom secureRandom;

    /**
     * Spring constructor using configured properties.
     */
    @Autowired
    public OtpHashingService(OtpCryptoProperties properties) {
        if (properties == null) {
            throw new IllegalArgumentException("OtpCryptoProperties cannot be null");
        }
        this.pepperKey = properties.getResolvedPepperKey() != null
                ? properties.getResolvedPepperKey()
                : OtpCryptoProperties.parseAndCreateHmacKey(properties.getOtpPepperKey(), "OTP_PEPPER_KEY");
        this.pepperVersion = properties.getOtpPepperVersion();
        this.secureRandom = new SecureRandom();
    }

    /**
     * Direct constructor for testing or manual instantiation.
     */
    public OtpHashingService(SecretKey pepperKey, String pepperVersion) {
        if (pepperKey == null) {
            throw new IllegalArgumentException("Pepper key cannot be null");
        }
        this.pepperKey = pepperKey;
        this.pepperVersion = pepperVersion != null ? pepperVersion : "v1";
        this.secureRandom = new SecureRandom();
    }

    /**
     * Generates a cryptographically secure, uniformly distributed 6-digit numeric OTP.
     * Uniform distribution is guaranteed by SecureRandom.nextInt(1_000_000) using rejection sampling.
     *
     * @return 6-digit numeric string (from "000000" to "999999").
     */
    public String generateOtp() {
        int code = secureRandom.nextInt(OTP_BOUND);
        return String.format("%06d", code);
    }

    /**
     * Generates a fresh cryptographically secure random 16-byte salt as a 32-character lowercase hex string.
     * Matches V6 column `salt VARCHAR(32)`.
     */
    public String generateSalt() {
        byte[] salt = new byte[SALT_BYTE_LENGTH];
        secureRandom.nextBytes(salt);
        return HexFormat.of().formatHex(salt);
    }

    /**
     * Computes a context-bound HMAC-SHA256 hex digest using the server-side pepper.
     * Context binding includes phone, purpose, otp, and salt to prevent cross-purpose
     * or cross-recipient hash reuse.
     *
     * Format: HMAC-SHA256(pepper, phone + ":" + purpose + ":" + otp + ":" + salt)
     *
     * @param phone   E.164 normalized phone number.
     * @param purpose OTP purpose (e.g. "REGISTRATION", "LOGIN").
     * @param otp     6-digit numeric OTP.
     * @param salt    32-character hex salt.
     * @return 64-character lowercase hexadecimal digest matching V6 column `otp_hash VARCHAR(64)`.
     */
    public String computeHash(String phone, String purpose, String otp, String salt) {
        if (phone == null || phone.isBlank()) {
            throw new IllegalArgumentException("Phone number is required for OTP context-bound hashing.");
        }
        if (purpose == null || purpose.isBlank()) {
            throw new IllegalArgumentException("Purpose is required for OTP context-bound hashing.");
        }
        if (otp == null || otp.isBlank()) {
            throw new IllegalArgumentException("OTP value is required for context-bound hashing.");
        }
        if (salt == null || salt.isBlank()) {
            throw new IllegalArgumentException("Salt is required for context-bound hashing.");
        }

        String payload = phone.trim() + ":" + purpose.trim() + ":" + otp.trim() + ":" + salt.trim();
        try {
            Mac mac = Mac.getInstance(HMAC_SHA256_ALGORITHM);
            mac.init(pepperKey);
            byte[] rawHash = mac.doFinal(payload.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(rawHash);
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new CryptoException("Failed to compute HMAC-SHA256 hash", e);
        }
    }

    /**
     * Validates a candidate OTP against the stored expected hash using constant-time comparison.
     *
     * @param phone        E.164 normalized phone number.
     * @param purpose      OTP purpose.
     * @param candidateOtp The OTP provided by the user.
     * @param salt         The salt stored in the OTP verification record.
     * @param expectedHash The 64-char hex hash stored in the OTP verification record.
     * @return true if candidate OTP produces an identical hash; false otherwise.
     */
    public boolean verifyOtp(String phone, String purpose, String candidateOtp, String salt, String expectedHash) {
        if (candidateOtp == null || candidateOtp.isBlank()
                || expectedHash == null || expectedHash.isBlank()
                || phone == null || purpose == null || salt == null) {
            return false;
        }

        String candidateHash = computeHash(phone, purpose, candidateOtp, salt);

        // Constant-time byte-level comparison to prevent timing side-channel attacks
        byte[] candidateBytes = candidateHash.getBytes(StandardCharsets.UTF_8);
        byte[] expectedBytes = expectedHash.getBytes(StandardCharsets.UTF_8);

        return MessageDigest.isEqual(candidateBytes, expectedBytes);
    }

    public String getPepperVersion() {
        return pepperVersion;
    }
}
