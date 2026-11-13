package com.safeher.auth;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.safeher.auth.dto.LoginRequest;
import com.safeher.auth.dto.OtpResendRequest;
import com.safeher.auth.dto.OtpVerifyRequest;
import com.safeher.auth.dto.RegisterRequest;
import com.safeher.otp.model.OtpStatus;
import com.safeher.otp.model.OtpVerification;
import com.safeher.otp.model.RateLimitEvent;
import com.safeher.otp.repository.OtpVerificationRepository;
import com.safeher.otp.repository.RateLimitEventRepository;
import com.safeher.otp.service.OtpRateLimiter;
import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.provider.MockSmsProviderClient;
import com.safeher.outbox.repository.SmsOutboxRepository;
import com.safeher.security.RefreshTokenRepository;
import com.safeher.security.crypto.SmsPayloadEncryptionService;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthControllerOtpIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

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

    private String extractDispatchedOtp(String phone) {
        List<SmsOutbox> outboxes = smsOutboxRepository.findAll();
        for (int i = outboxes.size() - 1; i >= 0; i--) {
            SmsOutbox o = outboxes.get(i);
            if (phone.equals(o.getPhone()) && o.getEncryptedPayload() != null) {
                String decrypted = encryptionService.decrypt(
                        o.getKeyVersion(),
                        o.getEncryptedPayload(),
                        o.getPayloadNonce(),
                        o.getPayloadTag()
                );
                java.util.regex.Matcher m = java.util.regex.Pattern.compile("\\b(\\d{6})\\b").matcher(decrypted);
                if (m.find()) {
                    return m.group(1);
                }
            }
        }
        throw new IllegalStateException("Could not find dispatched OTP for phone: " + phone);
    }

    @Test
    @DisplayName("1. POST /api/auth/register creates pending unverified user and returns 201 WITHOUT JWTs")
    void testRegister_createsPendingUser_noJwtInResponse() throws Exception {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.userId").isNotEmpty())
                .andExpect(jsonPath("$.data.email").value("priya@example.com"))
                .andExpect(jsonPath("$.data.phone").value("+919876543210"))
                .andExpect(jsonPath("$.data.accessToken").doesNotExist())
                .andExpect(jsonPath("$.data.refreshToken").doesNotExist());

        // Verify user in DB is PENDING_VERIFICATION and unverified
        User user = userRepository.findByEmailIgnoreCase("priya@example.com").orElseThrow();
        assertThat(user.getAccountStatus()).isEqualTo("PENDING_VERIFICATION");
        assertThat(user.getIsVerified()).isFalse();
        assertThat(user.getPhoneVerifiedAt()).isNull();
        assertThat(user.getIsLegacyAccount()).isFalse();

        // Verify outbox record created
        assertThat(smsOutboxRepository.findAll()).hasSize(1);
    }

    @Test
    @DisplayName("2. POST /api/auth/otp/verify with correct OTP marks user ACTIVE and returns JWTs")
    void testVerifyOtp_success_marksUserActiveAndReturnsTokens() throws Exception {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        String otpCode = extractDispatchedOtp("+919876543210");

        OtpVerifyRequest verifyRequest = OtpVerifyRequest.builder()
                .phone("+919876543210")
                .otp(otpCode)
                .build();

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.data.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.data.email").value("priya@example.com"));

        // Verify user in DB is ACTIVE and phoneVerifiedAt is populated
        User user = userRepository.findByEmailIgnoreCase("priya@example.com").orElseThrow();
        assertThat(user.getAccountStatus()).isEqualTo("ACTIVE");
        assertThat(user.getIsVerified()).isTrue();
        assertThat(user.getPhoneVerifiedAt()).isNotNull();

        // Verify OTP is CONSUMED
        List<OtpVerification> consumed = otpVerificationRepository.findByPhoneAndStatus("+919876543210", OtpStatus.CONSUMED);
        assertThat(consumed).hasSize(1);
    }

    @Test
    @DisplayName("3. POST /api/auth/otp/verify with wrong code returns 400 Bad Request with remaining attempts")
    void testVerifyOtp_wrongCode_returns400() throws Exception {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        OtpVerifyRequest wrongRequest = OtpVerifyRequest.builder()
                .phone("+919876543210")
                .otp("000000")
                .build();

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value(containsString("Invalid OTP code. 2 attempts remaining")));

        // Invariant: User phone must remain unverified
        User user = userRepository.findByEmailIgnoreCase("priya@example.com").orElseThrow();
        assertThat(user.getPhoneVerifiedAt()).isNull();
    }

    @Test
    @DisplayName("4. POST /api/auth/otp/verify with expired OTP returns 400 Bad Request")
    void testVerifyOtp_expiredCode_returns400() throws Exception {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        String otpCode = extractDispatchedOtp("+919876543210");

        // Backdate OTP record expiration
        OtpVerification v = otpVerificationRepository.findAll().get(0);
        v.setExpiresAt(Instant.now().minus(5, ChronoUnit.MINUTES));
        otpVerificationRepository.saveAndFlush(v);

        OtpVerifyRequest verifyRequest = OtpVerifyRequest.builder()
                .phone("+919876543210")
                .otp(otpCode)
                .build();

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("expired")));
    }

    @Test
    @DisplayName("5. POST /api/auth/otp/verify locks after 3 failed attempts (EXCEEDED)")
    void testVerifyOtp_exceededAttempts_returns400() throws Exception {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        OtpVerifyRequest wrongRequest = OtpVerifyRequest.builder()
                .phone("+919876543210")
                .otp("111111")
                .build();

        // 3 consecutive failed attempts
        mockMvc.perform(post("/api/auth/otp/verify").contentType(MediaType.APPLICATION_JSON).content(objectMapper.writeValueAsString(wrongRequest)))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/auth/otp/verify").contentType(MediaType.APPLICATION_JSON).content(objectMapper.writeValueAsString(wrongRequest)))
                .andExpect(status().isBadRequest());
        mockMvc.perform(post("/api/auth/otp/verify").contentType(MediaType.APPLICATION_JSON).content(objectMapper.writeValueAsString(wrongRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("Maximum verification attempts exceeded")));

        // Status is now EXCEEDED in database
        List<OtpVerification> exceededList = otpVerificationRepository.findByPhoneAndStatus("+919876543210", OtpStatus.EXCEEDED);
        assertThat(exceededList).hasSize(1);
    }

    @Test
    @DisplayName("6. Superseded OTP cannot be verified; latest OTP verifies successfully")
    void testVerifyOtp_supersededCode_returns400() throws Exception {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        String originalCode = extractDispatchedOtp("+919876543210");

        // Simulate cooldown elapsed
        rateLimitEventRepository.deleteAll();

        // Resend OTP
        OtpResendRequest resendRequest = OtpResendRequest.builder()
                .phone("+919876543210")
                .build();

        mockMvc.perform(post("/api/auth/otp/resend")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(resendRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true));

        // Original code must fail
        OtpVerifyRequest oldVerifyReq = OtpVerifyRequest.builder()
                .phone("+919876543210")
                .otp(originalCode)
                .build();

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(oldVerifyReq)))
                .andExpect(status().isBadRequest());

        // Latest code must succeed
        String newCode = extractDispatchedOtp("+919876543210");
        OtpVerifyRequest newVerifyReq = OtpVerifyRequest.builder()
                .phone("+919876543210")
                .otp(newCode)
                .build();

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(newVerifyReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty());
    }

    @Test
    @DisplayName("7. POST /api/auth/otp/resend within 45s cooldown returns 429 Too Many Requests with Retry-After")
    void testResendOtp_cooldownEnforced_returns429() throws Exception {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        OtpResendRequest resendRequest = OtpResendRequest.builder()
                .phone("+919876543210")
                .build();

        mockMvc.perform(post("/api/auth/otp/resend")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(resendRequest)))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value(containsString("Please wait")));
    }

    @Test
    @DisplayName("8. POST /api/auth/otp/resend exceeding hourly phone limit returns 429 Too Many Requests")
    void testResendOtp_hourlyLimit_returns429() throws Exception {
        RegisterRequest request = createRegisterRequest("priya@example.com", "+919876543210");
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated());

        // Clear events and simulate 5 previous dispatches in the past hour spaced beyond cooldown
        rateLimitEventRepository.deleteAll();
        Instant now = Instant.now();
        for (int i = 0; i < 5; i++) {
            rateLimitEventRepository.save(RateLimitEvent.builder()
                    .scopeKey("PHONE:+919876543210")
                    .actionType(OtpRateLimiter.ACTION_OTP_DISPATCH)
                    .eventTimestamp(now.minus(2 + i * 2, ChronoUnit.MINUTES))
                    .build());
        }

        OtpResendRequest resendRequest = OtpResendRequest.builder()
                .phone("+919876543210")
                .build();

        mockMvc.perform(post("/api/auth/otp/resend")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(resendRequest)))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value(containsString("Maximum OTP requests exceeded for this phone number")));
    }

    @Test
    @DisplayName("9. POST /api/auth/login for unverified non-legacy user is blocked (400 Bad Request)")
    void testLogin_unverifiedNonLegacyUser_returns400() throws Exception {
        User user = User.builder()
                .name("Unverified User")
                .email("unverified@example.com")
                .phone("+919876543099")
                .passwordHash(passwordEncoder.encode("Password123!"))
                .role("ROLE_USER")
                .accountStatus("PENDING_VERIFICATION")
                .isLegacyAccount(false)
                .phoneVerifiedAt(null)
                .isVerified(false)
                .build();
        userRepository.save(user);

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("unverified@example.com");
        loginRequest.setPassword("Password123!");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value(containsString("Account phone number is not verified")));
    }

    @Test
    @DisplayName("10. POST /api/auth/login for legacy account (User 1/2) succeeds without phone_verified_at")
    void testLogin_legacyUser_returns200WithTokens() throws Exception {
        User legacyUser = User.builder()
                .name("Legacy Admin")
                .email("legacy_admin@example.com")
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
        loginRequest.setIdentifier("legacy_admin@example.com");
        loginRequest.setPassword("AdminPass123!");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginRequest)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.data.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.data.email").value("legacy_admin@example.com"));
    }
}
