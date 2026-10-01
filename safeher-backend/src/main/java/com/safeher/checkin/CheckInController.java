package com.safeher.checkin;

import com.safeher.checkin.dto.CheckInCreateRequest;
import com.safeher.common.ApiResponse;
import com.safeher.user.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/checkins")
@RequiredArgsConstructor
public class CheckInController {

    private final CheckInService checkInService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<CheckIn>>> listCheckIns(@AuthenticationPrincipal User user) {
        List<CheckIn> checkIns = checkInService.getUserCheckIns(user.getId());
        return ResponseEntity.ok(ApiResponse.ok(checkIns, "Check-ins retrieved"));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<CheckIn>> createCheckIn(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody CheckInCreateRequest request) {
        CheckIn checkIn = checkInService.createCheckIn(user.getId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(checkIn, "Check-in scheduled"));
    }

    @PostMapping("/{id}/complete")
    public ResponseEntity<ApiResponse<CheckIn>> completeCheckIn(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        CheckIn checkIn = checkInService.completeCheckIn(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(checkIn, "Safety check-in confirmed"));
    }

    @PostMapping("/{id}/missed")
    public ResponseEntity<ApiResponse<CheckIn>> markMissed(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        CheckIn checkIn = checkInService.markMissed(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(checkIn, "Check-in marked missed"));
    }

    @PostMapping("/{id}/escalate")
    public ResponseEntity<ApiResponse<CheckIn>> escalate(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        CheckIn checkIn = checkInService.escalate(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(checkIn, "Check-in escalated"));
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<CheckIn>> cancel(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        CheckIn checkIn = checkInService.cancel(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(checkIn, "Check-in cancelled"));
    }
}
