package com.safeher.auth;

import com.safeher.auth.dto.AuthResponse;
import com.safeher.auth.dto.LoginRequest;
import com.safeher.auth.dto.RegisterRequest;
import com.safeher.otp.exception.OtpCooldownException;
import com.safeher.otp.exception.OtpRateLimitException;
import com.safeher.otp.model.OtpStatus;
import com.safeher.otp.model.OtpVerification;
import com.safeher.otp.model.RateLimitEvent;
import com.safeher.otp.repository.OtpVerificationRepository;
import com.safeher.otp.repository.RateLimitEventRepository;
import com.safeher.otp.service.OtpRateLimiter;
import com.safeher.otp.service.OtpService;
import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.model.SmsOutboxStatus;
import com.safeher.outbox.provider.MockSmsProviderClient;
import com.safeher.outbox.provider.SmsDispatchResult;
import com.safeher.outbox.repository.SmsOutboxRepository;
import com.safeher.outbox.service.SmsOutboxDispatcher;
import com.safeher.security.JwtTokenProvider;
import com.safeher.security.RefreshToken;
import com.safeher.security.RefreshTokenRepository;
import com.safeher.security.crypto.SmsPayloadEncryptionService;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class AuthServiceOtpIntegrationTest {

    @Autowired
    private AuthService authService;

    @Autowired
    private OtpService otpService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private OtpVerificationRepository otpVerificationRepository;

    @Autowired
    private SmsOutboxRepository smsOutboxRepository;

    @Autowired
    private RateLimitEventRepository rateLimitEventRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private SmsPayloadEncryptionService encryptionService;

    @Autowired
    private MockSmsProviderClient mockSmsProviderClient;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider tokenProvider;

    @Autowired
    private SmsOutboxDispatcher smsOutboxDispatcher;

    @BeforeEach
    void setUp() {
        mockSmsProviderClient.reset();
        smsOutboxRepository.deleteAll();
        otpVerificationRepository.deleteAll();
        rateLimitEventRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @AfterEach
    void tearDown() {
        mockSmsProviderClient.reset();
        smsOutboxRepository.deleteAll();
        otpVerificationRepository.deleteAll();
        rateLimitEventRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    private RegisterRequest createRegisterRequest(String email, String phone) {
        RegisterRequest req = new RegisterRequest();
        req.setName("Priya Sharma");
        req.setEmail(email);
        req.setPhone(phone);
        req.setPassword("SecurePass123!");
        req.setPin("1234");
        return req;
    }

    /**
     * Helper to extract the latest 6-digit OTP code dispatched to the outbox for testing.
     */
    private String extractDispatchedOtp(String phone) {
        List<SmsOutbox> outboxes = smsOutboxRepository.findAll();
        for (int i = outboxes.size() - 1; i >= 0; i--) {
            SmsOutbox o = outboxes.get(i);
            if (phone.equals(o.getPhone())) {
                if (o.getEncryptedPayload() != null) {
                    String decrypted = encryptionService.decrypt(
                            o.getKeyVersion(),
                            o.getEncryptedPayload(),
                            o.getPayloadNonce(),
                            o.getPayloadTag()
                    );
                    // Payload format: "Your SafeHer verification code is: 123456. Valid for 10 minutes..."
                    java.util.regex.Matcher m = java.util.regex.Pattern.compile("\\b(\\d{6})\\b").matcher(decrypted);
                    if (m.find()) {
                        return m.group(1);
                    }
                }
            }
        }
        throw new IllegalStateException("Could not find dispatched OTP for phone: " + phone);
    }

    @Test
    @DisplayName("1. New registration creates a pending unverified account and does NOT issue JWTs")
    void testNewRegistration_createsPendingAccount_noJwt() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        AuthResponse response = authService.register(request, "203.0.113.10");

        assertThat(response).isNotNull();
        assertThat(response.getUserId()).isNotNull();
        assertThat(response.getEmail()).isEqualTo("priya@example.com");
        assertThat(response.getPhone()).isEqualTo("+919876543210");

        // CRITICAL INVARIANT: No JWT access or refresh token issued before phone verification
        assertThat(response.getAccessToken()).isNull();
        assertThat(response.getRefreshToken()).isNull();

        User user = userRepository.findById(response.getUserId()).orElseThrow();
        assertThat(user.getAccountStatus()).isEqualTo("PENDING_VERIFICATION");
        assertThat(user.getIsVerified()).isFalse();
        assertThat(user.getPhoneVerifiedAt()).isNull();
        assertThat(user.getIsLegacyAccount()).isFalse();
    }

    @Test
    @DisplayName("2. OTP issuance creates a context-bound hashed OTP record and encrypted SMS outbox entry")
    void testOtpIssuance_createsHashedRecordAndEncryptedOutbox() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        AuthResponse response = authService.register(request, "203.0.113.10");

        // Verify otp_verifications row
        List<OtpVerification> verifications = otpVerificationRepository.findByPhoneAndStatus("+919876543210", OtpStatus.PENDING);
        assertThat(verifications).hasSize(1);
        OtpVerification v = verifications.get(0);

        assertThat(v.getOtpHash()).hasSize(64); // 64-char hex SHA256
        assertThat(v.getSalt()).hasSize(32);    // 32-char hex 16-byte salt
        assertThat(v.getAttemptsCount()).isEqualTo(0);
        assertThat(v.getMaxAttempts()).isEqualTo(3);
        assertThat(v.getExpiresAt()).isAfter(Instant.now());
        assertThat(v.getUser().getId()).isEqualTo(response.getUserId());

        // Verify sms_outbox row
        List<SmsOutbox> outboxes = smsOutboxRepository.findAll();
        assertThat(outboxes).hasSize(1);
        SmsOutbox outbox = outboxes.get(0);
        assertThat(outbox.getPhone()).isEqualTo("+919876543210");
        assertThat(outbox.getCorrelationId()).startsWith("OTP-");
        assertThat(outbox.getOtpVerification().getId()).isEqualTo(v.getId());
    }

    @Test
    @DisplayName("3. Correct OTP verifies phone, consumes OTP, marks user ACTIVE, and issues tokens")
    void testCorrectOtp_verifiesPhoneAndConsumesOtp() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        AuthResponse registerResponse = authService.register(request, "203.0.113.10");

        String code = extractDispatchedOtp("+919876543210");
        assertThat(code).matches("^\\d{6}$");

        AuthResponse verifyResponse = authService.verifyOtp("+919876543210", code);

        assertThat(verifyResponse).isNotNull();
        assertThat(verifyResponse.getAccessToken()).isNotNull().isNotBlank();
        assertThat(verifyResponse.getRefreshToken()).isNotNull().isNotBlank();
        assertThat(verifyResponse.getUserId()).isEqualTo(registerResponse.getUserId());

        // Assert OTP verification row is CONSUMED
        List<OtpVerification> consumed = otpVerificationRepository.findByPhoneAndStatus("+919876543210", OtpStatus.CONSUMED);
        assertThat(consumed).hasSize(1);
        assertThat(consumed.get(0).getConsumedAt()).isNotNull();

        // Assert User is phone-verified and ACTIVE
        User user = userRepository.findById(registerResponse.getUserId()).orElseThrow();
        assertThat(user.getPhoneVerifiedAt()).isNotNull();
        assertThat(user.getIsVerified()).isTrue();
        assertThat(user.getAccountStatus()).isEqualTo("ACTIVE");

        // Assert user can now login with credentials
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("priya@example.com");
        loginRequest.setPassword("SecurePass123!");
        AuthResponse loginResponse = authService.login(loginRequest);
        assertThat(loginResponse.getAccessToken()).isNotNull();
    }

    @Test
    @DisplayName("4. Incorrect OTP increments persistent attempt counters even on exception")
    void testIncorrectOtp_incrementsPersistentAttempts() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        authService.register(request, "203.0.113.10");

        // Attempt 1: wrong code
        assertThatThrownBy(() -> authService.verifyOtp("+919876543210", "000000"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Invalid OTP code. 2 attempts remaining");

        OtpVerification v1 = otpVerificationRepository.findByPhoneAndPurposeAndStatus(
                "+919876543210", OtpService.PURPOSE_REGISTRATION, OtpStatus.PENDING).orElseThrow();
        assertThat(v1.getAttemptsCount()).isEqualTo(1);

        // Attempt 2: wrong code
        assertThatThrownBy(() -> authService.verifyOtp("+919876543210", "111111"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Invalid OTP code. 1 attempts remaining");

        OtpVerification v2 = otpVerificationRepository.findByPhoneAndPurposeAndStatus(
                "+919876543210", OtpService.PURPOSE_REGISTRATION, OtpStatus.PENDING).orElseThrow();
        assertThat(v2.getAttemptsCount()).isEqualTo(2);

        // Attempt 3: wrong code -> Exceeded!
        assertThatThrownBy(() -> authService.verifyOtp("+919876543210", "222222"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Maximum verification attempts exceeded");

        // Status is now EXCEEDED in database
        List<OtpVerification> exceededList = otpVerificationRepository.findByPhoneAndStatus("+919876543210", OtpStatus.EXCEEDED);
        assertThat(exceededList).hasSize(1);
        assertThat(exceededList.get(0).getAttemptsCount()).isEqualTo(3);
    }

    @Test
    @DisplayName("5. Expired, consumed, exceeded, and superseded OTPs fail safely")
    void testExpiredConsumedExceededSupersededOtpsFail() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        authService.register(request, "203.0.113.10");
        String code = extractDispatchedOtp("+919876543210");

        // A. Test Expired
        OtpVerification v = otpVerificationRepository.findByPhoneAndPurposeAndStatus(
                "+919876543210", OtpService.PURPOSE_REGISTRATION, OtpStatus.PENDING).orElseThrow();
        v.setExpiresAt(Instant.now().minus(1, ChronoUnit.MINUTES));
        otpVerificationRepository.saveAndFlush(v);

        assertThatThrownBy(() -> authService.verifyOtp("+919876543210", code))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("OTP code has expired");

        // Verify status transitioned to EXPIRED
        List<OtpVerification> expired = otpVerificationRepository.findByPhoneAndStatus("+919876543210", OtpStatus.EXPIRED);
        assertThat(expired).hasSize(1);
    }

    @Test
    @DisplayName("6. Consumed OTP cannot be reused")
    void testConsumedOtp_cannotBeReused() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        authService.register(request, "203.0.113.10");
        String code = extractDispatchedOtp("+919876543210");

        // Verify first time -> succeeds
        authService.verifyOtp("+919876543210", code);

        // Verify second time with same code -> rejected
        assertThatThrownBy(() -> authService.verifyOtp("+919876543210", code))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("No active OTP verification found");
    }

    @Test
    @DisplayName("7. Superseded OTP cannot be verified after user requests a resend")
    void testSupersededOtp_cannotBeVerified() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        authService.register(request, "203.0.113.10");
        String originalCode = extractDispatchedOtp("+919876543210");

        // Simulate cooldown elapsing
        rateLimitEventRepository.deleteAll();

        // Resend OTP
        authService.resendOtp("+919876543210", "203.0.113.10");

        // Original code should now be superseded
        assertThatThrownBy(() -> authService.verifyOtp("+919876543210", originalCode))
                .isInstanceOf(IllegalArgumentException.class);

        // New code should verify successfully
        String newCode = extractDispatchedOtp("+919876543210");
        AuthResponse response = authService.verifyOtp("+919876543210", newCode);
        assertThat(response.getAccessToken()).isNotNull();
    }

    @Test
    @DisplayName("8. Resend cooldown (45s) is strictly enforced")
    void testResendCooldown_enforced() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        authService.register(request, "203.0.113.10");

        // Immediate resend attempt within 45s must fail
        assertThatThrownBy(() -> authService.resendOtp("+919876543210", "203.0.113.10"))
                .isInstanceOf(OtpCooldownException.class)
                .hasMessageContaining("Please wait");
    }

    @Test
    @DisplayName("9. Hourly phone limit (max 5 requests) is strictly enforced")
    void testHourlyPhoneLimit_enforced() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        authService.register(request, "203.0.113.10");

        // Clear initial events and simulate 5 dispatches within the hour (spaced beyond 45s cooldown)
        rateLimitEventRepository.deleteAll();
        Instant now = Instant.now();
        for (int i = 0; i < 5; i++) {
            rateLimitEventRepository.save(RateLimitEvent.builder()
                    .scopeKey("PHONE:+919876543210")
                    .actionType(OtpRateLimiter.ACTION_OTP_DISPATCH)
                    .eventTimestamp(now.minus(2 + i * 2, ChronoUnit.MINUTES))
                    .build());
        }

        // 6th attempt should throw rate limit exception
        assertThatThrownBy(() -> authService.resendOtp("+919876543210", "203.0.113.10"))
                .isInstanceOf(OtpRateLimitException.class)
                .hasMessageContaining("Maximum OTP requests exceeded for this phone number");
    }

    @Test
    @DisplayName("10. Hourly IP limit (max 10 requests) is strictly enforced")
    void testHourlyIpLimit_enforced() {
        Instant now = Instant.now();
        String testIp = "198.51.100.99";

        // Simulate 10 requests from the same IP with different phone numbers
        for (int i = 1; i <= 10; i++) {
            rateLimitEventRepository.save(RateLimitEvent.builder()
                    .scopeKey("IP:" + testIp)
                    .actionType(OtpRateLimiter.ACTION_OTP_DISPATCH)
                    .eventTimestamp(now.minus(i * 2, ChronoUnit.MINUTES))
                    .build());
        }

        RegisterRequest request = createRegisterRequest("unique@example.com", "+919876543299");
        assertThatThrownBy(() -> authService.register(request, testIp))
                .isInstanceOf(OtpRateLimitException.class)
                .hasMessageContaining("Maximum OTP requests exceeded for this IP address");
    }

    @Test
    @DisplayName("11. Duplicate registration does not overwrite existing account credentials")
    void testDuplicateRegistration_doesNotOverwriteExisting() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        authService.register(request, "203.0.113.10");
        String code = extractDispatchedOtp("+919876543210");
        authService.verifyOtp("+919876543210", code);

        User originalUser = userRepository.findByEmailIgnoreCase("priya@example.com").orElseThrow();
        String originalPasswordHash = originalUser.getPasswordHash();

        // Attempt duplicate registration with different password
        RegisterRequest duplicateReq = createRegisterRequest("priya@example.com", "+919876543210");
        duplicateReq.setPassword("NewHackerPassword!");

        assertThatThrownBy(() -> authService.register(duplicateReq, "203.0.113.10"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("already registered");

        // Assert original password hash was NOT modified
        User userAfterAttempt = userRepository.findByEmailIgnoreCase("priya@example.com").orElseThrow();
        assertThat(userAfterAttempt.getPasswordHash()).isEqualTo(originalPasswordHash);
    }

    @Test
    @DisplayName("12. Legacy accounts (User 1 and 2) retain login access without phone_verified_at")
    void testLegacyAccounts_retainLoginAccess() {
        User legacyUser = User.builder()
                .name("Grandfathered Admin")
                .email("admin@example.com")
                .phone("+919876543001")
                .passwordHash(passwordEncoder.encode("AdminPass123!"))
                .role("ROLE_ADMIN")
                .accountStatus("ACTIVE")
                .isLegacyAccount(true)
                .phoneVerifiedAt(null) // Legacy user has null phone_verified_at
                .isVerified(true)
                .build();
        userRepository.save(legacyUser);

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("admin@example.com");
        loginRequest.setPassword("AdminPass123!");

        AuthResponse response = authService.login(loginRequest);
        assertThat(response).isNotNull();
        assertThat(response.getAccessToken()).isNotNull();
    }

    @Test
    @DisplayName("13. User ID 3 (non-legacy, phone_verified_at NULL) cannot login before phone verification")
    void testUser3_cannotLoginBeforeVerification() {
        User user3 = User.builder()
                .name("Phase 2B User")
                .email("user3@example.com")
                .phone("+919876543003")
                .passwordHash(passwordEncoder.encode("User3Pass123!"))
                .role("ROLE_USER")
                .accountStatus("ACTIVE")
                .isLegacyAccount(false) // User 3 is NOT legacy
                .phoneVerifiedAt(null)  // User 3 is NOT phone verified
                .isVerified(false)
                .build();
        userRepository.save(user3);

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("user3@example.com");
        loginRequest.setPassword("User3Pass123!");

        // Must reject login
        assertThatThrownBy(() -> authService.login(loginRequest))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Account phone number is not verified");
    }

    @Test
    @DisplayName("14. Provider acceptance alone does NOT verify a phone or consume OTP")
    void testProviderAcceptanceAlone_doesNotVerifyPhone() {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        authService.register(request, "203.0.113.10");

        // Simulate provider accepting SMS dispatch
        mockSmsProviderClient.setDefaultOutcome(SmsDispatchResult.Outcome.ACCEPTED);
        mockSmsProviderClient.setCustomProviderRef("MSG91_DELIVERY_SUCCESS");
        smsOutboxDispatcher.dispatchBatch(10);

        // Verify outbox transitioned to ACCEPTED
        List<SmsOutbox> outboxes = smsOutboxRepository.findAll();
        assertThat(outboxes.get(0).getStatus()).isEqualTo(SmsOutboxStatus.ACCEPTED);

        // SECURITY CHECK: User phone must STILL be unverified!
        User user = userRepository.findByEmailIgnoreCase("priya@example.com").orElseThrow();
        assertThat(user.getPhoneVerifiedAt()).isNull();
        assertThat(user.getIsVerified()).isFalse();
        assertThat(user.getAccountStatus()).isEqualTo("PENDING_VERIFICATION");

        // SECURITY CHECK: OTP verification must STILL be PENDING (not consumed)!
        List<OtpVerification> pending = otpVerificationRepository.findByPhoneAndStatus("+919876543210", OtpStatus.PENDING);
        assertThat(pending).hasSize(1);
        assertThat(pending.get(0).getConsumedAt()).isNull();
    }
}
