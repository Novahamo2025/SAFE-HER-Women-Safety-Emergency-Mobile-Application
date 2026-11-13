package com.safeher.auth;

import com.safeher.auth.dto.AccountDeleteRequest;
import com.safeher.auth.dto.AuthResponse;
import com.safeher.auth.dto.LoginRequest;
import com.safeher.auth.dto.OtpResendRequest;
import com.safeher.auth.dto.OtpResponseDto;
import com.safeher.auth.dto.OtpSendRequest;
import com.safeher.auth.dto.OtpVerifyRequest;
import com.safeher.auth.dto.RefreshTokenRequest;
import com.safeher.auth.dto.RegisterRequest;
import com.safeher.auth.util.ClientIpResolver;
import com.safeher.common.ApiResponse;
import com.safeher.user.User;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    @PostMapping("/otp/send")
    public ResponseEntity<ApiResponse<Map<String, Object>>> sendOtp(
            @Valid @RequestBody OtpSendRequest request,
            HttpServletRequest servletRequest) {
        String clientIp = ClientIpResolver.getClientIp(servletRequest);
        Map<String, Object> result = authService.sendOtp(request, clientIp);
        return ResponseEntity.ok(ApiResponse.ok(result, (String) result.get("message")));
    }

    @PostMapping({"/otp/resend", "/resend-otp"})
    public ResponseEntity<ApiResponse<OtpResponseDto>> resendOtp(
            @Valid @RequestBody OtpResendRequest request,
            HttpServletRequest servletRequest) {
        String clientIp = ClientIpResolver.getClientIp(servletRequest);
        Map<String, Object> result = authService.resendOtp(request.getPhone(), clientIp);
        OtpResponseDto response = OtpResponseDto.builder()
                .status("PENDING_VERIFICATION")
                .phoneMasked((String) result.get("phoneMasked"))
                .cooldownSeconds((Integer) result.get("cooldownSeconds"))
                .expiresInSeconds((Integer) result.get("expiresInSeconds"))
                .dispatchStatus("ACCEPTED")
                .message("A fresh verification code has been dispatched via SMS.")
                .build();
        return ResponseEntity.ok(ApiResponse.ok(response, response.getMessage()));
    }

    @PostMapping({"/otp/verify", "/verify-otp"})
    public ResponseEntity<ApiResponse<AuthResponse>> verifyOtp(
            @Valid @RequestBody OtpVerifyRequest request) {
        AuthResponse response = authService.verifyOtp(request.getPhone(), request.getOtp());
        return ResponseEntity.ok(ApiResponse.ok(response, "Phone verified successfully."));
    }

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<AuthResponse>> register(
            @Valid @RequestBody RegisterRequest request,
            HttpServletRequest servletRequest) {
        String clientIp = ClientIpResolver.getClientIp(servletRequest);
        AuthResponse response = authService.register(request, clientIp);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(response, "User registered successfully. Please verify your phone number with the OTP sent via SMS."));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<AuthResponse>> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(ApiResponse.ok(response, "Login successful"));
    }

    @PostMapping("/refresh")
    public ResponseEntity<ApiResponse<AuthResponse>> refreshToken(@Valid @RequestBody RefreshTokenRequest request) {
        AuthResponse response = authService.refreshToken(request.getRefreshToken());
        return ResponseEntity.ok(ApiResponse.ok(response, "Token refreshed successfully"));
    }

    @PostMapping("/logout")
    public ResponseEntity<ApiResponse<Void>> logout(@Valid @RequestBody RefreshTokenRequest request) {
        authService.logout(request.getRefreshToken());
        return ResponseEntity.ok(ApiResponse.ok(null, "Logged out successfully"));
    }

    @PostMapping("/verify-password")
    public ResponseEntity<ApiResponse<Boolean>> verifyPassword(
            @AuthenticationPrincipal User user,
            @RequestBody Map<String, String> request) {
        String password = request != null ? request.get("password") : null;
        if (password == null || password.isBlank()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(ApiResponse.error("Password is required"));
        }

        boolean valid = false;
        if (user != null) {
            valid = authService.verifyPassword(user.getId(), password);
        } else if (request != null && request.containsKey("identifier")) {
            valid = authService.verifyPasswordByIdentifier(request.get("identifier"), password);
        } else {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Authentication required to verify password"));
        }

        if (!valid) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Incorrect password"));
        }

        return ResponseEntity.ok(ApiResponse.ok(true, "Password verified successfully"));
    }

    @DeleteMapping("/account")
    public ResponseEntity<ApiResponse<Void>> deleteAccount(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody AccountDeleteRequest request) {
        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(ApiResponse.error("Authentication required to delete account"));
        }

        authService.deleteAccount(user.getId(), request.getPassword());
        return ResponseEntity.ok(ApiResponse.ok(null, "Account permanently deleted"));
    }
}

