package com.safeher.outbox.service;

import com.safeher.otp.model.OtpStatus;
import com.safeher.otp.model.OtpVerification;
import com.safeher.otp.repository.OtpVerificationRepository;
import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.model.SmsOutboxStatus;
import com.safeher.outbox.provider.MockSmsProviderClient;
import com.safeher.outbox.provider.SmsDispatchResult;
import com.safeher.outbox.repository.SmsOutboxRepository;
import com.safeher.security.crypto.EncryptedPayload;
import com.safeher.security.crypto.SmsPayloadEncryptionService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
class SmsOutboxDispatcherTest {

    @Autowired
    private SmsOutboxDispatcher dispatcher;

    @Autowired
    private SmsOutboxTransactionService transactionService;

    @Autowired
    private SmsOutboxRepository outboxRepository;

    @Autowired
    private OtpVerificationRepository otpVerificationRepository;

    @Autowired
    private SmsPayloadEncryptionService encryptionService;

    @Autowired
    private MockSmsProviderClient mockSmsProviderClient;

    private OtpVerification testOtpVerification;

    @BeforeEach
    void setUp() {
        mockSmsProviderClient.reset();
        outboxRepository.deleteAll();
        otpVerificationRepository.deleteAll();

        testOtpVerification = OtpVerification.builder()
                .phone("+919876543210")
                .purpose("REGISTRATION")
                .otpHash("a".repeat(64))
                .salt("b".repeat(32))
                .pepperVersion("v1")
                .status(OtpStatus.PENDING)
                .attemptsCount(0)
                .maxAttempts(3)
                .expiresAt(Instant.now().plus(10, ChronoUnit.MINUTES))
                .build();
        testOtpVerification = otpVerificationRepository.save(testOtpVerification);
    }

    @AfterEach
    void tearDown() {
        mockSmsProviderClient.reset();
        outboxRepository.deleteAll();
        otpVerificationRepository.deleteAll();
    }

    @Test
    @DisplayName("1. createOutboxEntry: encrypts payload with AES-256-GCM and persists in CREATED status")
    void testCreateOutboxEntry_encryptsPayloadAndPersistsCreatedStatus() {
        String plaintextOtp = "Your SafeHer OTP is 748291. Valid for 10 minutes.";
        String correlationId = "CORR-" + UUID.randomUUID();

        SmsOutbox outbox = dispatcher.createOutboxEntry(testOtpVerification, "+919876543210", plaintextOtp, correlationId);

        assertThat(outbox.getId()).isNotNull();
        assertThat(outbox.getStatus()).isEqualTo(SmsOutboxStatus.CREATED);
        assertThat(outbox.getCorrelationId()).isEqualTo(correlationId);
        assertThat(outbox.getKeyVersion()).isEqualTo("v1");
        assertThat(outbox.getRetryCount()).isEqualTo(0);

        // Security check: Plaintext OTP is NEVER stored in database columns
        assertThat(outbox.getEncryptedPayload()).doesNotContain("748291");
        assertThat(outbox.getEncryptedPayload()).doesNotContain("SafeHer");
        assertThat(outbox.getPayloadNonce()).isNotNull().isNotBlank();
        assertThat(outbox.getPayloadTag()).isNotNull().isNotBlank();

        // Verify payload can be decrypted back to original plaintext
        String decrypted = encryptionService.decrypt(
                outbox.getKeyVersion(),
                outbox.getEncryptedPayload(),
                outbox.getPayloadNonce(),
                outbox.getPayloadTag()
        );
        assertThat(decrypted).isEqualTo(plaintextOtp);
    }

    @Test
    @DisplayName("2. dispatchBatch ACCEPTED: sets providerRef and logically deletes ciphertext")
    void testDispatchBatch_accepted_logicalDeletionOfCiphertext() {
        String plaintextOtp = "Your SafeHer OTP is 112233";
        String correlationId = "CORR-ACCEPTED-" + UUID.randomUUID();
        SmsOutbox created = dispatcher.createOutboxEntry(testOtpVerification, "+919876543210", plaintextOtp, correlationId);

        mockSmsProviderClient.setDefaultOutcome(SmsDispatchResult.Outcome.ACCEPTED);
        mockSmsProviderClient.setCustomProviderRef("MSG91_REQ_998877");

        int processed = dispatcher.dispatchBatch(10);
        assertThat(processed).isEqualTo(1);

        SmsOutbox updated = outboxRepository.findById(created.getId()).orElseThrow();
        assertThat(updated.getStatus()).isEqualTo(SmsOutboxStatus.ACCEPTED);
        assertThat(updated.getProviderRef()).isEqualTo("MSG91_REQ_998877");
        assertThat(updated.getRetryCount()).isEqualTo(1);

        // Logical deletion assertion: encrypted_payload, nonce, tag are all set to NULL
        assertThat(updated.getEncryptedPayload()).isNull();
        assertThat(updated.getPayloadNonce()).isNull();
        assertThat(updated.getPayloadTag()).isNull();

        // Verify provider actually received the decrypted message
        assertThat(mockSmsProviderClient.getDispatchCount()).isEqualTo(1);
    }

    @Test
    @DisplayName("3. dispatchBatch REJECTED: sets status to REJECTED and preserves audit record")
    void testDispatchBatch_rejected_statusUpdated() {
        String plaintextOtp = "Your SafeHer OTP is 334455";
        SmsOutbox created = dispatcher.createOutboxEntry(testOtpVerification, "+919876543210", plaintextOtp, null);

        mockSmsProviderClient.setDefaultOutcome(SmsDispatchResult.Outcome.REJECTED);

        int processed = dispatcher.dispatchBatch(10);
        assertThat(processed).isEqualTo(1);

        SmsOutbox updated = outboxRepository.findById(created.getId()).orElseThrow();
        assertThat(updated.getStatus()).isEqualTo(SmsOutboxStatus.REJECTED);
        assertThat(updated.getRetryCount()).isEqualTo(1);

        // A REJECTED record must never be picked up again by subsequent dispatch batches
        int secondRun = dispatcher.dispatchBatch(10);
        assertThat(secondRun).isEqualTo(0);
    }

    @Test
    @DisplayName("4. dispatchBatch UNCERTAIN on network timeout: sets UNCERTAIN and NEVER auto-resends")
    void testDispatchBatch_uncertain_networkTimeout_neverAutoResent() {
        String plaintextOtp = "Your SafeHer OTP is 556677";
        SmsOutbox created = dispatcher.createOutboxEntry(testOtpVerification, "+919876543210", plaintextOtp, null);

        // Simulate transport/network timeout
        mockSmsProviderClient.setSimulatedException(new RuntimeException("ConnectTimeoutException: MSG91 gateway unreachable"));

        int processed = dispatcher.dispatchBatch(10);
        assertThat(processed).isEqualTo(1);

        SmsOutbox updated = outboxRepository.findById(created.getId()).orElseThrow();
        assertThat(updated.getStatus()).isEqualTo(SmsOutboxStatus.UNCERTAIN);
        assertThat(updated.getRetryCount()).isEqualTo(1);
        assertThat(updated.getNextReconcileAt()).isAfter(Instant.now());

        // CRITICAL INVARIANT: Dispatcher worker MUST NOT pick up UNCERTAIN records for re-dispatch
        mockSmsProviderClient.setSimulatedException(null);
        mockSmsProviderClient.reset();

        int secondRun = dispatcher.dispatchBatch(10);
        assertThat(secondRun).isEqualTo(0);
        assertThat(mockSmsProviderClient.getDispatchCount()).isEqualTo(0);
    }

    @Test
    @DisplayName("5. recoverAbandonedDispatches: transitions crashed DISPATCHING records to UNCERTAIN")
    void testCrashRecovery_abandonedDispatching_transitionsToUncertain() {
        String plaintextOtp = "Your SafeHer OTP is 998811";
        SmsOutbox outbox = dispatcher.createOutboxEntry(testOtpVerification, "+919876543210", plaintextOtp, null);

        // Simulate a process crash that occurred while the record was in DISPATCHING 5 minutes ago
        outbox.setStatus(SmsOutboxStatus.DISPATCHING);
        outbox.setDispatchStartedAt(Instant.now().minus(5, ChronoUnit.MINUTES));
        outbox.setRetryCount(1);
        outbox = outboxRepository.save(outbox);

        int recovered = dispatcher.recoverAbandonedDispatches();
        assertThat(recovered).isEqualTo(1);

        SmsOutbox recoveredRecord = outboxRepository.findById(outbox.getId()).orElseThrow();
        assertThat(recoveredRecord.getStatus()).isEqualTo(SmsOutboxStatus.UNCERTAIN);
        assertThat(recoveredRecord.getNextReconcileAt()).isAfter(Instant.now());

        // Hard invariant: Recovered UNCERTAIN records are NEVER re-sent by dispatcher
        int dispatchCount = dispatcher.dispatchBatch(10);
        assertThat(dispatchCount).isEqualTo(0);
        assertThat(mockSmsProviderClient.getDispatchCount()).isEqualTo(0);
    }

    @Test
    @DisplayName("6. Decryption failure on tampered ciphertext transitions to REJECTED without calling provider")
    void testDecryptionFailure_tamperedCiphertext_transitionsToRejected() {
        String plaintextOtp = "Your SafeHer OTP is 123987";
        SmsOutbox outbox = dispatcher.createOutboxEntry(testOtpVerification, "+919876543210", plaintextOtp, null);

        // Deliberately tamper with ciphertext
        outbox.setEncryptedPayload("dGFtcGVyZWRfY2lwaGVydGV4dA==");
        outboxRepository.save(outbox);

        int processed = dispatcher.dispatchBatch(10);
        assertThat(processed).isEqualTo(1);

        SmsOutbox updated = outboxRepository.findById(outbox.getId()).orElseThrow();
        assertThat(updated.getStatus()).isEqualTo(SmsOutboxStatus.REJECTED);

        // Security check: Provider was NEVER called with corrupted or invalid payload
        assertThat(mockSmsProviderClient.getDispatchCount()).isEqualTo(0);
    }

    @Test
    @DisplayName("7. Batch claiming respects limit and processes records sequentially without starvation")
    void testBatchClaiming_respectsBatchSize() {
        // Create 5 outbox entries
        for (int i = 1; i <= 5; i++) {
            dispatcher.createOutboxEntry(testOtpVerification, "+919876543210", "OTP-" + i, "CORR-" + i);
        }

        mockSmsProviderClient.setDefaultOutcome(SmsDispatchResult.Outcome.ACCEPTED);

        // First batch claims exactly 3
        int firstBatch = dispatcher.dispatchBatch(3);
        assertThat(firstBatch).isEqualTo(3);

        // Second batch claims remaining 2
        int secondBatch = dispatcher.dispatchBatch(3);
        assertThat(secondBatch).isEqualTo(2);

        // Third batch has 0 left
        int thirdBatch = dispatcher.dispatchBatch(3);
        assertThat(thirdBatch).isEqualTo(0);

        List<SmsOutbox> accepted = outboxRepository.findByStatus(SmsOutboxStatus.ACCEPTED);
        assertThat(accepted).hasSize(5);
    }

    @Test
    @DisplayName("8. dispatchSingle: claims and processes a specific outbox record by ID")
    void testDispatchSingle_processesSpecificRecord() {
        String plaintextOtp = "Your SafeHer OTP is 887766";
        SmsOutbox outbox = dispatcher.createOutboxEntry(testOtpVerification, "+919876543210", plaintextOtp, null);

        mockSmsProviderClient.setDefaultOutcome(SmsDispatchResult.Outcome.ACCEPTED);
        mockSmsProviderClient.setCustomProviderRef("SINGLE_DISPATCH_REF");

        boolean dispatched = dispatcher.dispatchSingle(outbox.getId());
        assertThat(dispatched).isTrue();

        SmsOutbox updated = outboxRepository.findById(outbox.getId()).orElseThrow();
        assertThat(updated.getStatus()).isEqualTo(SmsOutboxStatus.ACCEPTED);
        assertThat(updated.getProviderRef()).isEqualTo("SINGLE_DISPATCH_REF");

        // Attempting to dispatch the same record again returns false (already claimed/completed)
        boolean secondAttempt = dispatcher.dispatchSingle(outbox.getId());
        assertThat(secondAttempt).isFalse();
    }
}
