package com.safeher.admin.dto;

import java.math.BigDecimal;
import java.time.Instant;

public final class AdminDashboardData {

    private AdminDashboardData() {
    }

    public record Emergency(
            Long id,
            String userName,
            String userPhone,
            String eventType,
            String status,
            Instant startedAt,
            BigDecimal latitude,
            BigDecimal longitude,
            Instant locationRecordedAt) {
    }

    public record Journey(
            Long id,
            String userName,
            String userPhone,
            String destination,
            BigDecimal startLat,
            BigDecimal startLng,
            BigDecimal destLat,
            BigDecimal destLng,
            Instant expectedArrival,
            Integer gracePeriodMinutes,
            String status,
            Instant startedAt,
            Instant completedAt) {
    }

    public record CheckIn(
            Long id,
            String userName,
            String userPhone,
            Instant scheduledTime,
            Integer gracePeriodMinutes,
            String status,
            Instant lastPromptedAt,
            Instant completedAt) {
    }

    public record Contact(
            Long id,
            String userName,
            String userPhone,
            String contactName,
            String phone,
            String relationship,
            Integer priority,
            Boolean notifySms,
            Boolean notifyPush,
            Boolean verified,
            Instant createdAt) {
    }

    public record Delivery(
            Long id,
            Long emergencyEventId,
            String recipientPhone,
            String channel,
            String status,
            String providerRef,
            String errorMessage,
            Instant sentAt) {
    }

    public record User(
            Long id,
            String name,
            String email,
            String phone,
            String role,
            Boolean verified,
            String accountStatus,
            Instant lastLoginAt,
            Instant createdAt) {
    }
}