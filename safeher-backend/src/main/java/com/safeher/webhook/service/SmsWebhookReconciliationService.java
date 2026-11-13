package com.safeher.webhook.service;

import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.model.SmsOutboxStatus;
import com.safeher.outbox.repository.SmsOutboxRepository;
import com.safeher.webhook.dto.Msg91WebhookPayload;
import com.safeher.webhook.model.QuarantinedWebhookEvent;
import com.safeher.webhook.model.WebhookEventReceipt;
import com.safeher.webhook.repository.QuarantinedWebhookEventRepository;
import com.safeher.webhook.repository.WebhookEventReceiptRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.Optional;

/**
 * Service for reconciling MSG91 SendOTP delivery report webhooks with the SMS Outbox.
 *
 * Security Invariants:
 * 1. Carrier delivery reports are strictly decoupled from OTP verification and consumption.
 *    A webhook callback NEVER verifies a phone number, modifies user status, or consumes an OTP.
 * 2. Idempotency is enforced via a unique composite event receipt (requestId + status + timestamp).
 *    Duplicate callbacks return without repeating side effects.
 * 3. Terminal state protection: An outbox record in RESOLVED or SUPERSEDED status is never
 *    reverted or modified by late-arriving callbacks.
 * 4. Uncertain dispatches NEVER trigger automatic resends upon carrier failure.
 * 5. Authenticated but unmatched callbacks are quarantined and acknowledged with HTTP 200
 *    to prevent MSG91 from auto-pausing the webhook in the portal.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SmsWebhookReconciliationService {

    private final WebhookEventReceiptRepository receiptRepository;
    private final QuarantinedWebhookEventRepository quarantineRepository;
    private final SmsOutboxRepository smsOutboxRepository;

    private static final DateTimeFormatter MSG91_DATE_FORMAT =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    @Transactional
    public ReconciliationOutcome processDeliveryReport(
            Msg91WebhookPayload payload,
            String rawPayload,
            String clientIp) {

        String reqId = payload.getRequestId() != null ? payload.getRequestId().trim() : "UNKNOWN";
        String status = payload.getStatus() != null ? payload.getStatus().trim() : "UNKNOWN";
        String timeKey = payload.getDeliveryTime() != null ? payload.getDeliveryTime().trim() :
                (payload.getRequestedAt() != null ? payload.getRequestedAt().trim() : "0");

        // 1. Compute Composite Deduplication Key
        String compositeKey = reqId + ":" + status + ":" + timeKey;

        // 2. Idempotency Check: Return early if receipt already recorded
        if (receiptRepository.existsByProviderEventId(compositeKey)) {
            log.debug("Webhook duplicate received for composite key: {}. Acknowledging idempotently.", compositeKey);
            return ReconciliationOutcome.DUPLICATE;
        }

        // 3. Persist Event Receipt
        Instant deliveryInstant = parseTimestamp(payload.getDeliveryTime());
        WebhookEventReceipt receipt = WebhookEventReceipt.builder()
                .providerEventId(compositeKey)
                .requestId(reqId)
                .correlationId(payload.getCrqid() != null ? payload.getCrqid().trim() : null)
                .statusCode(status)
                .deliveryTime(deliveryInstant)
                .build();
        receiptRepository.save(receipt);

        // 4. Correlate with SMS Outbox by CRQID (preferred) or requestId (providerRef)
        Optional<SmsOutbox> outboxOpt = Optional.empty();
        if (payload.getCrqid() != null && !payload.getCrqid().isBlank()) {
            outboxOpt = smsOutboxRepository.findByCorrelationId(payload.getCrqid().trim());
        }
        if (outboxOpt.isEmpty() && !"UNKNOWN".equals(reqId) && !reqId.isBlank()) {
            outboxOpt = smsOutboxRepository.findByProviderRef(reqId);
        }

        // 5. Handle Unmatched Callback -> Quarantine safely
        if (outboxOpt.isEmpty()) {
            log.warn("Webhook authenticated but unmatched with outbox record: requestId={}, CRQID={}. Quarantining event.",
                    reqId, payload.getCrqid());
            quarantineRepository.save(QuarantinedWebhookEvent.builder()
                    .rawPayload(rawPayload != null ? rawPayload : "{}")
                    .rejectionReason("UNMATCHED_OUTBOX_RECORD: requestId=" + reqId + ", CRQID=" + payload.getCrqid())
                    .sourceIp(clientIp)
                    .build());
            return ReconciliationOutcome.QUARANTINED;
        }

        SmsOutbox outbox = outboxOpt.get();

        // 6. Terminal State Protection: Never revert RESOLVED or SUPERSEDED outbox state
        if (outbox.getStatus() == SmsOutboxStatus.RESOLVED || outbox.getStatus() == SmsOutboxStatus.SUPERSEDED) {
            log.info("SmsOutbox [{}] is already in terminal state {}. Ignoring carrier delivery update to protect authoritative state.",
                    outbox.getId(), outbox.getStatus());
            return ReconciliationOutcome.RECONCILED;
        }

        // 7. Update Non-Terminal Outbox Status
        boolean isDelivered = "1".equals(status) || "DELIVERED".equalsIgnoreCase(status);
        boolean isFailed = "2".equals(status) || "FAILED".equalsIgnoreCase(status);

        if (isDelivered) {
            if (outbox.getStatus() == SmsOutboxStatus.DISPATCHING || outbox.getStatus() == SmsOutboxStatus.UNCERTAIN) {
                outbox.setStatus(SmsOutboxStatus.ACCEPTED);
                if (outbox.getProviderRef() == null && !"UNKNOWN".equals(reqId)) {
                    outbox.setProviderRef(reqId);
                }
                outbox.clearCiphertext();
                smsOutboxRepository.save(outbox);
                log.info("SmsOutbox [{}] transitioned to ACCEPTED via verified carrier delivery report callback.", outbox.getId());
            }
        } else if (isFailed) {
            if (outbox.getStatus() == SmsOutboxStatus.DISPATCHING || outbox.getStatus() == SmsOutboxStatus.UNCERTAIN) {
                outbox.setStatus(SmsOutboxStatus.REJECTED);
                if (outbox.getProviderRef() == null && !"UNKNOWN".equals(reqId)) {
                    outbox.setProviderRef(reqId);
                }
                outbox.clearCiphertext();
                smsOutboxRepository.save(outbox);
                log.warn("SmsOutbox [{}] transitioned to REJECTED via delivery report callback. Reason: {}. Auto-resend is disabled.",
                        outbox.getId(), payload.getFailureReason());
            } else if (outbox.getStatus() == SmsOutboxStatus.ACCEPTED) {
                log.warn("SmsOutbox [{}] carrier delivery failure reported after provider acceptance. Reason: {}. Auto-resend is disabled.",
                        outbox.getId(), payload.getFailureReason());
            }
        }

        return ReconciliationOutcome.RECONCILED;
    }

    private Instant parseTimestamp(String timestampStr) {
        if (timestampStr == null || timestampStr.isBlank()) {
            return null;
        }
        try {
            return LocalDateTime.parse(timestampStr.trim(), MSG91_DATE_FORMAT).toInstant(ZoneOffset.UTC);
        } catch (DateTimeParseException e) {
            try {
                return Instant.parse(timestampStr.trim());
            } catch (Exception ex) {
                log.debug("Could not parse delivery timestamp: {}", timestampStr);
                return null;
            }
        }
    }

    public enum ReconciliationOutcome {
        RECONCILED,
        DUPLICATE,
        QUARANTINED
    }
}
