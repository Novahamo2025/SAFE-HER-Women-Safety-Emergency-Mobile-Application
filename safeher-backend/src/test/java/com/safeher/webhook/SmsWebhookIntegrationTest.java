package com.safeher.webhook;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.safeher.otp.model.OtpStatus;
import com.safeher.otp.model.OtpVerification;
import com.safeher.otp.repository.OtpVerificationRepository;
import com.safeher.outbox.model.SmsOutbox;
import com.safeher.outbox.model.SmsOutboxStatus;
import com.safeher.outbox.repository.SmsOutboxRepository;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import com.safeher.webhook.config.Msg91WebhookProperties;
import com.safeher.webhook.dto.Msg91WebhookPayload;
import com.safeher.webhook.model.QuarantinedWebhookEvent;
import com.safeher.webhook.model.WebhookEventReceipt;
import com.safeher.webhook.repository.QuarantinedWebhookEventRepository;
import com.safeher.webhook.repository.WebhookEventReceiptRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class SmsWebhookIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private Msg91WebhookProperties webhookProperties;

    @Autowired
    private WebhookEventReceiptRepository receiptRepository;

    @Autowired
    private QuarantinedWebhookEventRepository quarantineRepository;

    @Autowired
    private SmsOutboxRepository smsOutboxRepository;

    @Autowired
    private OtpVerificationRepository otpVerificationRepository;

    @Autowired
    private UserRepository userRepository;

    private static final String TEST_HEADER = "X-SvaShield-Webhook-Secret";
    private static final String TEST_SECRET = "test-webhook-secret-token-abcdef123456";
    private static final String TEST_URL_TOKEN = "test-url-token-xyz789";

    @BeforeEach
    void setUp() {
        receiptRepository.deleteAll();
        quarantineRepository.deleteAll();
        smsOutboxRepository.deleteAll();
        otpVerificationRepository.deleteAll();
        userRepository.deleteAll();
    }

    @AfterEach
    void tearDown() {
        receiptRepository.deleteAll();
        quarantineRepository.deleteAll();
        smsOutboxRepository.deleteAll();
        otpVerificationRepository.deleteAll();
        userRepository.deleteAll();
    }

    private SmsOutbox createTestOutbox(String phone, String correlationId, SmsOutboxStatus status) {
        User user = User.builder()
                .name("Test Subject")
                .email("subject@example.com")
                .phone(phone)
                .passwordHash("DummyHash123")
                .role("ROLE_USER")
                .accountStatus("PENDING_VERIFICATION")
                .isLegacyAccount(false)
                .phoneVerifiedAt(null)
                .isVerified(false)
                .build();
        userRepository.save(user);

        OtpVerification verification = OtpVerification.builder()
                .user(user)
                .phone(phone)
                .purpose("REGISTRATION")
                .otpHash("0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
                .salt("0123456789abcdef0123456789abcdef")
                .status(OtpStatus.PENDING)
                .attemptsCount(0)
                .maxAttempts(3)
                .expiresAt(Instant.now().plusSeconds(600))
                .build();
        otpVerificationRepository.save(verification);

        SmsOutbox outbox = SmsOutbox.builder()
                .otpVerification(verification)
                .phone(phone)
                .correlationId(correlationId)
                .keyVersion("v1")
                .encryptedPayload("EncryptedCiphertextData==")
                .payloadNonce("Nonce123==")
                .payloadTag("Tag123==")
                .status(status)
                .nextReconcileAt(Instant.now().plusSeconds(120))
                .build();
        return smsOutboxRepository.save(outbox);
    }

    @Test
    @DisplayName("1. Webhook missing secret header is rejected with 401 Unauthorized")
    void testWebhook_missingSecretHeader_returns401() throws Exception {
        Msg91WebhookPayload payload = Msg91WebhookPayload.builder()
                .requestId("REQ-001")
                .status("1")
                .build();

        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("Unauthorized webhook access"));

        // Confirm nothing saved
        assertThat(receiptRepository.findAll()).isEmpty();
        assertThat(quarantineRepository.findAll()).isEmpty();
    }

    @Test
    @DisplayName("2. Webhook with invalid secret header is rejected with 401 Unauthorized")
    void testWebhook_invalidSecretHeader_returns401() throws Exception {
        Msg91WebhookPayload payload = Msg91WebhookPayload.builder()
                .requestId("REQ-001")
                .status("1")
                .build();

        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, "wrong-secret-value")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("Unauthorized webhook access"));
    }

    @Test
    @DisplayName("3. Webhook with invalid URL secret token is rejected with 401 Unauthorized")
    void testWebhook_invalidUrlToken_returns401() throws Exception {
        Msg91WebhookPayload payload = Msg91WebhookPayload.builder()
                .requestId("REQ-001")
                .status("1")
                .build();

        mockMvc.perform(post("/api/webhooks/msg91/invalid-url-token")
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("4. Valid delivery report callback transitions outbox to ACCEPTED and clears ciphertext")
    void testWebhook_validDeliveredCallback_transitionsOutboxToAccepted() throws Exception {
        String corrId = "CORR-" + UUID.randomUUID();
        SmsOutbox outbox = createTestOutbox("+919876543210", corrId, SmsOutboxStatus.DISPATCHING);

        Msg91WebhookPayload payload = Msg91WebhookPayload.builder()
                .requestId("MSG91_REQ_9999")
                .telNum("919876543210")
                .status("1") // 1 = Delivered
                .crqid(corrId)
                .deliveryTime("2026-11-11 12:00:00")
                .build();

        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("acknowledged"))
                .andExpect(jsonPath("$.outcome").value("RECONCILED"));

        // Verify outbox updated
        SmsOutbox updatedOutbox = smsOutboxRepository.findById(outbox.getId()).orElseThrow();
        assertThat(updatedOutbox.getStatus()).isEqualTo(SmsOutboxStatus.ACCEPTED);
        assertThat(updatedOutbox.getProviderRef()).isEqualTo("MSG91_REQ_9999");
        assertThat(updatedOutbox.getEncryptedPayload()).isNull(); // Ciphertext cleared

        // Verify deduplication receipt saved
        List<WebhookEventReceipt> receipts = receiptRepository.findAll();
        assertThat(receipts).hasSize(1);
        assertThat(receipts.get(0).getProviderEventId()).isEqualTo("MSG91_REQ_9999:1:2026-11-11 12:00:00");
    }

    @Test
    @DisplayName("5. Duplicate callback is processed idempotently without repeating side effects")
    void testWebhook_duplicateCallback_isIdempotent() throws Exception {
        String corrId = "CORR-" + UUID.randomUUID();
        createTestOutbox("+919876543210", corrId, SmsOutboxStatus.DISPATCHING);

        Msg91WebhookPayload payload = Msg91WebhookPayload.builder()
                .requestId("MSG91_REQ_8888")
                .telNum("919876543210")
                .status("1")
                .crqid(corrId)
                .deliveryTime("2026-11-11 12:00:00")
                .build();

        // 1st Callback: Processed & Reconciled
        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.outcome").value("RECONCILED"));

        // 2nd Callback (Retry from MSG91): Handled idempotently
        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.outcome").value("DUPLICATE"));

        // Exactly ONE receipt exists
        assertThat(receiptRepository.findAll()).hasSize(1);
    }

    @Test
    @DisplayName("6. Authenticated but unmatched callback is quarantined and acknowledged with 200 (prevents auto-pause)")
    void testWebhook_unmatchedCallback_quarantined_returns200() throws Exception {
        Msg91WebhookPayload payload = Msg91WebhookPayload.builder()
                .requestId("UNKNOWN_REQ_1111")
                .telNum("919876543999")
                .status("1")
                .crqid("UNKNOWN_CRQID")
                .deliveryTime("2026-11-11 12:05:00")
                .build();

        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.outcome").value("QUARANTINED"));

        // Receipt recorded
        assertThat(receiptRepository.findAll()).hasSize(1);

        // Quarantine event recorded
        List<QuarantinedWebhookEvent> quarantined = quarantineRepository.findAll();
        assertThat(quarantined).hasSize(1);
        assertThat(quarantined.get(0).getRejectionReason()).contains("UNMATCHED_OUTBOX_RECORD");
    }

    @Test
    @DisplayName("7. Authenticated malformed JSON is quarantined and acknowledged with 200 (prevents auto-pause)")
    void testWebhook_malformedJson_quarantined_returns200() throws Exception {
        String brokenJson = "{\"broken\": true, \"missing_brace\":";

        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(brokenJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("quarantined"))
                .andExpect(jsonPath("$.reason").value("Malformed JSON"));

        // Quarantine event recorded
        List<QuarantinedWebhookEvent> quarantined = quarantineRepository.findAll();
        assertThat(quarantined).hasSize(1);
        assertThat(quarantined.get(0).getRejectionReason()).contains("MALFORMED_JSON");
    }

    @Test
    @DisplayName("8. Terminal state protection: RESOLVED outbox is never overwritten by late-arriving callbacks")
    void testWebhook_terminalStateProtection_resolved() throws Exception {
        String corrId = "CORR-" + UUID.randomUUID();
        // Outbox is already RESOLVED (user entered OTP code successfully)
        SmsOutbox outbox = createTestOutbox("+919876543210", corrId, SmsOutboxStatus.RESOLVED);

        // Delayed callback arrives claiming delivery failed (status = 2)
        Msg91WebhookPayload failurePayload = Msg91WebhookPayload.builder()
                .requestId("REQ-DELAYED-99")
                .status("2")
                .failureReason("Network timeout")
                .crqid(corrId)
                .deliveryTime("2026-11-11 12:10:00")
                .build();

        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(failurePayload)))
                .andExpect(status().isOk());

        // Invariant: Outbox status MUST remain RESOLVED!
        SmsOutbox checkOutbox = smsOutboxRepository.findById(outbox.getId()).orElseThrow();
        assertThat(checkOutbox.getStatus()).isEqualTo(SmsOutboxStatus.RESOLVED);
    }

    @Test
    @DisplayName("9. Terminal state protection: SUPERSEDED outbox is never overwritten by late-arriving callbacks")
    void testWebhook_terminalStateProtection_superseded() throws Exception {
        String corrId = "CORR-" + UUID.randomUUID();
        // Outbox was superseded when user requested an OTP resend
        SmsOutbox outbox = createTestOutbox("+919876543210", corrId, SmsOutboxStatus.SUPERSEDED);

        Msg91WebhookPayload successPayload = Msg91WebhookPayload.builder()
                .requestId("REQ-SUPERSEDED-11")
                .status("1")
                .crqid(corrId)
                .deliveryTime("2026-11-11 12:15:00")
                .build();

        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(successPayload)))
                .andExpect(status().isOk());

        // Invariant: Outbox status MUST remain SUPERSEDED!
        SmsOutbox checkOutbox = smsOutboxRepository.findById(outbox.getId()).orElseThrow();
        assertThat(checkOutbox.getStatus()).isEqualTo(SmsOutboxStatus.SUPERSEDED);
    }

    @Test
    @DisplayName("10. CRITICAL INVARIANT: Delivery report callback NEVER verifies user or consumes OTP")
    void testWebhook_neverVerifiesUserOrConsumesOtp() throws Exception {
        String corrId = "CORR-" + UUID.randomUUID();
        SmsOutbox outbox = createTestOutbox("+919876543210", corrId, SmsOutboxStatus.DISPATCHING);

        // Webhook arrives claiming delivery was successful (status = 1) AND MSG91 verified = true
        Msg91WebhookPayload payload = Msg91WebhookPayload.builder()
                .requestId("REQ-DELIVERY-CONFIRMED")
                .telNum("919876543210")
                .status("1")
                .crqid(corrId)
                .verified(true) // Vendor field from MSG91 VerifyAPI
                .deliveryTime("2026-11-11 12:20:00")
                .build();

        mockMvc.perform(post("/api/webhooks/msg91/" + TEST_URL_TOKEN)
                        .header(TEST_HEADER, TEST_SECRET)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(payload)))
                .andExpect(status().isOk());

        // 1. Check User in database
        User user = userRepository.findByEmailIgnoreCase("subject@example.com").orElseThrow();
        assertThat(user.getPhoneVerifiedAt())
                .as("Security Invariant: phone_verified_at must remain NULL until physical code entry")
                .isNull();
        assertThat(user.getIsVerified())
                .as("Security Invariant: is_verified must remain FALSE")
                .isFalse();
        assertThat(user.getAccountStatus())
                .as("Security Invariant: account_status must remain PENDING_VERIFICATION")
                .isEqualTo("PENDING_VERIFICATION");

        // 2. Check OTP verification in database
        OtpVerification verification = otpVerificationRepository.findById(outbox.getOtpVerification().getId()).orElseThrow();
        assertThat(verification.getStatus())
                .as("Security Invariant: OTP verification status must remain PENDING")
                .isEqualTo(OtpStatus.PENDING);
        assertThat(verification.getConsumedAt())
                .as("Security Invariant: consumed_at must remain NULL")
                .isNull();
    }
}
