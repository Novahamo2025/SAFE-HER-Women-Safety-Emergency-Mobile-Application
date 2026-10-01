package com.safeher.admin;

import com.safeher.admin.dto.DashboardStatsResponse;
import com.safeher.admin.dto.AdminDashboardData;
import com.safeher.common.ApiResponse;
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
    public ResponseEntity<ApiResponse<List<AdminDashboardData.Emergency>>> getActiveEmergencies() {
        List<AdminDashboardData.Emergency> emergencies = adminService.getActiveEmergencies();
        return ResponseEntity.ok(ApiResponse.ok(emergencies, "Active emergency events retrieved"));
    }

    @GetMapping("/journeys")
    public ResponseEntity<ApiResponse<List<AdminDashboardData.Journey>>> getJourneys() {
        return ResponseEntity.ok(ApiResponse.ok(adminService.getJourneys(), "Safe journeys retrieved"));
    }

    @GetMapping("/checkins")
    public ResponseEntity<ApiResponse<List<AdminDashboardData.CheckIn>>> getCheckIns() {
        return ResponseEntity.ok(ApiResponse.ok(adminService.getCheckIns(), "Check-ins retrieved"));
    }

    @GetMapping("/contacts")
    public ResponseEntity<ApiResponse<List<AdminDashboardData.Contact>>> getContacts() {
        return ResponseEntity.ok(ApiResponse.ok(adminService.getContacts(), "Emergency contacts retrieved"));
    }

    @GetMapping("/deliveries")
    public ResponseEntity<ApiResponse<List<AdminDashboardData.Delivery>>> getDeliveries() {
        List<AdminDashboardData.Delivery> deliveries = adminService.getDeliveries();
        return ResponseEntity.ok(ApiResponse.ok(deliveries, "Notification deliveries retrieved"));
    }

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<List<AdminDashboardData.User>>> getUsers() {
        List<AdminDashboardData.User> users = adminService.getAllUsers();
        return ResponseEntity.ok(ApiResponse.ok(users, "User accounts retrieved"));
    }
}
