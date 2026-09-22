package com.safeher.journey;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface JourneyRepository extends JpaRepository<SafeJourney, Long> {
    List<SafeJourney> findByUserIdOrderByStartedAtDesc(Long userId);
    Optional<SafeJourney> findByIdAndUserId(Long id, Long userId);
    List<SafeJourney> findByStatusAndExpectedArrivalBefore(String status, Instant threshold);
}
