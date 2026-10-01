package com.safeher.checkin;

import com.safeher.checkin.dto.CheckInCreateRequest;
import com.safeher.common.ResourceNotFoundException;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@RequiredArgsConstructor
public class CheckInService {

    private final CheckInRepository checkInRepository;
    private final UserRepository userRepository;

    public List<CheckIn> getUserCheckIns(Long userId) {
        return checkInRepository.findByUserIdOrderByScheduledTimeDesc(userId);
    }

    @Transactional
    public CheckIn createCheckIn(Long userId, CheckInCreateRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        CheckIn checkIn = CheckIn.builder()
                .user(user)
                .scheduledTime(request.getScheduledTime())
                .gracePeriodMinutes(request.getGracePeriodMinutes() != null ? request.getGracePeriodMinutes() : 5)
                .status("PENDING")
                .build();

        return checkInRepository.save(checkIn);
    }

    @Transactional
    public CheckIn completeCheckIn(Long userId, Long checkInId) {
        CheckIn checkIn = checkInRepository.findByIdAndUserId(checkInId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Check-in not found"));

        checkIn.setStatus("COMPLETED");
        checkIn.setCompletedAt(Instant.now());
        return checkInRepository.save(checkIn);
    }

    @Transactional
    public CheckIn markMissed(Long userId, Long checkInId) {
        return updateStatus(userId, checkInId, "MISSED");
    }

    @Transactional
    public CheckIn escalate(Long userId, Long checkInId) {
        return updateStatus(userId, checkInId, "ESCALATED");
    }

    @Transactional
    public CheckIn cancel(Long userId, Long checkInId) {
        return updateStatus(userId, checkInId, "CANCELLED");
    }

    private CheckIn updateStatus(Long userId, Long checkInId, String status) {
        CheckIn checkIn = checkInRepository.findByIdAndUserId(checkInId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Check-in not found"));
        checkIn.setStatus(status);
        return checkInRepository.save(checkIn);
    }
}
