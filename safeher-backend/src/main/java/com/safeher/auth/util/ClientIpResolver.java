package com.safeher.auth.util;

import jakarta.servlet.http.HttpServletRequest;

/**
 * Utility for extracting the real client IP address from standard HTTP proxy headers.
 */
public final class ClientIpResolver {

    private ClientIpResolver() {
    }

    public static String getClientIp(HttpServletRequest request) {
        if (request == null) {
            return "UNKNOWN";
        }

        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isBlank()) {
            // Take the first comma-separated client IP
            return xForwardedFor.split(",")[0].trim();
        }

        String xRealIp = request.getHeader("X-Real-IP");
        if (xRealIp != null && !xRealIp.isBlank()) {
            return xRealIp.trim();
        }

        String remoteAddr = request.getRemoteAddr();
        return (remoteAddr != null && !remoteAddr.isBlank()) ? remoteAddr : "UNKNOWN";
    }
}
