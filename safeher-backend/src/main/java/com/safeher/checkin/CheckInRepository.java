package com.safeher.checkin;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface CheckInRepository extends JpaRepository<CheckIn, Long> {
    List<CheckIn> findByUserIdOrderByScheduledTimeDesc(Long userId);
    Optional<CheckIn> findByIdAndUserId(Long id, Long userId);
    List<CheckIn> findByStatusAndScheduledTimeBefore(String status, Instant threshold);
}
