package com.safeher.location;

import com.safeher.common.ResourceNotFoundException;
import com.safeher.emergency.EmergencyEvent;
import com.safeher.emergency.EmergencyRepository;
import com.safeher.location.dto.LocationSubmitRequest;
import com.safeher.user.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@Slf4j
@RequiredArgsConstructor
public class LocationService {

    private final LocationRepository locationRepository;
    private final EmergencyRepository emergencyRepository;

    @Transactional
    public LocationUpdate submitLocation(Long userId, Long eventId, LocationSubmitRequest request) {
        EmergencyEvent event = emergencyRepository.findByIdAndUserId(eventId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Active emergency event not found"));

        if (!"ACTIVE".equals(event.getStatus())) {
            throw new IllegalArgumentException("Cannot submit location for non-active emergency");
        }

        LocationUpdate update = LocationUpdate.builder()
                .emergencyEvent(event)
                .latitude(request.getLatitude())
                .longitude(request.getLongitude())
                .accuracy(request.getAccuracy())
                .recordedAt(request.getRecordedAt() != null ? request.getRecordedAt() : Instant.now())
                .build();

        return locationRepository.save(update);
    }

    public List<LocationUpdate> getLocationHistory(Long eventId) {
        return locationRepository.findByEmergencyEventIdOrderByRecordedAtAsc(eventId);
    }
}
