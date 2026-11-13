package com.safeher.outbox.repository;

import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.model.SmsOutboxStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Repository
public interface SmsOutboxRepository extends JpaRepository<SmsOutbox, Long> {

    Optional<SmsOutbox> findByCorrelationId(String correlationId);

    Optional<SmsOutbox> findByProviderRef(String providerRef);

    List<SmsOutbox> findByStatus(SmsOutboxStatus status);

    /**
     * Claims pending CREATED outbox records for dispatching using row-level locking.
     * Uses PostgreSQL FOR UPDATE SKIP LOCKED to prevent race conditions across concurrent workers.
     */
    @Query(value = "SELECT * FROM sms_outbox WHERE status = 'CREATED' ORDER BY id ASC LIMIT :limit FOR UPDATE SKIP LOCKED", nativeQuery = true)
    List<SmsOutbox> claimPendingRecordsForUpdate(@Param("limit") int limit);

    /**
     * Claims a single pending CREATED record by ID using FOR UPDATE SKIP LOCKED.
     */
    @Query(value = "SELECT * FROM sms_outbox WHERE id = :id AND status = 'CREATED' FOR UPDATE SKIP LOCKED", nativeQuery = true)
    Optional<SmsOutbox> claimRecordByIdForUpdate(@Param("id") Long id);

    /**
     * Finds records that have been in DISPATCHING status longer than the lease cutoff
     * (indicating a crashed worker or dropped connection).
     */
    @Query("SELECT o FROM SmsOutbox o WHERE o.status = :status AND o.dispatchStartedAt < :cutoff")
    List<SmsOutbox> findAbandonedDispatches(@Param("status") SmsOutboxStatus status, @Param("cutoff") Instant cutoff);

    /**
     * Finds UNCERTAIN records that are eligible for status reconciliation.
     */
    @Query("SELECT o FROM SmsOutbox o WHERE o.status = :status AND o.nextReconcileAt <= :cutoff")
    List<SmsOutbox> findPendingReconciliations(@Param("status") SmsOutboxStatus status, @Param("cutoff") Instant cutoff);
}
