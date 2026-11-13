package com.safeher.security.crypto;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.junit.jupiter.SpringExtension;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Verifies Spring dependency injection, property binding, @PostConstruct validation,
 * and service collaboration within the Spring application context.
 */
@ExtendWith(SpringExtension.class)
@ContextConfiguration(classes = {
        OtpCryptoProperties.class,
        OtpHashingService.class,
        SmsPayloadEncryptionService.class
})
@TestPropertySource(properties = {
        "app.crypto.otp-pepper-key=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        "app.crypto.otp-pepper-version=v1",
        "app.crypto.sms-encryption-key-v1=fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210",
        "app.crypto.sms-encryption-key-version=v1",
        "app.crypto.validate-on-startup=true"
})
class OtpCryptoSpringIntegrationTest {

    @Autowired
    private OtpCryptoProperties cryptoProperties;

    @Autowired
    private OtpHashingService otpHashingService;

    @Autowired
    private SmsPayloadEncryptionService smsPayloadEncryptionService;

    @Test
    @DisplayName("Cryptographic beans autowire cleanly in Spring context")
    void testBeansAutowireCleanly() {
        assertThat(cryptoProperties).isNotNull();
        assertThat(otpHashingService).isNotNull();
        assertThat(smsPayloadEncryptionService).isNotNull();
        assertThat(cryptoProperties.getOtpPepperVersion()).isEqualTo("v1");
        assertThat(cryptoProperties.getSmsEncryptionKeyVersion()).isEqualTo("v1");
    }

    @Test
    @DisplayName("Integrated OtpHashingService computes and verifies hashes via injected Spring configuration")
    void testOtpHashingService_SpringIntegration() {
        String phone = "+919988776655";
        String purpose = "REGISTRATION";
        String otp = otpHashingService.generateOtp();
        String salt = otpHashingService.generateSalt();

        String hash = otpHashingService.computeHash(phone, purpose, otp, salt);
        assertThat(hash).hasSize(64);

        boolean valid = otpHashingService.verifyOtp(phone, purpose, otp, salt, hash);
        assertThat(valid).isTrue();

        boolean invalid = otpHashingService.verifyOtp(phone, purpose, "000000", salt, hash);
        assertThat(invalid).isFalse();
    }

    @Test
    @DisplayName("Integrated SmsPayloadEncryptionService encrypts and decrypts payloads via injected Spring configuration")
    void testSmsPayloadEncryptionService_SpringIntegration() {
        String payload = "SafeHer Spring Integration Test OTP 736291";
        EncryptedPayload encrypted = smsPayloadEncryptionService.encrypt(payload);

        assertThat(encrypted.keyVersion()).isEqualTo("v1");
        assertThat(encrypted.encryptedPayload()).isNotBlank();

        String decrypted = smsPayloadEncryptionService.decrypt(encrypted);
        assertThat(decrypted).isEqualTo(payload);
    }
}
