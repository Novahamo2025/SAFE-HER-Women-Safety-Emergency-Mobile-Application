package com.safeher.outbox.service;

import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.model.SmsOutboxStatus;
import com.safeher.outbox.provider.SmsDispatchResult;
import com.safeher.outbox.repository.SmsOutboxRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Service encapsulating strict transaction boundaries for SMS Outbox operations.
 *
 * Enforces key transactional invariants:
 * 1. DISPATCHING state is durably persisted and committed BEFORE any provider network call begins.
 * 2. Provider outcomes (ACCEPTED, REJECTED, UNCERTAIN) are committed in separate transactions.
 * 3. Logical deletion of ciphertext (setting encrypted_payload, nonce, tag to null) occurs on ACCEPTED.
 * 4. UNCERTAIN state is committed and NEVER reset to CREATED/DISPATCHING for automatic re-dispatch.
 */
@Service
@Slf4j
@RequiredArgsConstructor
public class SmsOutboxTransactionService {

    private final SmsOutboxRepository outboxRepository;

    /**
     * Claims a batch of CREATED records, transitions them to DISPATCHING,
     * updates retry_count and dispatch_started_at, and COMMITS the transaction.
     *
     * Uses row-level FOR UPDATE SKIP LOCKED to prevent concurrent workers from claiming the same rows.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public List<SmsOutbox> claimAndMarkDispatchingBatch(int limit) {
        List<SmsOutbox> pending = outboxRepository.claimPendingRecordsForUpdate(limit);
        if (pending.isEmpty()) {
            return List.of();
        }

        Instant now = Instant.now();
        List<SmsOutbox> claimed = new ArrayList<>(pending.size());

        for (SmsOutbox outbox : pending) {
            outbox.setStatus(SmsOutboxStatus.DISPATCHING);
            outbox.setDispatchStartedAt(now);
            outbox.setRetryCount(outbox.getRetryCount() + 1);
            outbox.setUpdatedAt(now);
            claimed.add(outbox);
            log.info("SMS Outbox [{}] claimed and transitioned to DISPATCHING (correlationId: {}, attempt: {})",
                    outbox.getId(), outbox.getCorrelationId(), outbox.getRetryCount());
        }

        return outboxRepository.saveAll(claimed);
    }

    /**
     * Claims a single CREATED record by ID, transitions it to DISPATCHING, and COMMITS.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Optional<SmsOutbox> claimAndMarkDispatchingSingle(Long id) {
        Optional<SmsOutbox> optional = outboxRepository.claimRecordByIdForUpdate(id);
        if (optional.isEmpty()) {
            return Optional.empty();
        }

        SmsOutbox outbox = optional.get();
        Instant now = Instant.now();
        outbox.setStatus(SmsOutboxStatus.DISPATCHING);
        outbox.setDispatchStartedAt(now);
        outbox.setRetryCount(outbox.getRetryCount() + 1);
        outbox.setUpdatedAt(now);

        SmsOutbox saved = outboxRepository.save(outbox);
        log.info("SMS Outbox [{}] claimed single and transitioned to DISPATCHING (correlationId: {}, attempt: {})",
                saved.getId(), saved.getCorrelationId(), saved.getRetryCount());
        return Optional.of(saved);
    }

    /**
     * Records the provider dispatch outcome in a fresh, isolated transaction.
     *
     * - ACCEPTED: Sets provider_ref, clears encrypted_payload/nonce/tag (logical deletion), status = ACCEPTED.
     * - REJECTED: Sets status = REJECTED.
     * - UNCERTAIN: Sets status = UNCERTAIN, schedules next_reconcile_at. INVARIANT: Never auto-resends.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public SmsOutbox applyDispatchOutcome(Long id, SmsDispatchResult result) {
        SmsOutbox outbox = outboxRepository.findById(id)
                .orElseThrow(() -> new IllegalStateException("SMS Outbox record not found for id: " + id));

        Instant now = Instant.now();
        outbox.setUpdatedAt(now);

        switch (result.outcome()) {
            case ACCEPTED -> {
                outbox.setStatus(SmsOutboxStatus.ACCEPTED);
                outbox.setProviderRef(result.providerRef());
                // Logical deletion of sensitive encrypted payload
                outbox.clearCiphertext();
                log.info("SMS Outbox [{}] transitioned to ACCEPTED with providerRef: [{}]. Payload logically deleted.",
                        id, result.providerRef());
            }
            case REJECTED -> {
                outbox.setStatus(SmsOutboxStatus.REJECTED);
                log.warn("SMS Outbox [{}] transitioned to REJECTED. Reason: {}", id, result.errorMessage());
            }
            case UNCERTAIN -> {
                outbox.setStatus(SmsOutboxStatus.UNCERTAIN);
                Instant nextReconcile = calculateNextReconcileAt(now, outbox.getRetryCount());
                outbox.setNextReconcileAt(nextReconcile);
                log.warn("SMS Outbox [{}] transitioned to UNCERTAIN. Reason: {}. Next reconcile scheduled at: {}. (Auto-resend is disabled)",
                        id, result.errorMessage(), nextReconcile);
            }
        }

        return outboxRepository.save(outbox);
    }

    /**
     * Crash recovery: Transitions an abandoned DISPATCHING record to UNCERTAIN.
     * Called when a worker crashed or network connection dropped during dispatch.
     *
     * INVARIANT: Never resets to CREATED or DISPATCHING.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean markAbandonedAsUncertain(Long id) {
        Optional<SmsOutbox> optional = outboxRepository.findById(id);
        if (optional.isEmpty()) {
            return false;
        }

        SmsOutbox outbox = optional.get();
        if (outbox.getStatus() != SmsOutboxStatus.DISPATCHING) {
            log.debug("SMS Outbox [{}] is no longer in DISPATCHING status (current: {}), skipping crash recovery.",
                    id, outbox.getStatus());
            return false;
        }

        Instant now = Instant.now();
        outbox.setStatus(SmsOutboxStatus.UNCERTAIN);
        outbox.setNextReconcileAt(calculateNextReconcileAt(now, outbox.getRetryCount()));
        outbox.setUpdatedAt(now);
        outboxRepository.save(outbox);

        log.warn("CRASH RECOVERY: SMS Outbox [{}] (correlationId: {}) was abandoned in DISPATCHING. Transitioned to UNCERTAIN.",
                id, outbox.getCorrelationId());
        return true;
    }

    /**
     * Calculates exponential backoff for next status reconciliation attempt.
     */
    public static Instant calculateNextReconcileAt(Instant baseTime, int retryCount) {
        long minutesToAdd = switch (retryCount) {
            case 0, 1 -> 2;
            case 2 -> 5;
            default -> 15;
        };
        return baseTime.plus(Duration.ofMinutes(minutesToAdd));
    }
}
