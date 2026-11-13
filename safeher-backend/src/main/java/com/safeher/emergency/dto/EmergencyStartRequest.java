package com.safeher.emergency.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;

@Data
public class EmergencyStartRequest {

    private String eventType = "SOS"; // SOS, SAFE_WALK, CHECKIN

    @NotNull(message = "Latitude is required")
    private BigDecimal latitude;

    @NotNull(message = "Longitude is required")
    private BigDecimal longitude;

    private BigDecimal accuracyMeters;

    private String clientEventUuid;

    private String idempotencyKey;

    public String getEffectiveIdempotencyKey() {
        if (idempotencyKey != null && !idempotencyKey.isBlank()) {
            return idempotencyKey;
        }
        return clientEventUuid;
    }
}
