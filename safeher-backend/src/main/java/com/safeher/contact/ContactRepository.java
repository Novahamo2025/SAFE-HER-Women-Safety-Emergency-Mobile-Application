package com.safeher.contact;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface ContactRepository extends JpaRepository<EmergencyContact, Long> {
    List<EmergencyContact> findByUserIdOrderByPriorityAsc(Long userId);
    Optional<EmergencyContact> findByIdAndUserId(Long id, Long userId);
    boolean existsByUserIdAndPhone(Long userId, String phone);
    long countByUserId(Long userId);
}
