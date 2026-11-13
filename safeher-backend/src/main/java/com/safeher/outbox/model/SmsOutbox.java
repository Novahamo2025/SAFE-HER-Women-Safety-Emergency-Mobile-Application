package com.safeher.outbox.model;

import com.safeher.otp.model.OtpVerification;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.Instant;

/**
 * Entity representing a transactional SMS Outbox record.
 * Matches Flyway V6 table: sms_outbox.
 *
 * Implements crash-proof, at-least-once dispatch semantics with
 * authenticated AES-256-GCM payload encryption and logical ciphertext deletion upon acceptance.
 */
@Entity
@Table(name = "sms_outbox")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SmsOutbox {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "otp_verification_id", nullable = false)
    private OtpVerification otpVerification;

    @Column(nullable = false, length = 20)
    private String phone;

    @Column(name = "correlation_id", nullable = false, unique = true, length = 64)
    private String correlationId;

    @Column(name = "key_version", nullable = false, length = 10)
    @Builder.Default
    private String keyVersion = "v1";

    @Column(name = "encrypted_payload", columnDefinition = "TEXT")
    private String encryptedPayload;

    @Column(name = "payload_nonce", length = 32)
    private String payloadNonce;

    @Column(name = "payload_tag", length = 32)
    private String payloadTag;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    @Builder.Default
    private SmsOutboxStatus status = SmsOutboxStatus.CREATED;

    @Column(name = "provider_ref", length = 100)
    private String providerRef;

    @Column(name = "dispatch_started_at")
    private Instant dispatchStartedAt;

    @Column(name = "retry_count", nullable = false)
    @Builder.Default
    private Integer retryCount = 0;

    @Column(name = "max_retries", nullable = false)
    @Builder.Default
    private Integer maxRetries = 3;

    @Column(name = "next_reconcile_at", nullable = false)
    private Instant nextReconcileAt;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /**
     * Performs logical deletion of the encrypted payload, nonce, and tag.
     * Note: Eliminates application-level access to ciphertext in the database row,
     * but does not guarantee immediate physical zeroization of PostgreSQL disk pages or WAL.
     */
    public void clearCiphertext() {
        this.encryptedPayload = null;
        this.payloadNonce = null;
        this.payloadTag = null;
    }
}
