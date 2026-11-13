package com.safeher.otp.service;

import com.safeher.otp.model.OtpStatus;
import com.safeher.otp.model.OtpVerification;
import com.safeher.otp.model.RateLimitEvent;
import com.safeher.otp.repository.OtpVerificationRepository;
import com.safeher.otp.repository.RateLimitEventRepository;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

/**
 * Service managing strict database transaction boundaries for OTP verification lifecycle.
 *
 * Enforces key transactional guarantees:
 * 1. Failed attempts, expired states, and exceeded-attempt states are committed in isolated transactions (REQUIRES_NEW),
 *    ensuring counters and state transitions persist even when the verification throws an HTTP exception.
 * 2. OTP consumption and user account verification (phone_verified_at, is_verified=true, account_status=ACTIVE)
 *    are committed atomically in a single transaction, preventing inconsistent states.
 * 3. Concurrent verification requests use row-level write locks (FOR UPDATE) to prevent double consumption.
 * 4. Superseding older pending OTPs guarantees partial unique index compliance (idx_unique_active_otp_per_phone).
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class OtpVerificationTransactionService {

    private final OtpVerificationRepository otpVerificationRepository;
    private final UserRepository userRepository;
    private final RateLimitEventRepository rateLimitEventRepository;

    /**
     * Supersedes all existing PENDING OTP records for the given phone and purpose.
     * Prevents constraint violation on idx_unique_active_otp_per_phone.
     */
    @Transactional
    public void supersedePendingOtps(String phone, String purpose) {
        List<OtpVerification> pendingList = otpVerificationRepository
                .findByPhoneAndPurposeAndStatusOrderByCreatedAtDesc(phone, purpose, OtpStatus.PENDING);

        if (!pendingList.isEmpty()) {
            for (OtpVerification v : pendingList) {
                v.setStatus(OtpStatus.SUPERSEDED);
                log.info("OTP Verification [{}] superseded for phone: {}", v.getId(), maskPhone(phone));
            }
            otpVerificationRepository.saveAll(pendingList);
            otpVerificationRepository.flush();
        }
    }

    /**
     * Records a failed OTP verification attempt in a separate, isolated transaction.
     *
     * Increments attempts_count. If attempts_count >= max_attempts, marks status = EXCEEDED.
     * Also logs a FAILED_VERIFY event in rate_limit_events.
     * COMMITS before returning.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public FailedAttemptResult recordFailedAttempt(Long verificationId, String phone) {
        OtpVerification verification = otpVerificationRepository.findByIdForUpdate(verificationId)
                .orElseThrow(() -> new IllegalStateException("OTP verification record not found: " + verificationId));

        int newAttempts = verification.getAttemptsCount() + 1;
        verification.setAttemptsCount(newAttempts);

        boolean exceeded = newAttempts >= verification.getMaxAttempts();
        if (exceeded) {
            verification.setStatus(OtpStatus.EXCEEDED);
            log.warn("OTP Verification [{}] for phone {} marked EXCEEDED ({} attempts)",
                    verificationId, maskPhone(phone), newAttempts);
        } else {
            log.warn("OTP Verification [{}] failed attempt {} of {}",
                    verificationId, newAttempts, verification.getMaxAttempts());
        }

        otpVerificationRepository.saveAndFlush(verification);

        // Record sliding-window rate limit event
        rateLimitEventRepository.save(RateLimitEvent.builder()
                .scopeKey("PHONE:" + phone)
                .actionType(OtpRateLimiter.ACTION_FAILED_VERIFY)
                .eventTimestamp(Instant.now())
                .build());

        return new FailedAttemptResult(newAttempts, verification.getMaxAttempts(), exceeded);
    }

    /**
     * Marks an OTP verification record as EXPIRED in an isolated transaction and COMMITS.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void markExpired(Long verificationId) {
        otpVerificationRepository.findByIdForUpdate(verificationId).ifPresent(v -> {
            if (v.getStatus() == OtpStatus.PENDING) {
                v.setStatus(OtpStatus.EXPIRED);
                otpVerificationRepository.saveAndFlush(v);
                log.warn("OTP Verification [{}] marked EXPIRED", verificationId);
            }
        });
    }

    /**
     * Atomically consumes the OTP verification and verifies the associated user account.
     *
     * Guaranteed atomic commitment:
     * - otp_verifications: status = CONSUMED, consumed_at = NOW()
     * - users: phone_verified_at = NOW(), is_verified = TRUE, account_status = 'ACTIVE'
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public User consumeOtpAndVerifyUser(Long verificationId, Long userId) {
        OtpVerification verification = otpVerificationRepository.findByIdForUpdate(verificationId)
                .orElseThrow(() -> new IllegalStateException("OTP verification not found: " + verificationId));

        if (verification.getStatus() != OtpStatus.PENDING) {
            throw new IllegalStateException("OTP verification is not PENDING (current status: " + verification.getStatus() + ")");
        }

        Instant now = Instant.now();
        verification.setStatus(OtpStatus.CONSUMED);
        verification.setConsumedAt(now);
        otpVerificationRepository.saveAndFlush(verification);

        // Resolve user
        User user = null;
        if (userId != null) {
            user = userRepository.findById(userId).orElse(null);
        } else if (verification.getUser() != null) {
            user = verification.getUser();
        } else {
            user = userRepository.findByPhone(verification.getPhone()).orElse(null);
        }

        if (user != null) {
            user.setPhoneVerifiedAt(now);
            user.setIsVerified(true);
            user.setAccountStatus("ACTIVE");
            User verifiedUser = userRepository.saveAndFlush(user);
            log.info("User [{}] phone successfully verified and account marked ACTIVE (phone: {})",
                    verifiedUser.getId(), maskPhone(verification.getPhone()));
            return verifiedUser;
        } else {
            log.warn("No user found associated with OTP verification [{}] for phone: {}",
                    verificationId, maskPhone(verification.getPhone()));
            return null;
        }
    }

    public record FailedAttemptResult(int currentAttempts, int maxAttempts, boolean exceeded) {}

    private static String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return "***";
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 3);
    }
}
