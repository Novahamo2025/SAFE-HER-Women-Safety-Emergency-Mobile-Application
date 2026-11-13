package com.safeher.emergency.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmergencyEventResponse {
    private Long id;
    private String eventType;
    private String status;
    private String clientEventUuid;
    private String idempotencyKey;
    private Instant startedAt;
    private Instant endedAt;
    private Instant updatedAt;
    private String cancellationReason;
}
