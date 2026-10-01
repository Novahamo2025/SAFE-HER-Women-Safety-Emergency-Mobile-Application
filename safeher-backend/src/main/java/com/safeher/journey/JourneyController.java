package com.safeher.journey;

import com.safeher.common.ApiResponse;
import com.safeher.journey.dto.JourneyCreateRequest;
import com.safeher.user.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/journeys")
@RequiredArgsConstructor
public class JourneyController {

    private final JourneyService journeyService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<SafeJourney>>> listJourneys(@AuthenticationPrincipal User user) {
        List<SafeJourney> journeys = journeyService.getUserJourneys(user.getId());
        return ResponseEntity.ok(ApiResponse.ok(journeys, "Journeys retrieved"));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<SafeJourney>> createJourney(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody JourneyCreateRequest request) {
        SafeJourney journey = journeyService.createJourney(user.getId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(journey, "Safe journey initiated"));
    }

    @PostMapping("/{id}/check-in")
    public ResponseEntity<ApiResponse<SafeJourney>> checkInJourney(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        SafeJourney journey = journeyService.checkIn(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(journey, "Safe walk check-in confirmed"));
    }

    @PostMapping("/{id}/complete")
    public ResponseEntity<ApiResponse<SafeJourney>> completeJourney(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        SafeJourney journey = journeyService.completeJourney(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(journey, "Safe journey completed safely"));
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<SafeJourney>> cancelJourney(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        SafeJourney journey = journeyService.cancelJourney(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(journey, "Safe journey cancelled"));
    }
}
