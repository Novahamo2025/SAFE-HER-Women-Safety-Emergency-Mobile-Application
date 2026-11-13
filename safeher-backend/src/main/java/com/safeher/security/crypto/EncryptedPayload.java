package com.safeher.security.crypto;

import java.util.Objects;

/**
 * Immutable value object representing an AES-256-GCM encrypted payload,
 * matching the Flyway V6 sms_outbox table columns.
 *
 * @param keyVersion       The version of the encryption key used (V6 column: key_version).
 * @param encryptedPayload Base64-encoded ciphertext (V6 column: encrypted_payload).
 * @param payloadNonce     Base64-encoded 96-bit (12-byte) initialization vector (V6 column: payload_nonce).
 * @param payloadTag       Base64-encoded 128-bit (16-byte) GCM authentication tag (V6 column: payload_tag).
 */
public record EncryptedPayload(
        String keyVersion,
        String encryptedPayload,
        String payloadNonce,
        String payloadTag
) {
    public EncryptedPayload {
        Objects.requireNonNull(keyVersion, "keyVersion cannot be null");
        Objects.requireNonNull(encryptedPayload, "encryptedPayload cannot be null");
        Objects.requireNonNull(payloadNonce, "payloadNonce cannot be null");
        Objects.requireNonNull(payloadTag, "payloadTag cannot be null");
    }

    @Override
    public String toString() {
        // Redact ciphertext and sensitive material from standard toString to prevent accidental logging
        return "EncryptedPayload[keyVersion=" + keyVersion
                + ", encryptedPayload=[REDACTED " + (encryptedPayload != null ? encryptedPayload.length() : 0) + " chars]"
                + ", payloadNonce=[REDACTED]"
                + ", payloadTag=[REDACTED]]";
    }
}
