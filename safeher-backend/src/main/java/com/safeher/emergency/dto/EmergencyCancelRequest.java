package com.safeher.emergency.dto;

import lombok.Data;

@Data
public class EmergencyCancelRequest {
    private String reason;
    private String pin;
}
