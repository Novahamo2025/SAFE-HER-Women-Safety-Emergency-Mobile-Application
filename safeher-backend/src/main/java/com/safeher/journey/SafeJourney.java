package com.safeher.journey;

import com.safeher.user.User;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "safe_journeys")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SafeJourney {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(nullable = false)
    private String destination;

    @Column(name = "start_lat", precision = 10, scale = 7)
    private BigDecimal startLat;

    @Column(name = "start_lng", precision = 10, scale = 7)
    private BigDecimal startLng;

    @Column(name = "dest_lat", precision = 10, scale = 7)
    private BigDecimal destLat;

    @Column(name = "dest_lng", precision = 10, scale = 7)
    private BigDecimal destLng;

    @Column(name = "expected_arrival", nullable = false)
    private Instant expectedArrival;

    @Column(name = "grace_period_minutes", nullable = false)
    @Builder.Default
    private Integer gracePeriodMinutes = 5;

    @Column(nullable = false, length = 30)
    @Builder.Default
    private String status = "ACTIVE"; // ACTIVE, COMPLETED, OVERDUE, ESCALATED, CANCELLED

    @CreationTimestamp
    @Column(name = "started_at", nullable = false, updatable = false)
    private Instant startedAt;

    @Column(name = "completed_at")
    private Instant completedAt;
}
