package com.safeher.emergency;

import com.safeher.contact.ContactRepository;
import com.safeher.contact.EmergencyContact;
import com.safeher.emergency.dto.EmergencyCancelRequest;
import com.safeher.emergency.dto.EmergencyEventResponse;
import com.safeher.emergency.dto.EmergencyStartRequest;
import com.safeher.emergency.dto.LocationUpdateRequest;
import com.safeher.location.LocationRepository;
import com.safeher.location.LocationUpdate;
import com.safeher.notification.NotificationDelivery;
import com.safeher.notification.NotificationDeliveryRepository;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
class EmergencyServiceTest {

    @Autowired
    private EmergencyService emergencyService;

    @Autowired
    private EmergencyRepository emergencyRepository;

    @Autowired
    private LocationRepository locationRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ContactRepository contactRepository;

    @Autowired
    private NotificationDeliveryRepository deliveryRepository;

    @Autowired
    private com.safeher.security.RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private org.springframework.security.crypto.password.PasswordEncoder passwordEncoder;

    private User testUser;
    private EmergencyContact testContact;

    @BeforeEach
    void setUp() {
        deliveryRepository.deleteAll();
        locationRepository.deleteAll();
        emergencyRepository.deleteAll();
        contactRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();

        String uid = UUID.randomUUID().toString().substring(0, 6);
        testUser = userRepository.save(User.builder()
                .name("Priya Sharma")
                .email("priya_" + uid + "@example.com")
                .phone("+9197" + uid)
                .passwordHash("hashed_pwd")
                .pinHash(passwordEncoder.encode("1234"))
                .role("ROLE_USER")
                .accountStatus("ACTIVE")
                .isVerified(true)
                .build());

        testContact = contactRepository.save(EmergencyContact.builder()
                .user(testUser)
                .contactName("Papa")
                .phone("+9191" + uid)
                .relationship("Father")
                .priority(1)
                .notifySms(true)
                .notifyPush(true)
                .isVerified(true)
                .build());
    }

    @Test
    void testStartEmergency_CreatesEventAndAlertsContacts() {
        String uuidKey = UUID.randomUUID().toString();
        EmergencyStartRequest request = new EmergencyStartRequest();
        request.setEventType("SOS");
        request.setLatitude(new BigDecimal("28.6139000"));
        request.setLongitude(new BigDecimal("77.2090000"));
        request.setAccuracyMeters(new BigDecimal("8.5"));
        request.setIdempotencyKey(uuidKey);

        EmergencyEventResponse response = emergencyService.startEmergency(testUser.getId(), request);

        assertThat(response).isNotNull();
        assertThat(response.getId()).isNotNull();
        assertThat(response.getStatus()).isEqualTo("ACTIVE");
        assertThat(response.getEventType()).isEqualTo("SOS");
        assertThat(response.getIdempotencyKey()).isEqualTo(uuidKey);

        // Verify initial location update was saved
        List<LocationUpdate> locations = locationRepository.findByEmergencyEventIdOrderByRecordedAtAsc(response.getId());
        assertThat(locations).hasSize(1);
        assertThat(locations.get(0).getLatitude()).isEqualByComparingTo("28.6139000");

        // Verify trusted contact SMS notification was dispatched
        List<NotificationDelivery> deliveries = deliveryRepository.findByEmergencyEventIdOrderBySentAtDesc(response.getId());
        assertThat(deliveries).hasSize(1);
        assertThat(deliveries.get(0).getRecipientPhone()).isEqualTo(testContact.getPhone());
        assertThat(deliveries.get(0).getStatus()).isEqualTo("DELIVERED");
    }

    @Test
    void testStartEmergency_Idempotent_PreventsDuplicates() {
        String uuidKey = "sos-idempotency-" + UUID.randomUUID();
        EmergencyStartRequest request = new EmergencyStartRequest();
        request.setEventType("SOS");
        request.setLatitude(new BigDecimal("28.6139000"));
        request.setLongitude(new BigDecimal("77.2090000"));
        request.setAccuracyMeters(new BigDecimal("8.5"));
        request.setIdempotencyKey(uuidKey);

        // First call
        EmergencyEventResponse firstResponse = emergencyService.startEmergency(testUser.getId(), request);

        // Immediate retry call with same idempotency key (simulating network drop / multi-tap)
        EmergencyEventResponse secondResponse = emergencyService.startEmergency(testUser.getId(), request);

        assertThat(secondResponse.getId()).isEqualTo(firstResponse.getId());
        assertThat(emergencyRepository.findAll()).hasSize(1);
    }

    @Test
    void testUpdateLocation_AppendsLocationBreadcrumb() {
        String uuidKey = UUID.randomUUID().toString();
        EmergencyStartRequest startReq = new EmergencyStartRequest();
        startReq.setLatitude(new BigDecimal("28.6139000"));
        startReq.setLongitude(new BigDecimal("77.2090000"));
        startReq.setIdempotencyKey(uuidKey);

        EmergencyEventResponse event = emergencyService.startEmergency(testUser.getId(), startReq);

        LocationUpdateRequest locReq = new LocationUpdateRequest();
        locReq.setLatitude(new BigDecimal("28.6145000"));
        locReq.setLongitude(new BigDecimal("77.2098000"));
        locReq.setAccuracyMeters(new BigDecimal("5.0"));

        emergencyService.updateLocation(testUser.getId(), event.getId(), locReq);

        List<LocationUpdate> updates = locationRepository.findByEmergencyEventIdOrderByRecordedAtAsc(event.getId());
        assertThat(updates).hasSize(2);
        assertThat(updates.get(1).getLatitude()).isEqualByComparingTo("28.6145000");
    }

    @Test
    void testCancelEmergency_TransitionsStateAndClosesSession() {
        EmergencyStartRequest startReq = new EmergencyStartRequest();
        startReq.setLatitude(new BigDecimal("28.6139000"));
        startReq.setLongitude(new BigDecimal("77.2090000"));
        startReq.setIdempotencyKey(UUID.randomUUID().toString());

        EmergencyEventResponse event = emergencyService.startEmergency(testUser.getId(), startReq);

        EmergencyCancelRequest cancelReq = new EmergencyCancelRequest();
        cancelReq.setReason("User confirmed safe via PIN");
        cancelReq.setPin("1234");

        EmergencyEventResponse cancelled = emergencyService.cancelEmergency(testUser.getId(), event.getId(), cancelReq);

        assertThat(cancelled.getStatus()).isEqualTo("CANCELLED");
        assertThat(cancelled.getEndedAt()).isNotNull();
        assertThat(cancelled.getCancellationReason()).isEqualTo("User confirmed safe via PIN");
    }

    @Test
    void testCancelEmergency_RejectsInvalidPin() {
        EmergencyStartRequest startReq = new EmergencyStartRequest();
        startReq.setLatitude(new BigDecimal("28.6139000"));
        startReq.setLongitude(new BigDecimal("77.2090000"));
        startReq.setIdempotencyKey(UUID.randomUUID().toString());

        EmergencyEventResponse event = emergencyService.startEmergency(testUser.getId(), startReq);

        EmergencyCancelRequest wrongPinReq = new EmergencyCancelRequest();
        wrongPinReq.setReason("Test");
        wrongPinReq.setPin("9999");

        assertThatThrownBy(() -> emergencyService.cancelEmergency(testUser.getId(), event.getId(), wrongPinReq))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("Invalid security PIN");
    }
}
