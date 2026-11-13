package com.safeher.otp.exception;

/**
 * Thrown when an OTP request violates the mandatory resend cooldown window (45 seconds).
 */
public class OtpCooldownException extends IllegalArgumentException {

    private final long retryAfterSeconds;

    public OtpCooldownException(String message, long retryAfterSeconds) {
        super(message);
        this.retryAfterSeconds = retryAfterSeconds;
    }

    public long getRetryAfterSeconds() {
        return retryAfterSeconds;
    }
}
