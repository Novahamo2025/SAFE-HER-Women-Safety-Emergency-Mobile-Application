package com.safeher.admin;

import com.safeher.admin.dto.DashboardStatsResponse;
import com.safeher.admin.dto.AdminDashboardData;
import com.safeher.checkin.CheckInRepository;
import com.safeher.contact.ContactRepository;
import com.safeher.emergency.EmergencyRepository;
import com.safeher.journey.JourneyRepository;
import com.safeher.location.LocationRepository;
import com.safeher.notification.NotificationDeliveryRepository;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminService {

    private static final String ACTIVE_STATUS = "ACTIVE";

    private final EmergencyRepository emergencyRepository;
    private final JourneyRepository journeyRepository;
    private final CheckInRepository checkInRepository;
    private final UserRepository userRepository;
    private final NotificationDeliveryRepository deliveryRepository;
    private final ContactRepository contactRepository;
    private final LocationRepository locationRepository;

    public DashboardStatsResponse getOverviewStats() {
        long activeSos = emergencyRepository.findByStatus(ACTIVE_STATUS).size();
        long activeJourneys = journeyRepository.findByStatusAndExpectedArrivalBefore(ACTIVE_STATUS, java.time.Instant.now().plusSeconds(86400)).size();
        long pendingCheckins = checkInRepository.findByStatusAndScheduledTimeBefore("PENDING", java.time.Instant.now().plusSeconds(86400)).size();
        long totalUsers = userRepository.count();
        long failedDeliveries = deliveryRepository.findByStatus("FAILED").size();

        return DashboardStatsResponse.builder()
                .activeSosCount(activeSos)
                .activeJourneysCount(activeJourneys)
                .pendingCheckinsCount(pendingCheckins)
                .totalUsersCount(totalUsers)
                .failedDeliveriesCount(failedDeliveries)
                .build();
    }

        public List<AdminDashboardData.Emergency> getActiveEmergencies() {
        return emergencyRepository.findByStatus(ACTIVE_STATUS).stream()
            .map(event -> {
                var location = locationRepository
                    .findFirstByEmergencyEventIdOrderByRecordedAtDesc(event.getId())
                    .orElse(null);
                return new AdminDashboardData.Emergency(
                    event.getId(),
                    event.getUser().getName(),
                    event.getUser().getPhone(),
                    event.getEventType(),
                    event.getStatus(),
                    event.getStartedAt(),
                    location == null ? null : location.getLatitude(),
                    location == null ? null : location.getLongitude(),
                    location == null ? null : location.getRecordedAt());
            })
            .toList();
    }

        public List<AdminDashboardData.Journey> getJourneys() {
        return journeyRepository.findAll().stream()
            .map(journey -> new AdminDashboardData.Journey(
                journey.getId(),
                journey.getUser().getName(),
                journey.getUser().getPhone(),
                journey.getDestination(),
                journey.getStartLat(),
                journey.getStartLng(),
                journey.getDestLat(),
                journey.getDestLng(),
                journey.getExpectedArrival(),
                journey.getGracePeriodMinutes(),
                journey.getStatus(),
                journey.getStartedAt(),
                journey.getCompletedAt()))
            .toList();
    }

        public List<AdminDashboardData.CheckIn> getCheckIns() {
        return checkInRepository.findAll().stream()
            .map(checkIn -> new AdminDashboardData.CheckIn(
                checkIn.getId(),
                checkIn.getUser().getName(),
                checkIn.getUser().getPhone(),
                checkIn.getScheduledTime(),
                checkIn.getGracePeriodMinutes(),
                checkIn.getStatus(),
                checkIn.getLastPromptedAt(),
                checkIn.getCompletedAt()))
            .toList();
        }

        public List<AdminDashboardData.Contact> getContacts() {
        return contactRepository.findAll().stream()
            .map(contact -> new AdminDashboardData.Contact(
                contact.getId(),
                contact.getUser().getName(),
                contact.getUser().getPhone(),
                contact.getContactName(),
                contact.getPhone(),
                contact.getRelationship(),
                contact.getPriority(),
                contact.getNotifySms(),
                contact.getNotifyPush(),
                contact.getIsVerified(),
                contact.getCreatedAt()))
            .toList();
        }

        public List<AdminDashboardData.Delivery> getDeliveries() {
        return deliveryRepository.findAll().stream()
            .map(delivery -> new AdminDashboardData.Delivery(
                delivery.getId(),
                delivery.getEmergencyEvent() == null ? null : delivery.getEmergencyEvent().getId(),
                delivery.getRecipientPhone(),
                delivery.getChannel(),
                delivery.getStatus(),
                delivery.getProviderRef(),
                delivery.getErrorMessage(),
                delivery.getSentAt()))
            .toList();
        }

        public List<AdminDashboardData.User> getAllUsers() {
        return userRepository.findAll().stream()
            .map(user -> new AdminDashboardData.User(
                user.getId(),
                user.getName(),
                user.getEmail(),
                user.getPhone(),
                user.getRole(),
                user.getIsVerified(),
                user.getAccountStatus(),
                user.getLastLoginAt(),
                user.getCreatedAt()))
            .toList();
    }
}
