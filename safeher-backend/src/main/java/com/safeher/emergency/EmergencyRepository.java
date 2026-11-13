package com.safeher.emergency;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface EmergencyRepository extends JpaRepository<EmergencyEvent, Long> {
    List<EmergencyEvent> findByUserIdOrderByStartedAtDesc(Long userId);
    Optional<EmergencyEvent> findByIdAndUserId(Long id, Long userId);
    Optional<EmergencyEvent> findFirstByUserIdAndStatusOrderByStartedAtDesc(Long userId, String status);
    Optional<EmergencyEvent> findByUserIdAndIdempotencyKeyAndStatus(Long userId, String idempotencyKey, String status);
    Optional<EmergencyEvent> findByUserIdAndClientEventUuidAndStatus(Long userId, String clientEventUuid, String status);
    List<EmergencyEvent> findByStatus(String status);
}
