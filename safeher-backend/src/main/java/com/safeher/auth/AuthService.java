package com.safeher.auth;

import com.safeher.auth.dto.AuthResponse;
import com.safeher.auth.dto.LoginRequest;
import com.safeher.auth.dto.RegisterRequest;
import com.safeher.checkin.CheckInRepository;
import com.safeher.contact.ContactRepository;
import com.safeher.emergency.EmergencyEvent;
import com.safeher.emergency.EmergencyRepository;
import com.safeher.incident.IncidentRepository;
import com.safeher.journey.JourneyRepository;
import com.safeher.location.LocationRepository;
import com.safeher.notification.NotificationDeliveryRepository;
import com.safeher.security.JwtTokenProvider;
import com.safeher.security.RefreshToken;
import com.safeher.security.RefreshTokenRepository;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;
import com.safeher.auth.dto.OtpSendRequest;
import com.safeher.notification.SmsGatewayService;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;
import com.safeher.otp.service.OtpService;

@Service
@Slf4j
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final RefreshTokenRepository refreshTokenRepository;
    private final ContactRepository contactRepository;
    private final EmergencyRepository emergencyRepository;
    private final IncidentRepository incidentRepository;
    private final JourneyRepository journeyRepository;
    private final CheckInRepository checkInRepository;
    private final LocationRepository locationRepository;
    private final NotificationDeliveryRepository deliveryRepository;
    private final SmsGatewayService smsGatewayService;
    private final OtpService otpService;

    public Map<String, Object> sendOtp(OtpSendRequest request) {
        return sendOtp(request, null);
    }

    public Map<String, Object> sendOtp(OtpSendRequest request, String clientIp) {
        if (request == null || request.getPhone() == null || request.getPhone().isBlank()) {
            throw new IllegalArgumentException("Please enter your mobile number.");
        }

        String rawPhone = request.getPhone().trim();
        String normalizedPhone = normalizePhone(rawPhone);

        // Server-side validation: must match valid 10-digit Indian number (+91[6-9]XXXXXXXXX)
        if (normalizedPhone == null || !normalizedPhone.matches("^\\+91[6-9]\\d{9}$")) {
            throw new IllegalArgumentException("Please enter a valid 10-digit mobile number.");
        }

        User user = userRepository.findByPhone(normalizedPhone).orElse(null);
        return otpService.issueOtp(user, normalizedPhone, OtpService.PURPOSE_REGISTRATION, clientIp);
    }

    public Map<String, Object> resendOtp(String phone, String clientIp) {
        String normalizedPhone = normalizePhone(phone);
        if (normalizedPhone == null || !normalizedPhone.matches("^\\+91[6-9]\\d{9}$")) {
            throw new IllegalArgumentException("Please enter a valid 10-digit mobile number.");
        }

        User user = userRepository.findByPhone(normalizedPhone).orElse(null);
        return otpService.issueOtp(user, normalizedPhone, OtpService.PURPOSE_REGISTRATION, clientIp);
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        return register(request, null);
    }

    @Transactional
    public AuthResponse register(RegisterRequest request, String clientIp) {
        String normalizedEmail = request.getEmail().toLowerCase().trim();
        String normalizedPhone = normalizePhone(request.getPhone().trim());

        // Application-level duplicate check (DB constraint is the final guard)
        if (userRepository.existsByEmailIgnoreCase(normalizedEmail)) {
            throw new IllegalArgumentException("Email is already registered");
        }
        if (userRepository.existsByPhone(normalizedPhone)) {
            throw new IllegalArgumentException("Phone number is already registered");
        }

        User user = User.builder()
                .name(request.getName().trim())
                .email(normalizedEmail)
                .phone(normalizedPhone)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .pinHash(request.getPin() != null ? passwordEncoder.encode(request.getPin()) : null)
                .role("ROLE_USER")
                .accountStatus("PENDING_VERIFICATION")
                .isVerified(false)
                .isLegacyAccount(false)
                .phoneVerifiedAt(null)
                .build();

        User savedUser = userRepository.save(user);
        log.info("New pending user registered: id={}, phone={}", savedUser.getId(), maskPhone(normalizedPhone));

        // Issue initial registration OTP transactionally with encrypted outbox entry
        otpService.issueOtp(savedUser, normalizedPhone, OtpService.PURPOSE_REGISTRATION, clientIp);

        // Security requirement: Do NOT issue JWT or refresh tokens before phone verification
        return AuthResponse.builder()
                .accessToken(null)
                .refreshToken(null)
                .tokenType(null)
                .userId(savedUser.getId())
                .name(savedUser.getName())
                .email(savedUser.getEmail())
                .phone(savedUser.getPhone())
                .role(savedUser.getRole())
                .build();
    }

    @Transactional
    public AuthResponse verifyOtp(String phone, String otpCode) {
        User verifiedUser = otpService.verifyOtp(phone, OtpService.PURPOSE_REGISTRATION, otpCode);
        if (verifiedUser == null) {
            throw new IllegalArgumentException("Verification completed but user record not found.");
        }
        return generateAuthResponse(verifiedUser);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        String identifier = request.getIdentifier().trim();
        User user = userRepository.findByEmailIgnoreCase(identifier.toLowerCase())
                .or(() -> userRepository.findByPhone(normalizePhone(identifier)))
                .orElseThrow(() -> new IllegalArgumentException("Invalid credentials"));

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new IllegalArgumentException("Invalid credentials");
        }

        // Check verification & legacy eligibility
        boolean isLegacy = Boolean.TRUE.equals(user.getIsLegacyAccount());
        boolean isPhoneVerified = user.getPhoneVerifiedAt() != null;

        if (!isLegacy && !isPhoneVerified) {
            log.warn("Login rejected for unverified non-legacy user: id={}", user.getId());
            throw new IllegalArgumentException("Account phone number is not verified. Please complete OTP verification.");
        }

        if (!"ACTIVE".equals(user.getAccountStatus())) {
            throw new IllegalArgumentException("Account is not active");
        }

        // Update last login timestamp
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        log.info("User logged in: id={}", user.getId());
        return generateAuthResponse(user);
    }

    public boolean verifyPassword(Long userId, String rawPassword) {
        if (userId == null || rawPassword == null || rawPassword.isBlank()) {
            return false;
        }
        User user = userRepository.findById(userId).orElse(null);
        if (user == null || user.getPasswordHash() == null) {
            return false;
        }
        return passwordEncoder.matches(rawPassword, user.getPasswordHash());
    }

    public boolean verifyPasswordByIdentifier(String identifier, String rawPassword) {
        if (identifier == null || rawPassword == null || rawPassword.isBlank()) {
            return false;
        }
        String cleanIdentifier = identifier.trim().toLowerCase();
        User user = userRepository.findByEmailIgnoreCase(cleanIdentifier)
                .or(() -> userRepository.findByPhone(normalizePhone(identifier.trim())))
                .orElse(null);
        if (user == null || user.getPasswordHash() == null) {
            return false;
        }
        return passwordEncoder.matches(rawPassword, user.getPasswordHash());
    }

    @Transactional
    public AuthResponse refreshToken(String rawRefreshToken) {
        // Validate the JWT structure
        if (!tokenProvider.validateToken(rawRefreshToken)) {
            throw new IllegalArgumentException("Invalid or expired refresh token");
        }

        // Verify it's actually a refresh token (not an access token)
        String tokenType = tokenProvider.getTokenType(rawRefreshToken);
        if (!"refresh".equals(tokenType)) {
            throw new IllegalArgumentException("Invalid token type");
        }

        // Look up the token hash in DB
        String tokenHash = hashToken(rawRefreshToken);
        RefreshToken storedToken = refreshTokenRepository.findByTokenHash(tokenHash)
                .orElseThrow(() -> new IllegalArgumentException("Refresh token not recognized"));

        // Check if revoked
        if (storedToken.isRevoked()) {
            // Potential token theft — revoke ALL tokens for this user
            refreshTokenRepository.revokeAllByUserId(storedToken.getUserId(), Instant.now());
            log.warn("Revoked refresh token reuse detected for user {}. All sessions revoked.", storedToken.getUserId());
            throw new IllegalArgumentException("Session has been revoked. Please log in again.");
        }

        if (storedToken.isExpired()) {
            throw new IllegalArgumentException("Refresh token has expired. Please log in again.");
        }

        // Revoke old token (rotation)
        storedToken.setRevokedAt(Instant.now());
        refreshTokenRepository.save(storedToken);

        // Issue new tokens
        User user = userRepository.findById(storedToken.getUserId())
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        // Check verification & legacy eligibility
        boolean isLegacy = Boolean.TRUE.equals(user.getIsLegacyAccount());
        boolean isPhoneVerified = user.getPhoneVerifiedAt() != null;

        if (!isLegacy && !isPhoneVerified) {
            log.warn("Token refresh rejected for unverified non-legacy user: id={}", user.getId());
            throw new IllegalArgumentException("Account phone number is not verified.");
        }

        if (!"ACTIVE".equals(user.getAccountStatus())) {
            throw new IllegalArgumentException("Account is not active");
        }

        log.info("Token refreshed for user: id={}", user.getId());
        return generateAuthResponse(user);
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        if (rawRefreshToken == null || rawRefreshToken.isBlank()) {
            return; // Graceful no-op
        }

        String tokenHash = hashToken(rawRefreshToken);
        refreshTokenRepository.findByTokenHash(tokenHash).ifPresent(token -> {
            token.setRevokedAt(Instant.now());
            refreshTokenRepository.save(token);
            log.info("User logged out: userId={}", token.getUserId());
        });
    }

    @Transactional
    public void deleteAccount(Long userId, String rawPassword) {
        if (userId == null) {
            throw new IllegalArgumentException("User ID is required for account deletion");
        }
        if (rawPassword == null || rawPassword.isBlank()) {
            throw new IllegalArgumentException("Account password is required for deletion verification");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        if (!passwordEncoder.matches(rawPassword, user.getPasswordHash())) {
            throw new IllegalArgumentException("Invalid account password. Deletion verification failed.");
        }

        log.info("Initiating cascading account deletion for user: id={}, email={}", userId, user.getEmail());

        // 1. Delete emergency events and dependent location updates & notification deliveries
        List<EmergencyEvent> events = emergencyRepository.findByUserIdOrderByStartedAtDesc(userId);
        for (EmergencyEvent event : events) {
            deliveryRepository.deleteAll(deliveryRepository.findByEmergencyEventIdOrderBySentAtDesc(event.getId()));
            locationRepository.deleteAll(locationRepository.findByEmergencyEventIdOrderByRecordedAtAsc(event.getId()));
        }
        emergencyRepository.deleteAll(events);

        // 2. Delete user incidents (evidence records)
        incidentRepository.deleteAll(incidentRepository.findByUserIdOrderByCreatedAtDesc(userId));

        // 3. Delete emergency contacts
        contactRepository.deleteAll(contactRepository.findByUserIdOrderByPriorityAsc(userId));

        // 4. Delete journeys and check-ins
        journeyRepository.deleteAll(journeyRepository.findByUserIdOrderByStartedAtDesc(userId));
        checkInRepository.deleteAll(checkInRepository.findByUserIdOrderByScheduledTimeDesc(userId));

        // 5. Delete refresh tokens
        refreshTokenRepository.deleteAllByUserId(userId);

        // 6. Delete user entity
        userRepository.delete(user);

        log.info("User account and all associated personal safety records successfully deleted for user: id={}", userId);
    }

    // --- Private helpers ---

    private AuthResponse generateAuthResponse(User user) {
        String accessToken = tokenProvider.generateAccessToken(user.getId(), user.getEmail(), user.getRole());
        String refreshToken = tokenProvider.generateRefreshToken(user.getId());

        // Persist refresh token hash
        RefreshToken tokenRecord = RefreshToken.builder()
                .userId(user.getId())
                .tokenHash(hashToken(refreshToken))
                .expiresAt(Instant.now().plusMillis(tokenProvider.getRefreshTokenExpirationMs()))
                .build();
        refreshTokenRepository.save(tokenRecord);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .userId(user.getId())
                .name(user.getName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole())
                .build();
    }

    private String normalizePhone(String phone) {
        if (phone == null) return null;
        // Remove all whitespace and dashes
        String cleaned = phone.replaceAll("[\\s\\-()]", "");
        // Ensure Indian numbers get +91 prefix if 10 digits
        if (cleaned.matches("^[6-9]\\d{9}$")) {
            cleaned = "+91" + cleaned;
        }
        return cleaned;
    }

    private String hashToken(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }

    private static String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return "***";
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 3);
    }
}
