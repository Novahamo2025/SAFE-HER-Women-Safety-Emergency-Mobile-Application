package com.safeher.location;

import com.safeher.common.ApiResponse;
import com.safeher.location.dto.LocationSubmitRequest;
import com.safeher.user.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/emergency/{id}/location/submit")
@RequiredArgsConstructor
public class LocationController {

    private final LocationService locationService;

    @PostMapping
    public ResponseEntity<ApiResponse<LocationUpdate>> submitLocation(
            @AuthenticationPrincipal User user,
            @PathVariable Long id,
            @Valid @RequestBody LocationSubmitRequest request) {
        LocationUpdate update = locationService.submitLocation(user.getId(), id, request);
        return ResponseEntity.ok(ApiResponse.ok(update, "Location update saved"));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<List<LocationUpdate>>> getLocationHistory(
            @PathVariable Long id) {
        List<LocationUpdate> history = locationService.getLocationHistory(id);
        return ResponseEntity.ok(ApiResponse.ok(history, "Location history retrieved"));
    }
}
