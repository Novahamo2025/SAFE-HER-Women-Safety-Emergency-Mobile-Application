package com.safeher.notification;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface NotificationDeliveryRepository extends JpaRepository<NotificationDelivery, Long> {
    List<NotificationDelivery> findByEmergencyEventIdOrderBySentAtDesc(Long emergencyEventId);
    List<NotificationDelivery> findByStatus(String status);
}
