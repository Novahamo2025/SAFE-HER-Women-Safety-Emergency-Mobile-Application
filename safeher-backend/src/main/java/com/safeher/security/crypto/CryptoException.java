package com.safeher.security.crypto;

/**
 * Unchecked exception thrown for cryptographic operations failures, such as
 * authentication tag verification failure, key format invalidity, or tampering detection.
 *
 * Exception messages must never include plaintext OTPs, encryption keys, salts, or peppers.
 */
public class CryptoException extends RuntimeException {

    public CryptoException(String message) {
        super(message);
    }

    public CryptoException(String message, Throwable cause) {
        super(message, cause);
    }
}
