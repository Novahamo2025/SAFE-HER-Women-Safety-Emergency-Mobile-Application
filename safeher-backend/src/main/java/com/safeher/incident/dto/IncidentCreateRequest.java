package com.safeher.incident.dto;

import lombok.Data;

@Data
public class IncidentCreateRequest {
    private Long emergencyEventId;
    private String description;
    private Boolean hasAudio = false;
    private Boolean hasPhoto = false;
    private String localFileUri;
}
