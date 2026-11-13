package com.safeher.webhook.repository;

import com.safeher.webhook.model.WebhookEventReceipt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface WebhookEventReceiptRepository extends JpaRepository<WebhookEventReceipt, Long> {

    boolean existsByProviderEventId(String providerEventId);

    Optional<WebhookEventReceipt> findByProviderEventId(String providerEventId);
}
