package com.safeher.auth.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Public response DTO for OTP dispatch and resend requests.
 *
 * Security Notice:
 * Never exposes plaintext OTPs, internal cryptographic hashes, salts, or encryption parameters.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OtpResponseDto {

    private String status;
    private String phoneMasked;
    private Integer cooldownSeconds;
    private Integer expiresInSeconds;
    private String dispatchStatus;
    private String message;
}
