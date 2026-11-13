package com.safeher.webhook.repository;

import com.safeher.webhook.model.QuarantinedWebhookEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface QuarantinedWebhookEventRepository extends JpaRepository<QuarantinedWebhookEvent, Long> {

    List<QuarantinedWebhookEvent> findByRejectionReason(String rejectionReason);
}
