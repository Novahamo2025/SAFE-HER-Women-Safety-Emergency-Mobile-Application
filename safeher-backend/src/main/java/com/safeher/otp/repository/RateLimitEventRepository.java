package com.safeher.otp.repository;

import com.safeher.otp.model.RateLimitEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;

@Repository
public interface RateLimitEventRepository extends JpaRepository<RateLimitEvent, Long> {

    /**
     * Counts events within a sliding time window (from cutoff to now).
     */
    long countByScopeKeyAndActionTypeAndEventTimestampAfter(String scopeKey, String actionType, Instant cutoff);

    /**
     * Finds the most recent event for cooldown enforcement.
     */
    Optional<RateLimitEvent> findTopByScopeKeyAndActionTypeOrderByEventTimestampDesc(String scopeKey, String actionType);
}
