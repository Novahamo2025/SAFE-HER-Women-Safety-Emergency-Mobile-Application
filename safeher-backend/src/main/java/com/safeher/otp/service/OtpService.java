package com.safeher.otp.service;

import com.safeher.otp.model.OtpStatus;
import com.safeher.otp.model.OtpVerification;
import com.safeher.otp.repository.OtpVerificationRepository;
import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.service.SmsOutboxDispatcher;
import com.safeher.security.crypto.OtpHashingService;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/**
 * Service orchestrating the OTP lifecycle:
 * - Generation of cryptographically uniform 6-digit numeric codes.
 * - Context-bound HMAC-SHA256 salted hashing (never storing plaintext OTP).
 * - Integration with durable SMS Outbox dispatcher.
 * - Sliding-window rate limit and cooldown enforcement.
 * - Constant-time OTP verification with persistent failed-attempt tracking.
 * - Atomic OTP consumption and user phone verification.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class OtpService {

    public static final String PURPOSE_REGISTRATION = "REGISTRATION";
    public static final int OTP_EXPIRATION_MINUTES = 10;
    public static final int MAX_ATTEMPTS = 3;

    private final OtpVerificationRepository otpVerificationRepository;
    private final OtpHashingService otpHashingService;
    private final SmsOutboxDispatcher smsOutboxDispatcher;
    private final OtpRateLimiter otpRateLimiter;
    private final OtpVerificationTransactionService otpTransactionService;
    private final UserRepository userRepository;

    @Value("${app.crypto.otp-pepper-version:v1}")
    private String defaultPepperVersion = "v1";

    /**
     * Issues an OTP for registration or verification.
     * Enforces rate limits, supersedes older active OTPs, hashes the OTP,
     * creates an encrypted SMS outbox entry, and dispatches it.
     */
    @Transactional
    public Map<String, Object> issueOtp(User user, String rawPhone, String purpose, String clientIp) {
        String phone = normalizePhone(rawPhone);
        if (phone == null || !phone.matches("^\\+91[6-9]\\d{9}$")) {
            throw new IllegalArgumentException("Please enter a valid 10-digit mobile number.");
        }

        String validPurpose = (purpose != null && !purpose.isBlank()) ? purpose : PURPOSE_REGISTRATION;

        // 1. Enforce rate limits and cooldown
        otpRateLimiter.checkAndRecordOtpDispatch(phone, clientIp);

        // 2. Supersede any existing pending OTPs for (phone, purpose) to satisfy idx_unique_active_otp_per_phone
        otpTransactionService.supersedePendingOtps(phone, validPurpose);

        // 3. Generate uniform 6-digit OTP and random 16-byte salt
        String plaintextOtp = otpHashingService.generateOtp();
        String saltHex = otpHashingService.generateSalt();

        // 4. Compute context-bound HMAC-SHA256 hash
        String otpHash = otpHashingService.computeHash(
                phone, validPurpose, plaintextOtp, saltHex
        );

        Instant now = Instant.now();
        Instant expiresAt = now.plus(OTP_EXPIRATION_MINUTES, ChronoUnit.MINUTES);

        // 5. Persist OtpVerification record
        OtpVerification verification = OtpVerification.builder()
                .user(user)
                .phone(phone)
                .purpose(validPurpose)
                .otpHash(otpHash)
                .salt(saltHex)
                .pepperVersion(defaultPepperVersion)
                .status(OtpStatus.PENDING)
                .attemptsCount(0)
                .maxAttempts(MAX_ATTEMPTS)
                .expiresAt(expiresAt)
                .createdAt(now)
                .build();

        OtpVerification savedVerification = otpVerificationRepository.save(verification);
        log.info("OTP verification record [{}] created for phone: {} (purpose: {})",
                savedVerification.getId(), maskPhone(phone), validPurpose);

        // 6. Create encrypted SMS outbox entry using Stage 4 dispatcher
        String smsMessage = "Your SafeHer verification code is: " + plaintextOtp + ". Valid for " + OTP_EXPIRATION_MINUTES + " minutes. Do not share this code.";
        String correlationId = "OTP-" + UUID.randomUUID().toString();
        SmsOutbox outbox = smsOutboxDispatcher.createOutboxEntry(savedVerification, phone, smsMessage, correlationId);

        // 7. Trigger immediate dispatch for low latency
        smsOutboxDispatcher.dispatchSingle(outbox.getId());

        Map<String, Object> result = new HashMap<>();
        result.put("phone", phone);
        result.put("purpose", validPurpose);
        result.put("expiresAt", expiresAt);
        result.put("cooldownSeconds", 45);
        result.put("message", "OTP sent successfully to registered mobile number.");
        return result;
    }

    /**
     * Verifies a user-submitted OTP code.
     * Enforces failure limits, validates constant-time HMAC hash, persists attempt counters
     * across failure responses, and atomically marks the OTP CONSUMED and the user account ACTIVE.
     */
    public User verifyOtp(String rawPhone, String purpose, String rawOtp) {
        String phone = normalizePhone(rawPhone);
        if (phone == null || phone.isBlank()) {
            throw new IllegalArgumentException("Mobile number is required.");
        }
        if (rawOtp == null || rawOtp.isBlank()) {
            throw new IllegalArgumentException("OTP code is required.");
        }

        String validPurpose = (purpose != null && !purpose.isBlank()) ? purpose : PURPOSE_REGISTRATION;

        // 1. Enforce max failed attempts rate limit (5 failed attempts per phone per 15 minutes)
        otpRateLimiter.checkFailedVerificationLimit(phone);

        // 2. Retrieve active PENDING OTP verification record
        OtpVerification verification = otpVerificationRepository
                .findByPhoneAndPurposeAndStatus(phone, validPurpose, OtpStatus.PENDING)
                .orElseThrow(() -> new IllegalArgumentException("No active OTP verification found for this phone number. Please request a new OTP."));

        // 3. Check expiration
        if (Instant.now().isAfter(verification.getExpiresAt())) {
            otpTransactionService.markExpired(verification.getId());
            throw new IllegalArgumentException("OTP code has expired. Please request a new one.");
        }

        // 4. Check if maximum attempts on this code are already exceeded
        if (verification.getAttemptsCount() >= verification.getMaxAttempts()) {
            throw new IllegalArgumentException("Maximum verification attempts exceeded. Please request a new OTP.");
        }

        // 5. Validate OTP using constant-time comparison
        boolean matches = otpHashingService.verifyOtp(
                phone,
                validPurpose,
                rawOtp.trim(),
                verification.getSalt(),
                verification.getOtpHash()
        );

        if (!matches) {
            // Persist failed attempt in separate transaction (guaranteed to commit even on exception)
            var failResult = otpTransactionService.recordFailedAttempt(verification.getId(), phone);
            if (failResult.exceeded()) {
                throw new IllegalArgumentException("Maximum verification attempts exceeded. Please request a new OTP.");
            }
            int remaining = failResult.maxAttempts() - failResult.currentAttempts();
            throw new IllegalArgumentException("Invalid OTP code. " + remaining + " attempts remaining.");
        }

        // 6. OTP matched: Atomically consume OTP and verify User account
        Long userId = verification.getUser() != null ? verification.getUser().getId() : null;
        return otpTransactionService.consumeOtpAndVerifyUser(verification.getId(), userId);
    }

    public static String normalizePhone(String phone) {
        if (phone == null) return null;
        String cleaned = phone.replaceAll("[\\s\\-()]", "");
        if (cleaned.matches("^[6-9]\\d{9}$")) {
            cleaned = "+91" + cleaned;
        }
        return cleaned;
    }

    private static String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return "***";
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 3);
    }
}
