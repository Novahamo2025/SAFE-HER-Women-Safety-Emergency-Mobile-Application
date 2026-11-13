package com.safeher.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for verifying a 6-digit numeric OTP code.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OtpVerifyRequest {

    @NotBlank(message = "Please enter your mobile number.")
    @Pattern(regexp = "^(\\+91|91|0)?[6-9]\\d{9}$", message = "Please enter a valid 10-digit mobile number.")
    private String phone;

    @NotBlank(message = "Please enter the 6-digit verification code.")
    @Pattern(regexp = "^\\d{6}$", message = "Verification code must be exactly 6 numeric digits.")
    private String otp;
}
