package com.safeher.outbox.provider;

/**
 * Interface defining the boundary for outbound SMS telecom provider integration.
 */
public interface SmsProviderClient {

    /**
     * Dispatches an SMS payload to the specified recipient phone number.
     *
     * @param phone Recipient phone number (E.164 format, e.g. +919876543210).
     * @param plaintextPayload Plaintext message to send.
     * @param correlationId Unique correlation ID for tracking and idempotency.
     * @return SmsDispatchResult indicating ACCEPTED, REJECTED, or UNCERTAIN.
     */
    SmsDispatchResult sendSms(String phone, String plaintextPayload, String correlationId);
}
