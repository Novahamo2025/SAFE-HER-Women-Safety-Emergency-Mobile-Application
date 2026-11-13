package com.safeher.outbox.provider;

import lombok.Getter;
import lombok.Setter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * Mock SMS provider client used for local testing, integration tests,
 * and when external SMS dispatch is disabled.
 *
 * Supports deterministic simulation of ACCEPTED, REJECTED, UNCERTAIN outcomes
 * and network/transport exceptions.
 */
@Component
@Slf4j
public class MockSmsProviderClient implements SmsProviderClient {

    @Value("${app.sms.enabled:false}")
    private boolean smsEnabled;

    @Getter
    @Setter
    private SmsDispatchResult.Outcome defaultOutcome = SmsDispatchResult.Outcome.ACCEPTED;

    @Getter
    @Setter
    private RuntimeException simulatedException = null;

    @Getter
    @Setter
    private String customProviderRef = null;

    private final AtomicInteger dispatchCount = new AtomicInteger(0);
    private final List<DispatchedRecord> dispatchedRecords = new CopyOnWriteArrayList<>();

    public record DispatchedRecord(String phone, String correlationId, String payloadSnippet) {}

    @Override
    public SmsDispatchResult sendSms(String phone, String plaintextPayload, String correlationId) {
        dispatchCount.incrementAndGet();

        // Safe snippet for logging/auditing (redact majority of payload to protect secrets)
        String snippet = (plaintextPayload != null && plaintextPayload.length() >= 4)
                ? "[LEN=" + plaintextPayload.length() + "]"
                : "[EMPTY]";
        dispatchedRecords.add(new DispatchedRecord(phone, correlationId, snippet));

        if (simulatedException != null) {
            log.warn("MockSmsProviderClient throwing simulated exception for correlationId: {}", correlationId);
            throw simulatedException;
        }

        log.info("MockSmsProviderClient simulating dispatch to [{}] with outcome: {} (correlationId: {})",
                maskPhone(phone), defaultOutcome, correlationId);

        return switch (defaultOutcome) {
            case ACCEPTED -> {
                String ref = (customProviderRef != null) ? customProviderRef : "MOCK_MSG91_" + UUID.randomUUID().toString().substring(0, 12);
                yield SmsDispatchResult.accepted(ref);
            }
            case REJECTED -> SmsDispatchResult.rejected("MOCK_REJECTION: Simulated invalid destination or DLT failure");
            case UNCERTAIN -> SmsDispatchResult.uncertain("MOCK_UNCERTAIN: Simulated timeout / ambiguous provider response");
        };
    }

    public int getDispatchCount() {
        return dispatchCount.get();
    }

    public List<DispatchedRecord> getDispatchedRecords() {
        return List.copyOf(dispatchedRecords);
    }

    public void reset() {
        dispatchCount.set(0);
        dispatchedRecords.clear();
        defaultOutcome = SmsDispatchResult.Outcome.ACCEPTED;
        simulatedException = null;
        customProviderRef = null;
    }

    private static String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return "***";
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 3);
    }
}
