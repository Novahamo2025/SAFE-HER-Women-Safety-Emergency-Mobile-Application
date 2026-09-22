package com.safeher.location;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface LocationRepository extends JpaRepository<LocationUpdate, Long> {
    List<LocationUpdate> findByEmergencyEventIdOrderByRecordedAtAsc(Long emergencyEventId);
    Optional<LocationUpdate> findFirstByEmergencyEventIdOrderByRecordedAtDesc(Long emergencyEventId);
}
