package com.safeher.contact;

import com.safeher.common.ApiResponse;
import com.safeher.contact.dto.ContactRequest;
import com.safeher.user.User;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/contacts")
@RequiredArgsConstructor
public class ContactController {

    private final ContactService contactService;

    @GetMapping
    public ResponseEntity<ApiResponse<List<EmergencyContact>>> listContacts(@AuthenticationPrincipal User user) {
        List<EmergencyContact> contacts = contactService.getUserContacts(user.getId());
        return ResponseEntity.ok(ApiResponse.ok(contacts, "Contacts retrieved successfully"));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<EmergencyContact>> createContact(
            @AuthenticationPrincipal User user,
            @Valid @RequestBody ContactRequest request) {
        EmergencyContact contact = contactService.addContact(user.getId(), request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok(contact, "Contact added successfully"));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<EmergencyContact>> updateContact(
            @AuthenticationPrincipal User user,
            @PathVariable Long id,
            @Valid @RequestBody ContactRequest request) {
        EmergencyContact contact = contactService.updateContact(user.getId(), id, request);
        return ResponseEntity.ok(ApiResponse.ok(contact, "Contact updated successfully"));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<ApiResponse<Void>> deleteContact(
            @AuthenticationPrincipal User user,
            @PathVariable Long id) {
        contactService.deleteContact(user.getId(), id);
        return ResponseEntity.ok(ApiResponse.ok(null, "Contact deleted successfully"));
    }
}
