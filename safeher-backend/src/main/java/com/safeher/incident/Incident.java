package com.safeher.incident;

import com.safeher.emergency.EmergencyEvent;
import com.safeher.user.User;
import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.Instant;

@Entity
@Table(name = "incidents")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Incident {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "emergency_event_id")
    private EmergencyEvent emergencyEvent;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Column(name = "has_audio", nullable = false)
    @Builder.Default
    private Boolean hasAudio = false;

    @Column(name = "has_photo", nullable = false)
    @Builder.Default
    private Boolean hasPhoto = false;

    @Column(name = "local_file_uri", length = 500)
    private String localFileUri;

    @Column(name = "is_encrypted", nullable = false)
    @Builder.Default
    private Boolean isEncrypted = true;

    @CreationTimestamp
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
