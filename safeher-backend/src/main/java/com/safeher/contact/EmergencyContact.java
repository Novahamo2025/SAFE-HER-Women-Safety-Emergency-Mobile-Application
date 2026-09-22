package com.safeher.contact;

import com.safeher.user.User;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "emergency_contacts")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EmergencyContact {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "contact_name", nullable = false, length = 100)
    private String contactName;

    @Column(nullable = false, length = 20)
    private String phone;

    @Column(length = 50)
    private String relationship;

    @Column(nullable = false)
    @Builder.Default
    private Integer priority = 1;

    @Column(name = "notify_sms", nullable = false)
    @Builder.Default
    private Boolean notifySms = true;

    @Column(name = "notify_push", nullable = false)
    @Builder.Default
    private Boolean notifyPush = true;

    @Column(name = "is_verified", nullable = false)
    @Builder.Default
    private Boolean isVerified = false;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
