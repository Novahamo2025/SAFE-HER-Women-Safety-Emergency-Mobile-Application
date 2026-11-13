package com.safeher.otp.exception;

/**
 * Thrown when an OTP request or verification exceeds configured sliding-window rate limits.
 */
public class OtpRateLimitException extends IllegalArgumentException {

    private final String scope;
    private final int limit;
    private final String window;

    public OtpRateLimitException(String message, String scope, int limit, String window) {
        super(message);
        this.scope = scope;
        this.limit = limit;
        this.window = window;
    }

    public String getScope() {
        return scope;
    }

    public int getLimit() {
        return limit;
    }

    public String getWindow() {
        return window;
    }
}
