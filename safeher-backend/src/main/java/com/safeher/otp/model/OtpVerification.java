package com.safeher.otp.model;

import com.safeher.user.User;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

/**
 * Entity representing an OTP verification record.
 * Matches Flyway V6 table: otp_verifications.
 */
@Entity
@Table(name = "otp_verifications")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OtpVerification {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(nullable = false, length = 20)
    private String phone;

    @Column(nullable = false, length = 30)
    @Builder.Default
    private String purpose = "REGISTRATION";

    @Column(name = "otp_hash", nullable = false, length = 64)
    private String otpHash;

    @Column(nullable = false, length = 32)
    private String salt;

    @Column(name = "pepper_version", nullable = false, length = 10)
    @Builder.Default
    private String pepperVersion = "v1";

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    @Builder.Default
    private OtpStatus status = OtpStatus.PENDING;

    @Column(name = "attempts_count", nullable = false)
    @Builder.Default
    private Integer attemptsCount = 0;

    @Column(name = "max_attempts", nullable = false)
    @Builder.Default
    private Integer maxAttempts = 3;

    @Column(name = "expires_at", nullable = false)
    private Instant expiresAt;

    @Column(name = "consumed_at")
    private Instant consumedAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
