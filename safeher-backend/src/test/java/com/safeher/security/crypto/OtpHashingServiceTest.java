package com.safeher.security.crypto;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.RepeatedTest;
import org.junit.jupiter.api.Test;

import javax.crypto.SecretKey;
import java.security.MessageDigest;
import java.util.HashSet;
import java.util.Set;
import java.util.regex.Pattern;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class OtpHashingServiceTest {

    private static final String TEST_PEPPER_HEX = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
    private static final Pattern SIX_DIGIT_PATTERN = Pattern.compile("^[0-9]{6}$");

    private OtpHashingService hashingService;
    private SecretKey testKey;

    @BeforeEach
    void setUp() {
        testKey = OtpCryptoProperties.parseAndCreateHmacKey(TEST_PEPPER_HEX, "TEST_PEPPER");
        hashingService = new OtpHashingService(testKey, "v1");
    }

    @Test
    @DisplayName("OTP generation always produces exactly six numeric digits")
    void testOtpGeneration_AlwaysProducesSixNumericDigits() {
        for (int i = 0; i < 1000; i++) {
            String otp = hashingService.generateOtp();
            assertThat(otp).isNotNull();
            assertThat(otp).hasSize(6);
            assertThat(otp).matches(SIX_DIGIT_PATTERN);
        }
    }

    @Test
    @DisplayName("OTP generation uses secure randomness with diverse values across samples")
    void testOtpGeneration_UsesSecureRandomness() {
        Set<String> generatedCodes = new HashSet<>();
        int sampleSize = 1000;
        for (int i = 0; i < sampleSize; i++) {
            generatedCodes.add(hashingService.generateOtp());
        }
        // With 10^6 space and 1000 samples, collisions should be very small (< 10)
        assertThat(generatedCodes.size()).isGreaterThan(980);
    }

    @Test
    @DisplayName("Salt generation produces fresh 16-byte random hex string (32 characters)")
    void testGenerateSalt_ProducesUnique32CharHex() {
        Set<String> salts = new HashSet<>();
        for (int i = 0; i < 100; i++) {
            String salt = hashingService.generateSalt();
            assertThat(salt).hasSize(32);
            assertThat(salt).matches("^[0-9a-f]{32}$");
            salts.add(salt);
        }
        assertThat(salts).hasSize(100);
    }

    @Test
    @DisplayName("Different OTPs produce independently salted hashes")
    void testDifferentOtps_ProduceIndependentlySaltedHashes() {
        String phone = "+919876543210";
        String purpose = "REGISTRATION";
        String otp1 = hashingService.generateOtp();
        String salt1 = hashingService.generateSalt();
        String hash1 = hashingService.computeHash(phone, purpose, otp1, salt1);

        String otp2 = hashingService.generateOtp();
        String salt2 = hashingService.generateSalt();
        String hash2 = hashingService.computeHash(phone, purpose, otp2, salt2);

        assertThat(salt1).isNotEqualTo(salt2);
        assertThat(hash1).isNotEqualTo(hash2);
        assertThat(hash1).hasSize(64);
        assertThat(hash2).hasSize(64);
    }

    @Test
    @DisplayName("Correct OTP validation succeeds")
    void testVerifyOtp_CorrectOtp_Succeeds() {
        String phone = "+919876543210";
        String purpose = "REGISTRATION";
        String otp = "123456";
        String salt = hashingService.generateSalt();
        String hash = hashingService.computeHash(phone, purpose, otp, salt);

        boolean verified = hashingService.verifyOtp(phone, purpose, otp, salt, hash);
        assertThat(verified).isTrue();
    }

    @Test
    @DisplayName("Incorrect OTP validation fails")
    void testVerifyOtp_IncorrectOtp_Fails() {
        String phone = "+919876543210";
        String purpose = "REGISTRATION";
        String correctOtp = "123456";
        String candidateOtp = "654321";
        String salt = hashingService.generateSalt();
        String hash = hashingService.computeHash(phone, purpose, correctOtp, salt);

        boolean verified = hashingService.verifyOtp(phone, purpose, candidateOtp, salt, hash);
        assertThat(verified).isFalse();
    }

    @Test
    @DisplayName("Modified hash fails validation")
    void testVerifyOtp_ModifiedHash_Fails() {
        String phone = "+919876543210";
        String purpose = "REGISTRATION";
        String otp = "543210";
        String salt = hashingService.generateSalt();
        String hash = hashingService.computeHash(phone, purpose, otp, salt);

        // Flip last character of hash
        char lastChar = hash.charAt(hash.length() - 1);
        char flipped = (lastChar == '0') ? '1' : '0';
        String tamperedHash = hash.substring(0, hash.length() - 1) + flipped;

        boolean verified = hashingService.verifyOtp(phone, purpose, otp, salt, tamperedHash);
        assertThat(verified).isFalse();
    }

    @Test
    @DisplayName("Modified salt fails validation")
    void testVerifyOtp_ModifiedSalt_Fails() {
        String phone = "+919876543210";
        String purpose = "REGISTRATION";
        String otp = "543210";
        String salt = hashingService.generateSalt();
        String hash = hashingService.computeHash(phone, purpose, otp, salt);

        // Flip last character of salt
        char lastChar = salt.charAt(salt.length() - 1);
        char flipped = (lastChar == 'a') ? 'b' : 'a';
        String tamperedSalt = salt.substring(0, salt.length() - 1) + flipped;

        boolean verified = hashingService.verifyOtp(phone, purpose, otp, tamperedSalt, hash);
        assertThat(verified).isFalse();
    }

    @Test
    @DisplayName("Context-binding: Cross-phone OTP validation fails")
    void testVerifyOtp_DifferentPhone_Fails() {
        String phoneAlice = "+919876543210";
        String phoneEve = "+919876543211";
        String purpose = "REGISTRATION";
        String otp = "998877";
        String salt = hashingService.generateSalt();
        String hashAlice = hashingService.computeHash(phoneAlice, purpose, otp, salt);

        // Attempt to verify Alice's OTP hash against Eve's phone number
        boolean verified = hashingService.verifyOtp(phoneEve, purpose, otp, salt, hashAlice);
        assertThat(verified).isFalse();
    }

    @Test
    @DisplayName("Context-binding: Cross-purpose OTP validation fails")
    void testVerifyOtp_DifferentPurpose_Fails() {
        String phone = "+919876543210";
        String purposeReg = "REGISTRATION";
        String purposeLogin = "LOGIN";
        String otp = "112233";
        String salt = hashingService.generateSalt();
        String hashReg = hashingService.computeHash(phone, purposeReg, otp, salt);

        // Attempt to verify registration hash for a login purpose
        boolean verified = hashingService.verifyOtp(phone, purposeLogin, otp, salt, hashReg);
        assertThat(verified).isFalse();
    }

    @Test
    @DisplayName("Null or blank parameters fail gracefully without throwing unexpected exceptions")
    void testVerifyOtp_NullOrBlankParameters_ReturnsFalse() {
        String phone = "+919876543210";
        String purpose = "REGISTRATION";
        String otp = "123456";
        String salt = hashingService.generateSalt();
        String hash = hashingService.computeHash(phone, purpose, otp, salt);

        assertThat(hashingService.verifyOtp(null, purpose, otp, salt, hash)).isFalse();
        assertThat(hashingService.verifyOtp(phone, null, otp, salt, hash)).isFalse();
        assertThat(hashingService.verifyOtp(phone, purpose, null, salt, hash)).isFalse();
        assertThat(hashingService.verifyOtp(phone, purpose, otp, null, hash)).isFalse();
        assertThat(hashingService.verifyOtp(phone, purpose, otp, salt, null)).isFalse();
        assertThat(hashingService.verifyOtp(phone, purpose, "", salt, hash)).isFalse();
        assertThat(hashingService.verifyOtp(phone, purpose, otp, salt, "")).isFalse();
    }

    @Test
    @DisplayName("Constant-time comparison executes via MessageDigest.isEqual")
    void testConstantTimeComparison() {
        byte[] a = "abcdef0123456789".getBytes();
        byte[] b = "abcdef0123456789".getBytes();
        byte[] c = "abcdef0123456780".getBytes();

        assertThat(MessageDigest.isEqual(a, b)).isTrue();
        assertThat(MessageDigest.isEqual(a, c)).isFalse();
    }

    @Test
    @DisplayName("Pepper version is accessible and matches configuration")
    void testGetPepperVersion() {
        assertThat(hashingService.getPepperVersion()).isEqualTo("v1");
    }
}
