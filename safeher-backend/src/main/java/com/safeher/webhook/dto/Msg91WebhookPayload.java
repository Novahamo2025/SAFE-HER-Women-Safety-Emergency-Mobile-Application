package com.safeher.webhook.dto;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO mapping official MSG91 SendOTP delivery report webhook payload.
 *
 * Official SendOTP Webhook Fields:
 * - requestId: MSG91-generated identifier for the message request
 * - telNum: recipient mobile number
 * - status: delivery status ('1' for Delivered, '2' for Failed)
 * - requestedAt: request initiation timestamp
 * - deliveryTime: delivery-report timestamp
 * - CRQID: custom correlation parameter (matches outbox correlationId)
 * - failureReason: failure details
 * - verified: indicates whether OTP verification through MSG91's VerifyOTP API occurred (informational only)
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonIgnoreProperties(ignoreUnknown = true)
public class Msg91WebhookPayload {

    @JsonProperty("requestId")
    private String requestId;

    @JsonProperty("telNum")
    private String telNum;

    @JsonProperty("status")
    private String status;

    @JsonProperty("requestedAt")
    private String requestedAt;

    @JsonProperty("deliveryTime")
    private String deliveryTime;

    @JsonProperty("CRQID")
    private String crqid;

    @JsonProperty("failureReason")
    private String failureReason;

    @JsonProperty("verified")
    private Object verified;

    @JsonProperty("senderId")
    private String senderId;

    @JsonProperty("flowID")
    private String flowId;
}
