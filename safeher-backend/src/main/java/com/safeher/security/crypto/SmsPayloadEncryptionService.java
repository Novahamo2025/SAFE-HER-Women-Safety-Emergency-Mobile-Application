package com.safeher.security.crypto;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Service for authenticated AES-256-GCM encryption and decryption of transient SMS outbox payloads.
 *
 * Requirements:
 * - 96-bit (12-byte) random nonce generated for every single encryption.
 * - 128-bit (16-byte) GCM authentication tag.
 * - Nonce, ciphertext, and tag stored in Base64 encoding matching V6 sms_outbox columns:
 *   payload_nonce (VARCHAR(32)), encrypted_payload (TEXT), payload_tag (VARCHAR(32)).
 * - Detects and rejects modified ciphertext, nonce, or authentication tags via authenticated GCM tag verification.
 * - Supports key-version identification for seamless key rotation.
 * - Never logs plaintext payloads or encryption keys.
 *
 * Note: Setting encrypted_payload to NULL in PostgreSQL represents logical deletion and
 * eliminates application-level access, but does not guarantee immediate physical zeroization
 * of PostgreSQL storage pages or write-ahead logs (WAL).
 */
@Service
@Slf4j
public class SmsPayloadEncryptionService {

    private static final String CIPHER_TRANSFORMATION = "AES/GCM/NoPadding";
    private static final int GCM_TAG_LENGTH_BITS = 128;
    private static final int GCM_TAG_LENGTH_BYTES = 16;
    private static final int NONCE_LENGTH_BYTES = 12; // 96-bit nonce per NIST SP 800-38D

    private final Map<String, SecretKey> keyRegistry = new ConcurrentHashMap<>();
    private final String activeKeyVersion;
    private final SecureRandom secureRandom;

    /**
     * Spring constructor using configured properties.
     */
    @Autowired
    public SmsPayloadEncryptionService(OtpCryptoProperties properties) {
        if (properties == null) {
            throw new IllegalArgumentException("OtpCryptoProperties cannot be null");
        }
        this.activeKeyVersion = properties.getSmsEncryptionKeyVersion();
        SecretKey activeKey = properties.getResolvedEncryptionKey() != null
                ? properties.getResolvedEncryptionKey()
                : OtpCryptoProperties.parseAndCreateAes256Key(properties.getSmsEncryptionKeyV1(), "SMS_ENCRYPTION_KEY_V1");
        this.keyRegistry.put(this.activeKeyVersion, activeKey);
        this.secureRandom = new SecureRandom();
    }

    /**
     * Direct constructor for testing or manual instantiation.
     */
    public SmsPayloadEncryptionService(SecretKey activeKey, String activeKeyVersion) {
        if (activeKey == null) {
            throw new IllegalArgumentException("Active encryption key cannot be null");
        }
        this.activeKeyVersion = activeKeyVersion != null ? activeKeyVersion : "v1";
        this.keyRegistry.put(this.activeKeyVersion, activeKey);
        this.secureRandom = new SecureRandom();
    }

    /**
     * Registers an additional key version to support decrypting in-flight payloads during key rotation.
     */
    public void registerKeyVersion(String version, SecretKey key) {
        if (version == null || version.isBlank() || key == null) {
            throw new IllegalArgumentException("Key version and key cannot be null or blank");
        }
        this.keyRegistry.put(version, key);
    }

    /**
     * Encrypts a plaintext payload using AES-256-GCM with a fresh random 96-bit nonce.
     *
     * @param plaintext The plaintext payload (e.g. OTP verification message).
     * @return EncryptedPayload containing keyVersion, Base64 ciphertext, Base64 nonce, and Base64 tag.
     */
    public EncryptedPayload encrypt(String plaintext) {
        if (plaintext == null) {
            throw new IllegalArgumentException("Plaintext payload cannot be null");
        }

        SecretKey key = keyRegistry.get(activeKeyVersion);
        if (key == null) {
            throw new CryptoException("Active encryption key version '" + activeKeyVersion + "' is not registered.");
        }

        // Generate fresh 96-bit nonce
        byte[] nonce = new byte[NONCE_LENGTH_BYTES];
        secureRandom.nextBytes(nonce);

        try {
            Cipher cipher = Cipher.getInstance(CIPHER_TRANSFORMATION);
            GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH_BITS, nonce);
            cipher.init(Cipher.ENCRYPT_MODE, key, spec);

            byte[] cipherTextWithTag = cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));

            // Java AES/GCM appends the authentication tag to the ciphertext
            int cipherTextLength = cipherTextWithTag.length - GCM_TAG_LENGTH_BYTES;
            byte[] cipherTextBytes = Arrays.copyOfRange(cipherTextWithTag, 0, cipherTextLength);
            byte[] tagBytes = Arrays.copyOfRange(cipherTextWithTag, cipherTextLength, cipherTextWithTag.length);

            String b64Cipher = Base64.getEncoder().encodeToString(cipherTextBytes);
            String b64Nonce = Base64.getEncoder().encodeToString(nonce);
            String b64Tag = Base64.getEncoder().encodeToString(tagBytes);

            return new EncryptedPayload(activeKeyVersion, b64Cipher, b64Nonce, b64Tag);
        } catch (GeneralSecurityException e) {
            throw new CryptoException("AES-256-GCM encryption failed", e);
        }
    }

    /**
     * Decrypts an EncryptedPayload record.
     */
    public String decrypt(EncryptedPayload payload) {
        if (payload == null) {
            throw new IllegalArgumentException("EncryptedPayload cannot be null");
        }
        return decrypt(payload.keyVersion(), payload.encryptedPayload(), payload.payloadNonce(), payload.payloadTag());
    }

    /**
     * Decrypts an encrypted payload using the specified key version, ciphertext, nonce, and tag.
     * Recombines ciphertext and tag and verifies the authenticated GCM tag.
     *
     * @param keyVersion       The version identifier of the key used during encryption.
     * @param encryptedPayload Base64-encoded ciphertext.
     * @param payloadNonce     Base64-encoded 96-bit nonce.
     * @param payloadTag       Base64-encoded 128-bit authentication tag.
     * @return Decrypted plaintext string.
     * @throws CryptoException if authentication tag verification fails, payload is corrupted, or parameters are invalid.
     */
    public String decrypt(String keyVersion, String encryptedPayload, String payloadNonce, String payloadTag) {
        if (keyVersion == null || encryptedPayload == null || payloadNonce == null || payloadTag == null) {
            throw new CryptoException("All payload components (keyVersion, encryptedPayload, payloadNonce, payloadTag) are required for decryption.");
        }

        SecretKey key = keyRegistry.get(keyVersion);
        if (key == null) {
            throw new CryptoException("Unsupported or unregistered encryption key version: " + keyVersion);
        }

        byte[] nonce;
        byte[] tag;
        byte[] cipherText;

        try {
            nonce = Base64.getDecoder().decode(payloadNonce);
            tag = Base64.getDecoder().decode(payloadTag);
            cipherText = Base64.getDecoder().decode(encryptedPayload);
        } catch (IllegalArgumentException e) {
            throw new CryptoException("Malformed Base64 payload component", e);
        }

        if (nonce.length != NONCE_LENGTH_BYTES) {
            throw new CryptoException("Invalid nonce length: expected " + NONCE_LENGTH_BYTES + " bytes, got " + nonce.length);
        }
        if (tag.length != GCM_TAG_LENGTH_BYTES) {
            throw new CryptoException("Invalid tag length: expected " + GCM_TAG_LENGTH_BYTES + " bytes, got " + tag.length);
        }

        // Recombine ciphertext and tag for Java AES/GCM decryption
        byte[] cipherTextWithTag = new byte[cipherText.length + tag.length];
        System.arraycopy(cipherText, 0, cipherTextWithTag, 0, cipherText.length);
        System.arraycopy(tag, 0, cipherTextWithTag, cipherText.length, tag.length);

        try {
            Cipher cipher = Cipher.getInstance(CIPHER_TRANSFORMATION);
            GCMParameterSpec spec = new GCMParameterSpec(GCM_TAG_LENGTH_BITS, nonce);
            cipher.init(Cipher.DECRYPT_MODE, key, spec);

            byte[] plaintextBytes = cipher.doFinal(cipherTextWithTag);
            return new String(plaintextBytes, StandardCharsets.UTF_8);
        } catch (GeneralSecurityException e) {
            // GeneralSecurityException covers AEADBadTagException (tampered ciphertext or tag)
            throw new CryptoException("Decryption failed: authentication tag verification failed or ciphertext tampered with.", e);
        }
    }

    public String getActiveKeyVersion() {
        return activeKeyVersion;
    }
}
