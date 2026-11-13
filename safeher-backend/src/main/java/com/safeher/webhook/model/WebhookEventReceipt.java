package com.safeher.webhook.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

/**
 * Entity mapping the deduplication receipts table for incoming webhook callbacks.
 * Matches Flyway V6 table: webhook_event_receipts.
 */
@Entity
@Table(name = "webhook_event_receipts")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class WebhookEventReceipt {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "provider_event_id", nullable = false, unique = true, length = 100)
    private String providerEventId;

    @Column(name = "request_id", nullable = false, length = 100)
    private String requestId;

    @Column(name = "correlation_id", length = 64)
    private String correlationId;

    @Column(name = "status_code", nullable = false, length = 20)
    private String statusCode;

    @Column(name = "delivery_time")
    private Instant deliveryTime;

    @CreationTimestamp
    @Column(name = "received_at", nullable = false, updatable = false)
    private Instant receivedAt;
}
