package com.safeher.outbox.model;

/**
 * Lifecycle statuses for an SMS outbox record.
 * Matches Flyway V6 check constraint: chk_sms_outbox_status.
 */
public enum SmsOutboxStatus {
    CREATED,
    DISPATCHING,
    ACCEPTED,
    UNCERTAIN,
    REJECTED,
    SUPERSEDED,
    RESOLVED
}
