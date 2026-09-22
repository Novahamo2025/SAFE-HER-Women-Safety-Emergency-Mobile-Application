package com.safeher.contact.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class ContactRequest {

    @NotBlank(message = "Contact name is required")
    private String contactName;

    @NotBlank(message = "Phone number is required")
    @Pattern(regexp = "^\\+?[0-9]{10,15}$", message = "Phone must be a valid number")
    private String phone;

    private String relationship;

    @NotNull(message = "Priority is required")
    private Integer priority;

    private Boolean notifySms = true;
    private Boolean notifyPush = true;
}
