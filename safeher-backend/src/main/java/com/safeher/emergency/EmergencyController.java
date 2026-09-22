package com.safeher.emergency;

import com.safeher.common.ApiResponse;
import com.safeher.emergency.dto.EmergencyCancelRequest;
import com.safeher.emergency.dto.EmergencyStartRequest;
import com.safeher.user.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/emergency")
@RequiredArgsConstructor
public class EmergencyController {

    private final EmergencyService emergencyService;

    @PostMapping("/start")
    public ResponseEntity<ApiResponse<EmergencyEvent>> startEmergency(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody EmergencyStartRequest request) {
        EmergencyEvent event = emergencyService.startEmergency(user.getId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(event, "Emergency alert activated successfully"));
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<EmergencyEvent>> cancelEmergency(
            @AuthenticationPrincipal User user,
            @PathVariable Long id,
            @RequestBody(required = false) EmergencyCancelRequest request) {
        EmergencyEvent event = emergencyService.cancelEmergency(user.getId(), id, request);
        return ResponseEntity.ok(ApiResponse.ok(event, "Emergency alert cancelled and closed"));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<EmergencyEvent>> getEmergencyStatus(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        EmergencyEvent event = emergencyService.getEmergencyStatus(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(event, "Emergency status retrieved"));
    }
}
