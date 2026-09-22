package com.safeher.admin;

import com.safeher.admin.dto.DashboardStatsResponse;
import com.safeher.checkin.CheckInRepository;
import com.safeher.emergency.EmergencyEvent;
import com.safeher.emergency.EmergencyRepository;
import com.safeher.journey.JourneyRepository;
import com.safeher.notification.NotificationDelivery;
import com.safeher.notification.NotificationDeliveryRepository;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminService {

    private final EmergencyRepository emergencyRepository;
    private final JourneyRepository journeyRepository;
    private final CheckInRepository checkInRepository;
    private final UserRepository userRepository;
    private final NotificationDeliveryRepository deliveryRepository;

    public DashboardStatsResponse getOverviewStats() {
        long activeSos = emergencyRepository.findByStatus("ACTIVE").size();
        long activeJourneys = journeyRepository.findByStatusAndExpectedArrivalBefore("ACTIVE", java.time.Instant.now().plusSeconds(86400)).size();
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

    public List<EmergencyEvent> getActiveEmergencies() {
        return emergencyRepository.findByStatus("ACTIVE");
    }

    public List<NotificationDelivery> getDeliveries() {
        return deliveryRepository.findAll();
    }

    public List<User> getAllUsers() {
        return userRepository.findAll();
    }
}
