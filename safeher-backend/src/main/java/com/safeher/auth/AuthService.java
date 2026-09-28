package com.safeher.auth;

import com.safeher.auth.dto.AuthResponse;
import com.safeher.auth.dto.LoginRequest;
import com.safeher.auth.dto.RegisterRequest;
import com.safeher.security.JwtTokenProvider;
import com.safeher.security.RefreshToken;
import com.safeher.security.RefreshTokenRepository;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.util.HexFormat;

@Service
@Slf4j
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final RefreshTokenRepository refreshTokenRepository;

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        String normalizedEmail = request.getEmail().toLowerCase().trim();
        String normalizedPhone = normalizePhone(request.getPhone().trim());

        // Application-level duplicate check (DB constraint is the final guard)
        if (userRepository.existsByEmailIgnoreCase(normalizedEmail)) {
            throw new IllegalArgumentException("Email is already registered");
        }
        if (userRepository.existsByPhone(normalizedPhone)) {
            throw new IllegalArgumentException("Phone number is already registered");
        }

        User user = User.builder()
                .name(request.getName().trim())
                .email(normalizedEmail)
                .phone(normalizedPhone)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .pinHash(request.getPin() != null ? passwordEncoder.encode(request.getPin()) : null)
                .role("ROLE_USER")
                .accountStatus("ACTIVE")
                .isVerified(true)
                .build();

        User savedUser = userRepository.save(user);
        log.info("New user registered: id={}", savedUser.getId());

        return generateAuthResponse(savedUser);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        String identifier = request.getIdentifier().trim();
        User user = userRepository.findByEmailIgnoreCase(identifier.toLowerCase())
                .or(() -> userRepository.findByPhone(normalizePhone(identifier)))
                .orElseThrow(() -> new IllegalArgumentException("Invalid credentials"));

        if (!"ACTIVE".equals(user.getAccountStatus())) {
            throw new IllegalArgumentException("Account is not active");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            throw new IllegalArgumentException("Invalid credentials");
        }

        // Update last login timestamp
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        log.info("User logged in: id={}", user.getId());
        return generateAuthResponse(user);
    }

    @Transactional
    public AuthResponse refreshToken(String rawRefreshToken) {
        // Validate the JWT structure
        if (!tokenProvider.validateToken(rawRefreshToken)) {
            throw new IllegalArgumentException("Invalid or expired refresh token");
        }

        // Verify it's actually a refresh token (not an access token)
        String tokenType = tokenProvider.getTokenType(rawRefreshToken);
        if (!"refresh".equals(tokenType)) {
            throw new IllegalArgumentException("Invalid token type");
        }

        // Look up the token hash in DB
        String tokenHash = hashToken(rawRefreshToken);
        RefreshToken storedToken = refreshTokenRepository.findByTokenHash(tokenHash)
                .orElseThrow(() -> new IllegalArgumentException("Refresh token not recognized"));

        // Check if revoked
        if (storedToken.isRevoked()) {
            // Potential token theft — revoke ALL tokens for this user
            refreshTokenRepository.revokeAllByUserId(storedToken.getUserId(), Instant.now());
            log.warn("Revoked refresh token reuse detected for user {}. All sessions revoked.", storedToken.getUserId());
            throw new IllegalArgumentException("Session has been revoked. Please log in again.");
        }

        if (storedToken.isExpired()) {
            throw new IllegalArgumentException("Refresh token has expired. Please log in again.");
        }

        // Revoke old token (rotation)
        storedToken.setRevokedAt(Instant.now());
        refreshTokenRepository.save(storedToken);

        // Issue new tokens
        User user = userRepository.findById(storedToken.getUserId())
                .orElseThrow(() -> new IllegalArgumentException("User not found"));

        if (!"ACTIVE".equals(user.getAccountStatus())) {
            throw new IllegalArgumentException("Account is not active");
        }

        log.info("Token refreshed for user: id={}", user.getId());
        return generateAuthResponse(user);
    }

    @Transactional
    public void logout(String rawRefreshToken) {
        if (rawRefreshToken == null || rawRefreshToken.isBlank()) {
            return; // Graceful no-op
        }

        String tokenHash = hashToken(rawRefreshToken);
        refreshTokenRepository.findByTokenHash(tokenHash).ifPresent(token -> {
            token.setRevokedAt(Instant.now());
            refreshTokenRepository.save(token);
            log.info("User logged out: userId={}", token.getUserId());
        });
    }

    // --- Private helpers ---

    private AuthResponse generateAuthResponse(User user) {
        String accessToken = tokenProvider.generateAccessToken(user.getId(), user.getEmail(), user.getRole());
        String refreshToken = tokenProvider.generateRefreshToken(user.getId());

        // Persist refresh token hash
        RefreshToken tokenRecord = RefreshToken.builder()
                .userId(user.getId())
                .tokenHash(hashToken(refreshToken))
                .expiresAt(Instant.now().plusMillis(tokenProvider.getRefreshTokenExpirationMs()))
                .build();
        refreshTokenRepository.save(tokenRecord);

        return AuthResponse.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .tokenType("Bearer")
                .userId(user.getId())
                .name(user.getName())
                .email(user.getEmail())
                .phone(user.getPhone())
                .role(user.getRole())
                .build();
    }

    private String normalizePhone(String phone) {
        if (phone == null) return null;
        // Remove all whitespace and dashes
        String cleaned = phone.replaceAll("[\\s\\-()]", "");
        // Ensure Indian numbers get +91 prefix if 10 digits
        if (cleaned.matches("^[6-9]\\d{9}$")) {
            cleaned = "+91" + cleaned;
        }
        return cleaned;
    }

    private String hashToken(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawToken.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not available", e);
        }
    }
}
