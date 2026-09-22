package com.safeher.journey;

import com.safeher.common.ResourceNotFoundException;
import com.safeher.journey.dto.JourneyCreateRequest;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
public class JourneyService {

    private final JourneyRepository journeyRepository;
    private final UserRepository userRepository;

    public List<SafeJourney> getUserJourneys(Long userId) {
        return journeyRepository.findByUserIdOrderByStartedAtDesc(userId);
    }

    @Transactional
    public SafeJourney createJourney(Long userId, JourneyCreateRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        SafeJourney journey = SafeJourney.builder()
                .user(user)
                .destination(request.getDestination())
                .startLat(request.getStartLat())
                .startLng(request.getStartLng())
                .destLat(request.getDestLat())
                .destLng(request.getDestLng())
                .expectedArrival(request.getExpectedArrival())
                .gracePeriodMinutes(request.getGracePeriodMinutes() != null ? request.getGracePeriodMinutes() : 5)
                .status("ACTIVE")
                .build();

        return journeyRepository.save(journey);
    }

    @Transactional
    public SafeJourney completeJourney(Long userId, Long journeyId) {
        SafeJourney journey = journeyRepository.findByIdAndUserId(journeyId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Journey not found"));

        journey.setStatus("COMPLETED");
        journey.setCompletedAt(Instant.now());
        return journeyRepository.save(journey);
    }

    @Transactional
    public SafeJourney checkIn(Long userId, Long journeyId) {
        SafeJourney journey = journeyRepository.findByIdAndUserId(journeyId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Journey not found"));

        // Periodic check-in during safe walk confirms user is fine
        return journey;
    }
}
