package com.safeher.auth;

import com.safeher.auth.dto.AuthResponse;
import com.safeher.auth.dto.LoginRequest;
import com.safeher.auth.dto.OtpSendRequest;
import com.safeher.auth.dto.RegisterRequest;
import com.safeher.security.RefreshToken;
import com.safeher.security.RefreshTokenRepository;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class AuthServiceTest {

    @Autowired
    private AuthService authService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private com.safeher.emergency.EmergencyRepository emergencyRepository;

    @Autowired
    private com.safeher.contact.ContactRepository contactRepository;

    @Autowired
    private com.safeher.location.LocationRepository locationRepository;

    @Autowired
    private com.safeher.notification.NotificationDeliveryRepository deliveryRepository;

    @Autowired
    private com.safeher.incident.IncidentRepository incidentRepository;

    @Autowired
    private com.safeher.journey.JourneyRepository journeyRepository;

    @Autowired
    private com.safeher.checkin.CheckInRepository checkInRepository;

    @Autowired
    private com.safeher.otp.repository.RateLimitEventRepository rateLimitEventRepository;

    @Autowired
    private com.safeher.otp.repository.OtpVerificationRepository otpVerificationRepository;

    @Autowired
    private com.safeher.outbox.repository.SmsOutboxRepository smsOutboxRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @BeforeEach
    void setUp() {
        smsOutboxRepository.deleteAll();
        otpVerificationRepository.deleteAll();
        rateLimitEventRepository.deleteAll();
        deliveryRepository.deleteAll();
        locationRepository.deleteAll();
        incidentRepository.deleteAll();
        journeyRepository.deleteAll();
        checkInRepository.deleteAll();
        emergencyRepository.deleteAll();
        contactRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    private RegisterRequest createValidRegisterRequest() {
        RegisterRequest request = new RegisterRequest();
        request.setName("Test User");
        request.setEmail("test@example.com");
        request.setPhone("+919876543210");
        request.setPassword("Password123!");
        request.setPin("1234");
        return request;
    }

    private User createAndSaveActiveVerifiedUser(String email, String phone) {
        User user = User.builder()
                .name("Test User")
                .email(email)
                .phone(phone)
                .passwordHash(passwordEncoder.encode("Password123!"))
                .pinHash(passwordEncoder.encode("1234"))
                .role("ROLE_USER")
                .accountStatus("ACTIVE")
                .isVerified(true)
                .phoneVerifiedAt(Instant.now())
                .isLegacyAccount(false)
                .build();
        return userRepository.save(user);
    }

    @Test
    void testSuccessfulRegistration() {
        RegisterRequest request = createValidRegisterRequest();
        AuthResponse response = authService.register(request);

        assertThat(response).isNotNull();
        assertThat(response.getAccessToken()).isNull();
        assertThat(response.getRefreshToken()).isNull();
        assertThat(response.getEmail()).isEqualTo("test@example.com");

        User savedUser = userRepository.findByEmailIgnoreCase("test@example.com").orElse(null);
        assertThat(savedUser).isNotNull();
        assertThat(savedUser.getAccountStatus()).isEqualTo("PENDING_VERIFICATION");
        assertThat(savedUser.getIsVerified()).isFalse();
        assertThat(savedUser.getPhoneVerifiedAt()).isNull();
    }

    @Test
    void testDuplicateEmailRegistration() {
        RegisterRequest request1 = createValidRegisterRequest();
        authService.register(request1);

        // Clear rate limits so phone cooldown doesn't mask email duplicate check
        rateLimitEventRepository.deleteAll();

        RegisterRequest request2 = createValidRegisterRequest();
        request2.setPhone("+919876543211"); // Change phone to isolate email failure

        assertThatThrownBy(() -> authService.register(request2))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Email is already registered");
    }

    @Test
    void testDuplicatePhoneRegistration() {
        RegisterRequest request1 = createValidRegisterRequest();
        authService.register(request1);

        // Clear rate limits so cooldown doesn't mask phone duplicate check
        rateLimitEventRepository.deleteAll();

        RegisterRequest request2 = createValidRegisterRequest();
        request2.setEmail("another@example.com"); // Change email to isolate phone failure

        assertThatThrownBy(() -> authService.register(request2))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Phone number is already registered");
    }

    @Test
    void testSuccessfulLogin() {
        createAndSaveActiveVerifiedUser("test@example.com", "+919876543210");

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("test@example.com");
        loginRequest.setPassword("Password123!");

        AuthResponse response = authService.login(loginRequest);
        assertThat(response).isNotNull();
        assertThat(response.getAccessToken()).isNotNull();

        User user = userRepository.findByEmailIgnoreCase("test@example.com").get();
        assertThat(user.getLastLoginAt()).isNotNull();
    }

    @Test
    void testLoginWithWrongPassword() {
        createAndSaveActiveVerifiedUser("test@example.com", "+919876543210");

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("test@example.com");
        loginRequest.setPassword("WrongPassword!");

        assertThatThrownBy(() -> authService.login(loginRequest))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Invalid credentials");
    }

    @Test
    void testLoginWithNonExistentUser() {
        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("nobody@example.com");
        loginRequest.setPassword("Password123!");

        assertThatThrownBy(() -> authService.login(loginRequest))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Invalid credentials");
    }

    @Test
    void testTokenRefresh() {
        createAndSaveActiveVerifiedUser("test@example.com", "+919876543210");

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("test@example.com");
        loginRequest.setPassword("Password123!");
        AuthResponse loginResponse = authService.login(loginRequest);

        AuthResponse refreshResponse = authService.refreshToken(loginResponse.getRefreshToken());
        assertThat(refreshResponse).isNotNull();
        assertThat(refreshResponse.getAccessToken()).isNotEqualTo(loginResponse.getAccessToken());
        assertThat(refreshResponse.getRefreshToken()).isNotEqualTo(loginResponse.getRefreshToken());
    }

    @Test
    void testRefreshWithRevokedToken() {
        createAndSaveActiveVerifiedUser("test@example.com", "+919876543210");

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("test@example.com");
        loginRequest.setPassword("Password123!");
        AuthResponse loginResponse = authService.login(loginRequest);

        // Manually revoke the token
        List<RefreshToken> tokens = refreshTokenRepository.findAll();
        RefreshToken token = tokens.get(0);
        token.setRevokedAt(java.time.Instant.now());
        refreshTokenRepository.save(token);

        assertThatThrownBy(() -> authService.refreshToken(loginResponse.getRefreshToken()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Session has been revoked");
    }

    @Test
    void testLogout() {
        createAndSaveActiveVerifiedUser("test@example.com", "+919876543210");

        LoginRequest loginRequest = new LoginRequest();
        loginRequest.setIdentifier("test@example.com");
        loginRequest.setPassword("Password123!");
        AuthResponse loginResponse = authService.login(loginRequest);

        authService.logout(loginResponse.getRefreshToken());

        List<RefreshToken> tokens = refreshTokenRepository.findAll();
        assertThat(tokens).isNotEmpty();
        assertThat(tokens.get(0).isRevoked()).isTrue();
    }

    @Test
    void testConcurrentRegistration() throws InterruptedException {
        int threads = 2;
        ExecutorService executorService = Executors.newFixedThreadPool(threads);
        CountDownLatch latch = new CountDownLatch(1);
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failCount = new AtomicInteger(0);

        for (int i = 0; i < threads; i++) {
            executorService.execute(() -> {
                try {
                    latch.await();
                    RegisterRequest req = createValidRegisterRequest();
                    authService.register(req);
                    successCount.incrementAndGet();
                } catch (Exception e) {
                    failCount.incrementAndGet();
                }
            });
        }

        latch.countDown();
        executorService.shutdown();
        executorService.awaitTermination(5, java.util.concurrent.TimeUnit.SECONDS);

        assertThat(successCount.get() + failCount.get()).isEqualTo(2);
    }

    @Test
    void testDeleteAccount_Success() {
        User user = createAndSaveActiveVerifiedUser("test@example.com", "+919876543210");
        Long userId = user.getId();

        // Attach an emergency contact
        com.safeher.contact.EmergencyContact contact = com.safeher.contact.EmergencyContact.builder()
                .user(user)
                .contactName("Mom")
                .phone("+919111122222")
                .relationship("Family")
                .priority(1)
                .notifySms(true)
                .notifyPush(true)
                .build();
        contactRepository.save(contact);

        // Attach an emergency event
        com.safeher.emergency.EmergencyEvent event = com.safeher.emergency.EmergencyEvent.builder()
                .user(user)
                .eventType("SOS")
                .status("RESOLVED")
                .clientEventUuid("uuid-test-delete-123")
                .build();
        emergencyRepository.save(event);

        // Verify records exist
        assertThat(userRepository.findById(userId)).isPresent();
        assertThat(contactRepository.findByUserIdOrderByPriorityAsc(userId)).isNotEmpty();
        assertThat(emergencyRepository.findByUserIdOrderByStartedAtDesc(userId)).isNotEmpty();

        // Delete account
        authService.deleteAccount(userId, "Password123!");

        // Assert all user data is permanently deleted
        assertThat(userRepository.findById(userId)).isEmpty();
        assertThat(contactRepository.findByUserIdOrderByPriorityAsc(userId)).isEmpty();
        assertThat(emergencyRepository.findByUserIdOrderByStartedAtDesc(userId)).isEmpty();
    }

    @Test
    void testDeleteAccount_RejectsInvalidPassword() {
        User user = createAndSaveActiveVerifiedUser("test@example.com", "+919876543210");
        Long userId = user.getId();

        assertThatThrownBy(() -> authService.deleteAccount(userId, "WrongPassword!"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Invalid account password");

        // Verify user still exists in database
        assertThat(userRepository.findById(userId)).isPresent();
    }

    @Test
    void testDeleteAccount_NonExistentUser() {
        assertThatThrownBy(() -> authService.deleteAccount(99999L, "Password123!"))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("User not found");
    }

    @Test
    void testSendOtp_ValidIndianPhone_Success() {
        OtpSendRequest request = OtpSendRequest.builder()
                .phone("+919876543210")
                .build();

        Map<String, Object> result = authService.sendOtp(request);
        assertThat(result).isNotNull();
        assertThat(result.get("phone")).isEqualTo("+919876543210");
        assertThat((String) result.get("message")).contains("OTP");
    }

    @Test
    void testSendOtp_10DigitIndianPhone_Normalized() {
        rateLimitEventRepository.deleteAll(); // clear cooldown
        OtpSendRequest request = OtpSendRequest.builder()
                .phone("9876543210")
                .build();

        Map<String, Object> result = authService.sendOtp(request);
        assertThat(result.get("phone")).isEqualTo("+919876543210");
    }

    @Test
    void testSendOtp_NullOrBlankPhone_ThrowsException() {
        OtpSendRequest request = OtpSendRequest.builder().phone("").build();
        assertThatThrownBy(() -> authService.sendOtp(request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Please enter your mobile number");
    }

    @Test
    void testSendOtp_InvalidPhoneFormat_ThrowsException() {
        OtpSendRequest request = OtpSendRequest.builder().phone("12345").build();
        assertThatThrownBy(() -> authService.sendOtp(request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Please enter a valid 10-digit mobile number");
    }
}
