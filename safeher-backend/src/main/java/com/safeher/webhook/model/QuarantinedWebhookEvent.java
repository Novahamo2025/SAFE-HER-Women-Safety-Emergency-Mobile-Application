package com.safeher.webhook.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

/**
 * Entity mapping the quarantine audit table for malformed or unmatched webhook events.
 * Matches Flyway V6 table: quarantined_webhook_events.
 */
@Entity
@Table(name = "quarantined_webhook_events")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class QuarantinedWebhookEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "raw_payload", nullable = false, columnDefinition = "TEXT")
    private String rawPayload;

    @Column(name = "rejection_reason", nullable = false, length = 255)
    private String rejectionReason;

    @Column(name = "source_ip", length = 50)
    private String sourceIp;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
