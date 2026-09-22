package com.safeher.admin.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DashboardStatsResponse {
    private long activeSosCount;
    private long activeJourneysCount;
    private long pendingCheckinsCount;
    private long totalUsersCount;
    private long failedDeliveriesCount;
}
