package com.safeher.checkin.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.Instant;

@Data
public class CheckInCreateRequest {

    @NotNull(message = "Scheduled time is required")
    private Instant scheduledTime;

    private Integer gracePeriodMinutes = 5;
}
