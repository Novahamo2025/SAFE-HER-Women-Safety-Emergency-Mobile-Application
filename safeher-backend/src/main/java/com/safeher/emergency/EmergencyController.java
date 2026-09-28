package com.safeher.emergency;

import com.safeher.common.ApiResponse;
import com.safeher.emergency.dto.EmergencyCancelRequest;
import com.safeher.emergency.dto.EmergencyEventResponse;
import com.safeher.emergency.dto.EmergencyStartRequest;
import com.safeher.emergency.dto.LocationUpdateRequest;
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
    public ResponseEntity<ApiResponse<EmergencyEventResponse>> startEmergency(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody EmergencyStartRequest request) {
        EmergencyEventResponse response = emergencyService.startEmergency(user.getId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(response, "Emergency alert activated successfully"));
    }

    @PostMapping("/{id}/location")
    public ResponseEntity<ApiResponse<Void>> updateLocation(
            @AuthenticationPrincipal User user,
            @PathVariable Long id,
            @Valid @RequestBody LocationUpdateRequest request) {
        emergencyService.updateLocation(user.getId(), id, request);
        return ResponseEntity.ok(ApiResponse.ok(null, "Location updated successfully"));
    }

    @PostMapping("/{id}/cancel")
    public ResponseEntity<ApiResponse<EmergencyEventResponse>> cancelEmergency(
            @AuthenticationPrincipal User user,
            @PathVariable Long id,
            @RequestBody(required = false) EmergencyCancelRequest request) {
        EmergencyEventResponse response = emergencyService.cancelEmergency(user.getId(), id, request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Emergency alert cancelled and closed"));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ApiResponse<EmergencyEventResponse>> getEmergencyStatus(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        EmergencyEventResponse response = emergencyService.getEmergencyStatus(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(response, "Emergency status retrieved"));
    }
}
