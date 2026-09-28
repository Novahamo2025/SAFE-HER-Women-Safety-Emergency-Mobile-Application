package com.safeher.contact.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ContactResponse {
    private Long id;
    private String contactName;
    private String phone;
    private String relationship;
    private Integer priority;
    private Boolean notifySms;
    private Boolean notifyPush;
    private Boolean isVerified;
    private Instant createdAt;
    private Instant updatedAt;
}
