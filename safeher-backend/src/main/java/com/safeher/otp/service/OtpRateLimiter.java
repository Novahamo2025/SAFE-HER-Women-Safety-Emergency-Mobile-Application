package com.safeher.otp.service;

import com.safeher.otp.exception.OtpCooldownException;
import com.safeher.otp.exception.OtpRateLimitException;
import com.safeher.otp.model.RateLimitEvent;
import com.safeher.otp.repository.RateLimitEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

/**
 * Service enforcing persistent sliding-window rate limits and cooldowns for OTP operations.
 *
 * Rules:
 * 1. 45-second resend cooldown per phone number.
 * 2. Maximum 5 OTP requests per phone per hour.
 * 3. Maximum 10 OTP requests per IP per hour.
 * 4. Maximum 5 failed verification attempts per phone per 15 minutes.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class OtpRateLimiter {

    public static final String ACTION_OTP_DISPATCH = "OTP_DISPATCH";
    public static final String ACTION_FAILED_VERIFY = "FAILED_VERIFY";

    private static final int COOLDOWN_SECONDS = 45;
    private static final int MAX_OTP_PER_PHONE_HOUR = 5;
    private static final int MAX_OTP_PER_IP_HOUR = 10;
    private static final int MAX_FAILED_VERIFY_PER_PHONE_15M = 5;

    private final RateLimitEventRepository rateLimitEventRepository;

    /**
     * Checks and records an OTP dispatch event across phone and IP scopes.
     * Enforces 45-second cooldown and hourly phone/IP limits.
     */
    @Transactional
    public void checkAndRecordOtpDispatch(String phone, String clientIp) {
        Instant now = Instant.now();
        String phoneScope = "PHONE:" + phone;

        // 1. Enforce 45-second resend cooldown
        Optional<RateLimitEvent> latestDispatch = rateLimitEventRepository
                .findTopByScopeKeyAndActionTypeOrderByEventTimestampDesc(phoneScope, ACTION_OTP_DISPATCH);

        if (latestDispatch.isPresent()) {
            Instant latestTime = latestDispatch.get().getEventTimestamp();
            long elapsedSeconds = Duration.between(latestTime, now).getSeconds();
            if (elapsedSeconds < COOLDOWN_SECONDS) {
                long retryAfter = COOLDOWN_SECONDS - elapsedSeconds;
                log.warn("RateLimit: Cooldown active for phone {}. Retry after {}s", maskPhone(phone), retryAfter);
                throw new OtpCooldownException(
                        "Please wait " + retryAfter + " seconds before requesting another OTP.",
                        retryAfter
                );
            }
        }

        // 2. Enforce Max 5 OTP requests per phone per hour
        Instant oneHourAgo = now.minus(Duration.ofHours(1));
        long phoneDispatchesLastHour = rateLimitEventRepository
                .countByScopeKeyAndActionTypeAndEventTimestampAfter(phoneScope, ACTION_OTP_DISPATCH, oneHourAgo);

        if (phoneDispatchesLastHour >= MAX_OTP_PER_PHONE_HOUR) {
            log.warn("RateLimit: Max hourly dispatches exceeded for phone {}", maskPhone(phone));
            throw new OtpRateLimitException(
                    "Maximum OTP requests exceeded for this phone number. Please try again after 1 hour.",
                    phoneScope, MAX_OTP_PER_PHONE_HOUR, "1 hour"
            );
        }

        // 3. Enforce Max 10 OTP requests per IP per hour (if IP provided)
        String ipScope = null;
        if (clientIp != null && !clientIp.isBlank()) {
            ipScope = "IP:" + clientIp.trim();
            long ipDispatchesLastHour = rateLimitEventRepository
                    .countByScopeKeyAndActionTypeAndEventTimestampAfter(ipScope, ACTION_OTP_DISPATCH, oneHourAgo);

            if (ipDispatchesLastHour >= MAX_OTP_PER_IP_HOUR) {
                log.warn("RateLimit: Max hourly dispatches exceeded for IP {}", clientIp);
                throw new OtpRateLimitException(
                        "Maximum OTP requests exceeded for this IP address. Please try again after 1 hour.",
                        ipScope, MAX_OTP_PER_IP_HOUR, "1 hour"
                );
            }
        }

        // 4. Atomically persist dispatch events for both scopes
        rateLimitEventRepository.save(RateLimitEvent.builder()
                .scopeKey(phoneScope)
                .actionType(ACTION_OTP_DISPATCH)
                .eventTimestamp(now)
                .build());

        if (ipScope != null) {
            rateLimitEventRepository.save(RateLimitEvent.builder()
                    .scopeKey(ipScope)
                    .actionType(ACTION_OTP_DISPATCH)
                    .eventTimestamp(now)
                    .build());
        }
    }

    /**
     * Checks if the phone has exceeded 5 failed verification attempts in the last 15 minutes.
     */
    @Transactional(readOnly = true)
    public void checkFailedVerificationLimit(String phone) {
        Instant fifteenMinutesAgo = Instant.now().minus(Duration.ofMinutes(15));
        String phoneScope = "PHONE:" + phone;

        long failedCount = rateLimitEventRepository
                .countByScopeKeyAndActionTypeAndEventTimestampAfter(phoneScope, ACTION_FAILED_VERIFY, fifteenMinutesAgo);

        if (failedCount >= MAX_FAILED_VERIFY_PER_PHONE_15M) {
            log.warn("RateLimit: Max failed verification attempts exceeded for phone {}", maskPhone(phone));
            throw new OtpRateLimitException(
                    "Too many failed verification attempts. Please try again after 15 minutes.",
                    phoneScope, MAX_FAILED_VERIFY_PER_PHONE_15M, "15 minutes"
            );
        }
    }

    /**
     * Records a failed verification event for the phone.
     */
    @Transactional
    public void recordFailedVerification(String phone) {
        String phoneScope = "PHONE:" + phone;
        rateLimitEventRepository.save(RateLimitEvent.builder()
                .scopeKey(phoneScope)
                .actionType(ACTION_FAILED_VERIFY)
                .eventTimestamp(Instant.now())
                .build());
        log.warn("RateLimit: Recorded failed verification event for phone {}", maskPhone(phone));
    }

    private static String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return "***";
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 3);
    }
}
