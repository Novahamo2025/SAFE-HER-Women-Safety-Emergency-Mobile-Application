package com.safeher.otp.repository;

import com.safeher.otp.model.OtpStatus;
import com.safeher.otp.model.OtpVerification;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface OtpVerificationRepository extends JpaRepository<OtpVerification, Long> {

    Optional<OtpVerification> findByPhoneAndPurposeAndStatus(String phone, String purpose, OtpStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT o FROM OtpVerification o WHERE o.phone = :phone AND o.purpose = :purpose AND o.status = :status")
    Optional<OtpVerification> findByPhoneAndPurposeAndStatusForUpdate(@Param("phone") String phone,
                                                                     @Param("purpose") String purpose,
                                                                     @Param("status") OtpStatus status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT o FROM OtpVerification o WHERE o.id = :id")
    Optional<OtpVerification> findByIdForUpdate(@Param("id") Long id);

    List<OtpVerification> findByPhoneAndPurposeAndStatusOrderByCreatedAtDesc(String phone, String purpose, OtpStatus status);

    List<OtpVerification> findByPhoneAndStatus(String phone, OtpStatus status);

    Optional<OtpVerification> findTopByPhoneAndPurposeOrderByCreatedAtDesc(String phone, String purpose);
}
