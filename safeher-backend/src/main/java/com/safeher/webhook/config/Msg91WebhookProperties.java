package com.safeher.webhook.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * Configuration properties for MSG91 webhook authentication and parameters.
 */
@Configuration
@ConfigurationProperties(prefix = "app.webhook.msg91")
@Data
public class Msg91WebhookProperties {

    /**
     * Header name configured in the MSG91 dashboard for webhook authentication.
     * Default: X-SvaShield-Webhook-Secret
     */
    private String secretHeaderName = "X-SvaShield-Webhook-Secret";

    /**
     * Shared secret value configured in MSG91 dashboard and environment.
     */
    private String secretHeaderValue;

    /**
     * High-entropy secret token passed in the webhook URL path (/api/webhooks/msg91/{urlToken}).
     */
    private String urlToken;
}
