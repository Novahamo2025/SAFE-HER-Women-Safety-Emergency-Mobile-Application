package com.safeher.incident;

import com.safeher.common.ApiResponse;
import com.safeher.incident.dto.IncidentCreateRequest;
import com.safeher.user.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/incidents")
@RequiredArgsConstructor
public class IncidentController {

    private final IncidentService incidentService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<Incident>>> listIncidents(@AuthenticationPrincipal User user) {
        List<Incident> incidents = incidentService.getUserIncidents(user.getId());
        return ResponseEntity.ok(ApiResponse.ok(incidents, "Incidents retrieved"));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<Incident>> createIncident(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody IncidentCreateRequest request) {
        Incident incident = incidentService.createIncident(user.getId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(incident, "Incident record stored securely"));
    }
}
