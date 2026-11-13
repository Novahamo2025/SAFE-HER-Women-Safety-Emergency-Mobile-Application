package com.safeher.webhook.controller;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.safeher.auth.util.ClientIpResolver;
import com.safeher.webhook.config.Msg91WebhookProperties;
import com.safeher.webhook.dto.Msg91WebhookPayload;
import com.safeher.webhook.model.QuarantinedWebhookEvent;
import com.safeher.webhook.repository.QuarantinedWebhookEventRepository;
import com.safeher.webhook.service.SmsWebhookReconciliationService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

/**
 * REST controller for receiving and securely reconciling MSG91 SendOTP delivery reports.
 *
 * Security Requirements:
 * 1. Constant-time validation of secret header and URL token.
 * 2. Unauthorized requests rejected with HTTP 401.
 * 3. Authenticated malformed or unmatched requests acknowledged with HTTP 200 and quarantined,
 *    preventing MSG91 auto-pause.
 * 4. Zero exposure or logging of secrets, credentials, or payload ciphertexts.
 */
@RestController
@RequestMapping("/api/webhooks")
@RequiredArgsConstructor
@Slf4j
public class SmsWebhookController {

    private final Msg91WebhookProperties webhookProperties;
    private final SmsWebhookReconciliationService reconciliationService;
    private final QuarantinedWebhookEventRepository quarantineRepository;
    private final ObjectMapper objectMapper;

    @PostMapping({"/msg91/{urlSecretToken}", "/sms/dlr/{urlSecretToken}"})
    public ResponseEntity<Map<String, String>> receiveDeliveryReport(
            @PathVariable("urlSecretToken") String urlSecretToken,
            @RequestHeader(value = "X-SvaShield-Webhook-Secret", required = false) String secretHeader,
            @RequestBody(required = false) String rawPayload,
            HttpServletRequest request) {

        String clientIp = ClientIpResolver.getClientIp(request);

        // 1. Authenticate custom secret header and URL secret token in constant time
        if (!isAuthenticated(secretHeader, urlSecretToken)) {
            log.warn("Unauthorized webhook attempt rejected from IP: {}", clientIp);
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "Unauthorized webhook access"));
        }

        // 2. Validate payload existence
        if (rawPayload == null || rawPayload.isBlank()) {
            quarantineRepository.save(QuarantinedWebhookEvent.builder()
                    .rawPayload("")
                    .rejectionReason("EMPTY_PAYLOAD")
                    .sourceIp(clientIp)
                    .build());
            return ResponseEntity.ok(Map.of("status", "quarantined", "reason", "Empty payload"));
        }

        // 3. Parse JSON safely
        Msg91WebhookPayload payload;
        try {
            payload = objectMapper.readValue(rawPayload, Msg91WebhookPayload.class);
        } catch (JsonProcessingException e) {
            log.warn("Malformed JSON received from authenticated webhook sender (IP: {}). Quarantining event.", clientIp);
            quarantineRepository.save(QuarantinedWebhookEvent.builder()
                    .rawPayload(rawPayload)
                    .rejectionReason("MALFORMED_JSON: " + e.getMessage())
                    .sourceIp(clientIp)
                    .build());
            return ResponseEntity.ok(Map.of("status", "quarantined", "reason", "Malformed JSON"));
        }

        // 4. Validate minimum essential payload structure
        if ((payload.getRequestId() == null || payload.getRequestId().isBlank()) &&
                (payload.getCrqid() == null || payload.getCrqid().isBlank())) {
            log.warn("Webhook payload missing both requestId and CRQID from IP: {}. Quarantining event.", clientIp);
            quarantineRepository.save(QuarantinedWebhookEvent.builder()
                    .rawPayload(rawPayload)
                    .rejectionReason("MISSING_IDENTIFIERS: Both requestId and CRQID are missing or blank")
                    .sourceIp(clientIp)
                    .build());
            return ResponseEntity.ok(Map.of("status", "quarantined", "reason", "Missing identifiers"));
        }

        // 5. Reconcile with outbox
        SmsWebhookReconciliationService.ReconciliationOutcome outcome =
                reconciliationService.processDeliveryReport(payload, rawPayload, clientIp);

        return ResponseEntity.ok(Map.of(
                "status", "acknowledged",
                "outcome", outcome.name()
        ));
    }

    /**
     * Performs constant-time comparison of incoming secrets against configured values.
     * Prevents timing attacks and ensures zero logging of secret values.
     */
    private boolean isAuthenticated(String incomingHeaderSecret, String incomingUrlToken) {
        String expectedHeaderSecret = webhookProperties.getSecretHeaderValue();
        String expectedUrlToken = webhookProperties.getUrlToken();

        // If either secret is unconfigured, reject all requests safely
        if (expectedHeaderSecret == null || expectedHeaderSecret.isBlank() ||
                expectedUrlToken == null || expectedUrlToken.isBlank()) {
            log.error("MSG91 webhook secrets are not configured. Rejecting all webhook requests.");
            return false;
        }

        if (incomingHeaderSecret == null || incomingUrlToken == null) {
            return false;
        }

        boolean headerMatches = MessageDigest.isEqual(
                expectedHeaderSecret.getBytes(StandardCharsets.UTF_8),
                incomingHeaderSecret.getBytes(StandardCharsets.UTF_8)
        );

        boolean tokenMatches = MessageDigest.isEqual(
                expectedUrlToken.getBytes(StandardCharsets.UTF_8),
                incomingUrlToken.getBytes(StandardCharsets.UTF_8)
        );

        return headerMatches && tokenMatches;
    }
}
