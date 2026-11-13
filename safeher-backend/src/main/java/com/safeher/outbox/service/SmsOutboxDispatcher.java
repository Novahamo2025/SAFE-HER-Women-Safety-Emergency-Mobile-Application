package com.safeher.outbox.service;

import com.safeher.otp.model.OtpVerification;
import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.model.SmsOutboxStatus;
import com.safeher.outbox.provider.SmsDispatchResult;
import com.safeher.outbox.provider.SmsProviderClient;
import com.safeher.outbox.repository.SmsOutboxRepository;
import com.safeher.security.crypto.EncryptedPayload;
import com.safeher.security.crypto.SmsPayloadEncryptionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * High-reliability durable SMS Outbox Dispatcher.
 *
 * Implements:
 * 1. Transactional creation of encrypted outbox records alongside OTP generation.
 * 2. Guaranteed pre-network commitment of DISPATCHING status (Transaction 1).
 * 3. Provider network call execution outside database transactions (Zero lock holding).
 * 4. Separate post-network commitment of provider outcome with logical ciphertext deletion (Transaction 2).
 * 5. Automatic recovery of abandoned/crashed DISPATCHING records into UNCERTAIN state.
 * 6. Hard invariant: UNCERTAIN records are never automatically re-dispatched.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class SmsOutboxDispatcher {

    private final SmsOutboxRepository outboxRepository;
    private final SmsOutboxTransactionService transactionService;
    private final SmsPayloadEncryptionService encryptionService;
    private final SmsProviderClient providerClient;

    @Value("${app.outbox.enabled:true}")
    private boolean outboxEnabled;

    @Value("${app.outbox.batch-size:10}")
    private int batchSize;

    @Value("${app.outbox.lease-duration-seconds:120}")
    private long leaseDurationSeconds;

    /**
     * Creates an encrypted outbox entry in CREATED status.
     * Must be called within the caller's business transaction (e.g. OTP issuance).
     */
    @Transactional
    public SmsOutbox createOutboxEntry(OtpVerification otpVerification, String phone, String plaintextPayload, String correlationId) {
        if (otpVerification == null) {
            throw new IllegalArgumentException("OtpVerification cannot be null");
        }
        if (phone == null || phone.isBlank()) {
            throw new IllegalArgumentException("Phone cannot be null or blank");
        }
        if (plaintextPayload == null || plaintextPayload.isBlank()) {
            throw new IllegalArgumentException("Plaintext payload cannot be null or blank");
        }

        EncryptedPayload encrypted = encryptionService.encrypt(plaintextPayload);
        String cid = (correlationId != null && !correlationId.isBlank()) ? correlationId : UUID.randomUUID().toString();
        Instant now = Instant.now();

        SmsOutbox outbox = SmsOutbox.builder()
                .otpVerification(otpVerification)
                .phone(phone)
                .correlationId(cid)
                .keyVersion(encrypted.keyVersion())
                .encryptedPayload(encrypted.encryptedPayload())
                .payloadNonce(encrypted.payloadNonce())
                .payloadTag(encrypted.payloadTag())
                .status(SmsOutboxStatus.CREATED)
                .retryCount(0)
                .maxRetries(3)
                .nextReconcileAt(now)
                .createdAt(now)
                .updatedAt(now)
                .build();

        SmsOutbox saved = outboxRepository.save(outbox);
        log.info("SMS Outbox entry [{}] created in CREATED status (correlationId: {}, verificationId: {})",
                saved.getId(), cid, otpVerification.getId());
        return saved;
    }

    /**
     * Polls and processes pending outbox records in batches.
     * Scheduled background worker.
     */
    @Scheduled(fixedDelayString = "${app.outbox.poll-interval-ms:5000}")
    public int pollAndDispatch() {
        if (!outboxEnabled) {
            return 0;
        }

        try {
            return dispatchBatch(batchSize);
        } catch (Exception e) {
            log.error("Unhandled error during SMS outbox polling loop: {}", e.getMessage(), e);
            return 0;
        }
    }

    /**
     * Dispatches up to batchSize pending records.
     *
     * Invariant:
     * - Transaction 1 commits DISPATCHING state before any HTTP call.
     * - Network call runs completely outside any DB transaction.
     * - Transaction 2 commits outcome (ACCEPTED / REJECTED / UNCERTAIN).
     */
    public int dispatchBatch(int limit) {
        // Step 1: Claim and commit DISPATCHING status in Transaction 1
        List<SmsOutbox> claimedList = transactionService.claimAndMarkDispatchingBatch(limit);
        if (claimedList.isEmpty()) {
            return 0;
        }

        log.debug("Claimed {} SMS outbox records for dispatch", claimedList.size());

        // Step 2 & 3: Process each record outside DB transaction
        for (SmsOutbox claimed : claimedList) {
            processClaimedRecord(claimed);
        }

        return claimedList.size();
    }

    /**
     * Dispatches a single record by ID immediately (used for low-latency dispatch).
     */
    public boolean dispatchSingle(Long outboxId) {
        Optional<SmsOutbox> claimedOpt = transactionService.claimAndMarkDispatchingSingle(outboxId);
        if (claimedOpt.isEmpty()) {
            log.debug("SMS Outbox record [{}] could not be claimed (already claimed or not CREATED)", outboxId);
            return false;
        }

        processClaimedRecord(claimedOpt.get());
        return true;
    }

    /**
     * Decrypts payload, invokes provider client outside any DB transaction,
     * and persists outcome in Transaction 2.
     */
    private void processClaimedRecord(SmsOutbox record) {
        Long id = record.getId();
        String correlationId = record.getCorrelationId();
        String phone = record.getPhone();

        // 1. Decrypt AES-256-GCM payload
        String plaintextPayload;
        try {
            plaintextPayload = encryptionService.decrypt(
                    record.getKeyVersion(),
                    record.getEncryptedPayload(),
                    record.getPayloadNonce(),
                    record.getPayloadTag()
            );
        } catch (Exception ex) {
            log.error("Failed to decrypt SMS payload for outbox record [{}] (correlationId: {}): {}",
                    id, correlationId, ex.getMessage());
            // Tampered or corrupt payload -> reject permanently to protect system integrity
            transactionService.applyDispatchOutcome(id, SmsDispatchResult.rejected("DECRYPTION_FAILED: " + ex.getMessage()));
            return;
        }

        // 2. Perform Network Call to SMS Provider (NO ACTIVE DB TRANSACTION OR LOCK)
        SmsDispatchResult result;
        try {
            result = providerClient.sendSms(phone, plaintextPayload, correlationId);
            if (result == null) {
                result = SmsDispatchResult.uncertain("Provider client returned null result");
            }
        } catch (Exception ex) {
            log.warn("Network exception during provider call for outbox [{}] (correlationId: {}): {}",
                    id, correlationId, ex.getMessage());
            // Network failure, timeout, or dropped connection -> UNCERTAIN!
            result = SmsDispatchResult.uncertain("NETWORK_FAILURE: " + ex.getMessage());
        }

        // 3. Persist outcome in Transaction 2
        try {
            transactionService.applyDispatchOutcome(id, result);
        } catch (Exception ex) {
            log.error("Failed to persist dispatch outcome for outbox [{}] (correlationId: {}): {}",
                    id, correlationId, ex.getMessage(), ex);
        }
    }

    /**
     * Scheduled recovery worker: Scans for abandoned DISPATCHING records
     * whose lease has expired (worker crashed or network partitioned).
     */
    @Scheduled(fixedDelayString = "${app.outbox.recovery-interval-ms:60000}")
    public int scheduledRecoverAbandonedDispatches() {
        if (!outboxEnabled) {
            return 0;
        }
        return recoverAbandonedDispatches();
    }

    /**
     * Core recovery execution: Finds abandoned records in DISPATCHING status older than the lease cutoff
     * and transitions them to UNCERTAIN state.
     *
     * HARD INVARIANT: UNCERTAIN records are NEVER re-dispatched automatically.
     */
    public int recoverAbandonedDispatches() {
        Instant cutoff = Instant.now().minus(Duration.ofSeconds(leaseDurationSeconds));
        List<SmsOutbox> abandoned = outboxRepository.findAbandonedDispatches(SmsOutboxStatus.DISPATCHING, cutoff);
        if (abandoned.isEmpty()) {
            return 0;
        }

        log.warn("CRASH RECOVERY: Found {} abandoned SMS outbox records stuck in DISPATCHING older than {}s",
                abandoned.size(), leaseDurationSeconds);

        int recoveredCount = 0;
        for (SmsOutbox record : abandoned) {
            boolean recovered = transactionService.markAbandonedAsUncertain(record.getId());
            if (recovered) {
                recoveredCount++;
            }
        }

        log.info("CRASH RECOVERY completed: {} records transitioned from DISPATCHING to UNCERTAIN", recoveredCount);
        return recoveredCount;
    }
}
