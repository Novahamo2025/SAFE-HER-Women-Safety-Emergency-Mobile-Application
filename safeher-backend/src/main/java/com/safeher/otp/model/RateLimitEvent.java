package com.safeher.otp.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Entity mapping the persistent sliding-window rate limit events table.
 * Matches Flyway V6 table: rate_limit_events.
 */
@Entity
@Table(name = "rate_limit_events")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RateLimitEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "scope_key", nullable = false, length = 100)
    private String scopeKey;

    @Column(name = "action_type", nullable = false, length = 30)
    private String actionType;

    @Column(name = "event_timestamp", nullable = false)
    private Instant eventTimestamp;

    @PrePersist
    protected void onCreate() {
        if (eventTimestamp == null) {
            eventTimestamp = Instant.now();
        }
    }
}
