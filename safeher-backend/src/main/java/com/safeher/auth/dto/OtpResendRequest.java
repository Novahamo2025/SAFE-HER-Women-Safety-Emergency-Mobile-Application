package com.safeher.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request DTO for requesting an OTP resend.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OtpResendRequest {

    @NotBlank(message = "Please enter your mobile number.")
    @Pattern(regexp = "^(\\+91|91|0)?[6-9]\\d{9}$", message = "Please enter a valid 10-digit mobile number.")
    private String phone;
}
