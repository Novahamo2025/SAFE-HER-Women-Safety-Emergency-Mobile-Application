package com.safeher.admin;

import com.safeher.admin.dto.DashboardStatsResponse;
import com.safeher.common.ApiResponse;
import com.safeher.emergency.EmergencyEvent;
import com.safeher.notification.NotificationDelivery;
import com.safeher.user.User;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/admin")
@RequiredArgsConstructor
public class AdminController {

    private final AdminService adminService;

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<DashboardStatsResponse>> getStats() {
        DashboardStatsResponse stats = adminService.getOverviewStats();
        return ResponseEntity.ok(ApiResponse.ok(stats, "Overview statistics retrieved"));
    }

    @GetMapping("/emergencies")
    public ResponseEntity<ApiResponse<List<EmergencyEvent>>> getActiveEmergencies() {
        List<EmergencyEvent> emergencies = adminService.getActiveEmergencies();
        return ResponseEntity.ok(ApiResponse.ok(emergencies, "Active emergency events retrieved"));
    }

    @GetMapping("/deliveries")
    public ResponseEntity<ApiResponse<List<NotificationDelivery>>> getDeliveries() {
        List<NotificationDelivery> deliveries = adminService.getDeliveries();
        return ResponseEntity.ok(ApiResponse.ok(deliveries, "Notification deliveries retrieved"));
    }

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<List<User>>> getUsers() {
        List<User> users = adminService.getAllUsers();
        return ResponseEntity.ok(ApiResponse.ok(users, "User accounts retrieved"));
    }
}
