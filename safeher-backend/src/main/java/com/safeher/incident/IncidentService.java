package com.safeher.incident;

import com.safeher.common.ResourceNotFoundException;
import com.safeher.emergency.EmergencyEvent;
import com.safeher.emergency.EmergencyRepository;
import com.safeher.incident.dto.IncidentCreateRequest;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class IncidentService {

    private final IncidentRepository incidentRepository;
    private final EmergencyRepository emergencyRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public List<Incident> getUserIncidents(Long userId) {
        return incidentRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    @Transactional
    public Incident createIncident(Long userId, IncidentCreateRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        EmergencyEvent event = null;
        if (request.getEmergencyEventId() != null) {
            event = emergencyRepository.findByIdAndUserId(request.getEmergencyEventId(), userId).orElse(null);
        }

        Incident incident = Incident.builder()
                .user(user)
                .emergencyEvent(event)
                .description(request.getDescription())
                .hasAudio(request.getHasAudio() != null ? request.getHasAudio() : false)
                .hasPhoto(request.getHasPhoto() != null ? request.getHasPhoto() : false)
                .localFileUri(request.getLocalFileUri())
                .isEncrypted(true)
                .build();

        return incidentRepository.save(incident);
    }

    @Transactional
    public void deleteIncident(Long userId, Long incidentId, String password) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (password == null || password.isBlank() || !passwordEncoder.matches(password, user.getPasswordHash())) {
            throw new IllegalArgumentException("Incorrect password. Deletion unauthorized.");
        }

        Incident incident = incidentRepository.findById(incidentId)
                .orElseThrow(() -> new ResourceNotFoundException("Incident record not found"));

        if (!incident.getUser().getId().equals(userId)) {
            throw new IllegalArgumentException("Unauthorized to delete this incident record");
        }

        incidentRepository.delete(incident);
    }
}
