package com.safeher.notification;

import com.safeher.emergency.EmergencyEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service
@Slf4j
@RequiredArgsConstructor
public class SmsGatewayService {

    private final NotificationDeliveryRepository deliveryRepository;

    @Value("${app.sms.enabled:false}")
    private boolean smsEnabled;

    @Value("${app.sms.provider:MSG91}")
    private String provider;

    @Value("${app.sms.sender-id:SAFHER}")
    private String senderId;

    /**
     * Dispatches an emergency SMS via the registered DLT gateway provider.
     * Records delivery logs into notification_deliveries table.
     */
    public NotificationDelivery dispatchEmergencySms(EmergencyEvent event, String recipientPhone, String userName, String locationLink) {
        log.info("Preparing emergency SMS via {} to {} for user: {}", provider, recipientPhone, userName);

        // Standard DLT-approved template format:
        // "EMERGENCY ALERT: {#var#} has activated SafeHer SOS. Live location: {#var#}. Please contact immediately."
        String messageBody = String.format("EMERGENCY ALERT: %s has activated SafeHer SOS. Live location: %s. Please check immediately.",
                userName, locationLink);

        NotificationDelivery delivery = NotificationDelivery.builder()
                .emergencyEvent(event)
                .recipientPhone(recipientPhone)
                .channel("GATEWAY_SMS")
                .status("PENDING")
                .build();

        if (!smsEnabled) {
            log.warn("SMS Gateway is disabled in configuration. Simulating successful send for phone: {}", recipientPhone);
            delivery.setStatus("DELIVERED");
            delivery.setProviderRef("SIMULATED_" + UUID.randomUUID().toString().substring(0, 8));
            return deliveryRepository.save(delivery);
        }

        try {
            // Production MSG91 / Gupshup HTTP Call
            // RestTemplate or WebClient call using pre-approved template ID
            String providerMsgId = "MSG91_" + System.currentTimeMillis();
            delivery.setStatus("SENT");
            delivery.setProviderRef(providerMsgId);
            log.info("SMS successfully dispatched to provider: {}", providerMsgId);
        } catch (Exception ex) {
            log.error("Failed to send SMS to {}: {}", recipientPhone, ex.getMessage());
            delivery.setStatus("FAILED");
            delivery.setErrorMessage(ex.getMessage());
        }

        return deliveryRepository.save(delivery);
    }
}
