package com.safeher.emergency;

import com.safeher.common.ResourceNotFoundException;
import com.safeher.emergency.dto.EmergencyCancelRequest;
import com.safeher.emergency.dto.EmergencyEventResponse;
import com.safeher.emergency.dto.EmergencyStartRequest;
import com.safeher.emergency.dto.LocationUpdateRequest;
import com.safeher.location.LocationRepository;
import com.safeher.location.LocationUpdate;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Optional;

@Service
@Slf4j
@RequiredArgsConstructor
public class EmergencyService {

    private final EmergencyRepository emergencyRepository;
    private final LocationRepository locationRepository;
    private final UserRepository userRepository;

    @Transactional
    public EmergencyEventResponse startEmergency(Long userId, EmergencyStartRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        // Check if an active emergency already exists — return it instead of creating duplicate
        Optional<EmergencyEvent> existingActive = emergencyRepository
                .findFirstByUserIdAndStatusOrderByStartedAtDesc(userId, "ACTIVE");
        if (existingActive.isPresent()) {
            log.info("Returning existing active emergency {} for user {}", existingActive.get().getId(), userId);
            return toResponse(existingActive.get());
        }

        EmergencyEvent event = EmergencyEvent.builder()
                .user(user)
                .eventType(request.getEventType() != null ? request.getEventType() : "SOS")
                .status("ACTIVE")
                .clientEventUuid(request.getClientEventUuid())
                .build();

        EmergencyEvent savedEvent = emergencyRepository.save(event);
        log.info("Emergency event started: id={}, userId={}, type={}", savedEvent.getId(), userId, savedEvent.getEventType());

        // Record initial location update
        if (request.getLatitude() != null && request.getLongitude() != null) {
            saveLocationUpdate(savedEvent, request.getLatitude(), request.getLongitude(), request.getAccuracyMeters());
        }

        return toResponse(savedEvent);
    }

    @Transactional
    public void updateLocation(Long userId, Long eventId, LocationUpdateRequest request) {
        EmergencyEvent event = emergencyRepository.findByIdAndUserId(eventId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Emergency event not found"));

        // Only accept location updates for active events
        EventStatus currentStatus = EventStatus.fromString(event.getStatus());
        if (currentStatus != EventStatus.ACTIVE) {
            throw new IllegalStateException("Cannot update location for event in status: " + event.getStatus());
        }

        saveLocationUpdate(event, request.getLatitude(), request.getLongitude(), request.getAccuracyMeters());
        log.debug("Location updated for event {}", eventId);
    }

    @Transactional
    public EmergencyEventResponse cancelEmergency(Long userId, Long eventId, EmergencyCancelRequest request) {
        EmergencyEvent event = emergencyRepository.findByIdAndUserId(eventId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Emergency event not found"));

        // Validate state transition
        EventStatus currentStatus = EventStatus.fromString(event.getStatus());
        if (!currentStatus.canTransitionTo(EventStatus.CANCELLED)) {
            // If already cancelled, return current state (idempotent)
            if (currentStatus == EventStatus.CANCELLED || currentStatus == EventStatus.RESOLVED) {
                return toResponse(event);
            }
            throw new IllegalStateException("Cannot cancel event in status: " + event.getStatus());
        }

        event.setStatus(EventStatus.CANCELLED.name());
        event.setEndedAt(Instant.now());
        event.setCancellationReason(request != null ? request.getReason() : "User marked safe");

        EmergencyEvent saved = emergencyRepository.save(event);
        log.info("Emergency event cancelled: id={}, userId={}", eventId, userId);
        return toResponse(saved);
    }

    public EmergencyEventResponse getEmergencyStatus(Long userId, Long eventId) {
        EmergencyEvent event = emergencyRepository.findByIdAndUserId(eventId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Emergency event not found"));
        return toResponse(event);
    }

    // --- Private helpers ---

    private void saveLocationUpdate(EmergencyEvent event, java.math.BigDecimal lat, java.math.BigDecimal lng, java.math.BigDecimal accuracy) {
        LocationUpdate location = LocationUpdate.builder()
                .emergencyEvent(event)
                .latitude(lat)
                .longitude(lng)
                .accuracy(accuracy)
                .recordedAt(Instant.now())
                .build();
        locationRepository.save(location);
    }

    private EmergencyEventResponse toResponse(EmergencyEvent event) {
        return EmergencyEventResponse.builder()
                .id(event.getId())
                .eventType(event.getEventType())
                .status(event.getStatus())
                .clientEventUuid(event.getClientEventUuid())
                .startedAt(event.getStartedAt())
                .endedAt(event.getEndedAt())
                .updatedAt(event.getUpdatedAt())
                .cancellationReason(event.getCancellationReason())
                .build();
    }
}
