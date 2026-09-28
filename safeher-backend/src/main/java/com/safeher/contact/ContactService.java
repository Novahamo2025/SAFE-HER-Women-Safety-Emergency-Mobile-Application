package com.safeher.contact;

import com.safeher.common.ResourceNotFoundException;
import com.safeher.contact.dto.ContactRequest;
import com.safeher.contact.dto.ContactResponse;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ContactService {

    private final ContactRepository contactRepository;
    private final UserRepository userRepository;

    @Value("${app.contacts.max-per-user:10}")
    private int maxContactsPerUser;

    public List<ContactResponse> getUserContacts(Long userId) {
        return contactRepository.findByUserIdOrderByPriorityAsc(userId)
                .stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    public ContactResponse getContact(Long userId, Long contactId) {
        EmergencyContact contact = contactRepository.findByIdAndUserId(contactId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Contact not found"));
        return toResponse(contact);
    }

    @Transactional
    public ContactResponse addContact(Long userId, ContactRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        // Enforce contact limit
        long currentCount = contactRepository.countByUserId(userId);
        if (currentCount >= maxContactsPerUser) {
            throw new IllegalArgumentException(
                    String.format("Maximum number of contacts (%d) reached", maxContactsPerUser));
        }

        String normalizedPhone = normalizePhone(request.getPhone());

        if (contactRepository.existsByUserIdAndPhone(userId, normalizedPhone)) {
            throw new IllegalArgumentException("A contact with this phone number already exists");
        }

        EmergencyContact contact = EmergencyContact.builder()
                .user(user)
                .contactName(request.getContactName().trim())
                .phone(normalizedPhone)
                .relationship(request.getRelationship())
                .priority(request.getPriority())
                .notifySms(request.getNotifySms() != null ? request.getNotifySms() : true)
                .notifyPush(request.getNotifyPush() != null ? request.getNotifyPush() : true)
                .isVerified(false)
                .build();

        EmergencyContact saved = contactRepository.save(contact);
        return toResponse(saved);
    }

    @Transactional
    public ContactResponse updateContact(Long userId, Long contactId, ContactRequest request) {
        EmergencyContact contact = contactRepository.findByIdAndUserId(contactId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Contact not found"));

        String normalizedPhone = normalizePhone(request.getPhone());

        // Check for duplicate phone (different contact, same user)
        if (!contact.getPhone().equals(normalizedPhone) &&
                contactRepository.existsByUserIdAndPhone(userId, normalizedPhone)) {
            throw new IllegalArgumentException("A contact with this phone number already exists");
        }

        contact.setContactName(request.getContactName().trim());
        contact.setPhone(normalizedPhone);
        contact.setRelationship(request.getRelationship());
        contact.setPriority(request.getPriority());
        if (request.getNotifySms() != null) contact.setNotifySms(request.getNotifySms());
        if (request.getNotifyPush() != null) contact.setNotifyPush(request.getNotifyPush());

        EmergencyContact saved = contactRepository.save(contact);
        return toResponse(saved);
    }

    @Transactional
    public void deleteContact(Long userId, Long contactId) {
        EmergencyContact contact = contactRepository.findByIdAndUserId(contactId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Contact not found"));
        contactRepository.delete(contact);
    }

    // --- Private helpers ---

    private String normalizePhone(String phone) {
        if (phone == null) return null;
        String cleaned = phone.trim().replaceAll("[\\s\\-()]", "");
        if (cleaned.matches("^[6-9]\\d{9}$")) {
            cleaned = "+91" + cleaned;
        }
        return cleaned;
    }

    private ContactResponse toResponse(EmergencyContact contact) {
        return ContactResponse.builder()
                .id(contact.getId())
                .contactName(contact.getContactName())
                .phone(contact.getPhone())
                .relationship(contact.getRelationship())
                .priority(contact.getPriority())
                .notifySms(contact.getNotifySms())
                .notifyPush(contact.getNotifyPush())
                .isVerified(contact.getIsVerified())
                .createdAt(contact.getCreatedAt())
                .updatedAt(contact.getUpdatedAt())
                .build();
    }
}
