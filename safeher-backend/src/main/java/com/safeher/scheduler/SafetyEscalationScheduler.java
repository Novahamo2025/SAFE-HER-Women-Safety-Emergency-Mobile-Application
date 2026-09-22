package com.safeher.scheduler;

import com.safeher.checkin.CheckIn;
import com.safeher.checkin.CheckInRepository;
import com.safeher.contact.ContactRepository;
import com.safeher.contact.EmergencyContact;
import com.safeher.emergency.EmergencyEvent;
import com.safeher.emergency.EmergencyRepository;
import com.safeher.journey.JourneyRepository;
import com.safeher.journey.SafeJourney;
import com.safeher.notification.SmsGatewayService;
import com.safeher.user.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Component
@Slf4j
@RequiredArgsConstructor
public class SafetyEscalationScheduler {

    private final JourneyRepository journeyRepository;
    private final CheckInRepository checkInRepository;
    private final EmergencyRepository emergencyRepository;
    private final ContactRepository contactRepository;
    private final SmsGatewayService smsGatewayService;

    /**
     * Polling worker: Runs every 60 seconds to detect overdue Safe Walks and missed Check-Ins.
     * Ensures safety escalation even if the user's phone is destroyed or offline.
     */
    @Scheduled(fixedRate = 60000)
    @Transactional
    public void monitorOverdueSafetyWorkflows() {
        Instant now = Instant.now();
        escalateOverdueJourneys(now);
        escalateMissedCheckIns(now);
    }

    private void escalateOverdueJourneys(Instant now) {
        List<SafeJourney> activeJourneys = journeyRepository.findByStatusAndExpectedArrivalBefore("ACTIVE", now);

        for (SafeJourney journey : activeJourneys) {
            Instant escalationDeadline = journey.getExpectedArrival().plus(journey.getGracePeriodMinutes(), ChronoUnit.MINUTES);

            if (now.isAfter(escalationDeadline)) {
                log.warn("Escalating overdue Safe Walk for user: {}, destination: {}",
                        journey.getUser().getName(), journey.getDestination());

                journey.setStatus("ESCALATED");
                journeyRepository.save(journey);

                // Create an emergency event for this escalation
                EmergencyEvent escalationEvent = EmergencyEvent.builder()
                        .user(journey.getUser())
                        .eventType("SAFE_WALK_OVERDUE")
                        .status("ACTIVE")
                        .cancellationReason("Automated server escalation: Overdue Safe Walk past grace period")
                        .build();
                EmergencyEvent savedEvent = emergencyRepository.save(escalationEvent);

                // Alert emergency contacts via SMS Gateway
                dispatchEscalationAlerts(journey.getUser(), savedEvent,
                        "OVERDUE SAFE WALK: " + journey.getUser().getName() + " did not reach " + journey.getDestination() + " on time.");
            }
        }
    }

    private void escalateMissedCheckIns(Instant now) {
        List<CheckIn> pendingCheckIns = checkInRepository.findByStatusAndScheduledTimeBefore("PENDING", now);

        for (CheckIn checkIn : pendingCheckIns) {
            Instant escalationDeadline = checkIn.getScheduledTime().plus(checkIn.getGracePeriodMinutes(), ChronoUnit.MINUTES);

            if (now.isAfter(escalationDeadline)) {
                log.warn("Escalating missed Safety Check-In for user: {}", checkIn.getUser().getName());

                checkIn.setStatus("ESCALATED");
                checkInRepository.save(checkIn);

                // Create emergency event
                EmergencyEvent escalationEvent = EmergencyEvent.builder()
                        .user(checkIn.getUser())
                        .eventType("CHECKIN_MISSED")
                        .status("ACTIVE")
                        .cancellationReason("Automated server escalation: Missed Safety Check-in")
                        .build();
                EmergencyEvent savedEvent = emergencyRepository.save(escalationEvent);

                // Alert emergency contacts
                dispatchEscalationAlerts(checkIn.getUser(), savedEvent,
                        "SAFETY ALERT: " + checkIn.getUser().getName() + " missed a scheduled safety check-in.");
            }
        }
    }

    private void dispatchEscalationAlerts(User user, EmergencyEvent event, String alertSummary) {
        List<EmergencyContact> contacts = contactRepository.findByUserIdOrderByPriorityAsc(user.getId());
        for (EmergencyContact contact : contacts) {
            if (contact.getNotifySms()) {
                smsGatewayService.dispatchEmergencySms(event, contact.getPhone(), user.getName(), alertSummary);
            }
        }
    }
}
