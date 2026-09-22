package com.safeher.journey.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.math.BigDecimal;
import java.time.Instant;

@Data
public class JourneyCreateRequest {

    @NotBlank(message = "Destination is required")
    private String destination;

    private BigDecimal startLat;
    private BigDecimal startLng;
    private BigDecimal destLat;
    private BigDecimal destLng;

    @NotNull(message = "Expected arrival time is required")
    private Instant expectedArrival;

    private Integer gracePeriodMinutes = 5;
}
