package com.safeher.emergency;

import com.safeher.common.ResourceNotFoundException;
import com.safeher.contact.ContactRepository;
import com.safeher.contact.EmergencyContact;
import com.safeher.emergency.dto.EmergencyCancelRequest;
import com.safeher.emergency.dto.EmergencyStartRequest;
import com.safeher.location.LocationRepository;
import com.safeher.location.LocationUpdate;
import com.safeher.notification.SmsGatewayService;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@Slf4j
@RequiredArgsConstructor
public class EmergencyService {

    private final EmergencyRepository emergencyRepository;
    private final LocationRepository locationRepository;
    private final ContactRepository contactRepository;
    private final UserRepository userRepository;
    private final SmsGatewayService smsGatewayService;

    @Transactional
    public EmergencyEvent startEmergency(Long userId, EmergencyStartRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        // Check if an active emergency already exists
        emergencyRepository.findFirstByUserIdAndStatusOrderByStartedAtDesc(userId, "ACTIVE")
                .ifPresent(activeEvent -> {
                    log.warn("Active emergency {} already exists for user {}", activeEvent.getId(), userId);
                });

        EmergencyEvent event = EmergencyEvent.builder()
                .user(user)
                .eventType(request.getEventType() != null ? request.getEventType() : "SOS")
                .status("ACTIVE")
                .clientEventUuid(request.getClientEventUuid())
                .build();

        EmergencyEvent savedEvent = emergencyRepository.save(event);

        // Record initial location update
        if (request.getLatitude() != null && request.getLongitude() != null) {
            LocationUpdate initialLocation = LocationUpdate.builder()
                    .emergencyEvent(savedEvent)
                    .latitude(request.getLatitude())
                    .longitude(request.getLongitude())
                    .accuracy(request.getAccuracyMeters())
                    .recordedAt(Instant.now())
                    .build();
            locationRepository.save(initialLocation);
        }

        // Trigger notifications to verified/priority emergency contacts
        List<EmergencyContact> contacts = contactRepository.findByUserIdOrderByPriorityAsc(userId);
        String mapsUrl = String.format("https://maps.google.com/?q=%s,%s", request.getLatitude(), request.getLongitude());

        for (EmergencyContact contact : contacts) {
            if (contact.getNotifySms()) {
                smsGatewayService.dispatchEmergencySms(savedEvent, contact.getPhone(), user.getName(), mapsUrl);
            }
        }

        return savedEvent;
    }

    @Transactional
    public EmergencyEvent cancelEmergency(Long userId, Long eventId, EmergencyCancelRequest request) {
        EmergencyEvent event = emergencyRepository.findByIdAndUserId(eventId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Emergency event not found"));

        event.setStatus("RESOLVED");
        event.setEndedAt(Instant.now());
        event.setCancellationReason(request != null ? request.getReason() : "User marked safe");

        return emergencyRepository.save(event);
    }

    public EmergencyEvent getEmergencyStatus(Long userId, Long eventId) {
        return emergencyRepository.findByIdAndUserId(eventId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Emergency event not found"));
    }
}
