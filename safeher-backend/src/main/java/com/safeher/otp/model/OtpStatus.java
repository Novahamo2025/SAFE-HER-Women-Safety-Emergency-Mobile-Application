package com.safeher.otp.model;

/**
 * Lifecycle statuses for an OTP verification record.
 * Matches Flyway V6 check constraint: chk_otp_status.
 */
public enum OtpStatus {
    PENDING,
    CONSUMED,
    EXPIRED,
    EXCEEDED,
    SUPERSEDED
}
