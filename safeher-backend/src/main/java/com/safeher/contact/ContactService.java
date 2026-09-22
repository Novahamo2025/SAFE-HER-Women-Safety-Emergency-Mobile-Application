package com.safeher.contact;

import com.safeher.common.ResourceNotFoundException;
import com.safeher.contact.dto.ContactRequest;
import com.safeher.user.User;
import com.safeher.user.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class ContactService {

    private final ContactRepository contactRepository;
    private final UserRepository userRepository;

    public List<EmergencyContact> getUserContacts(Long userId) {
        return contactRepository.findByUserIdOrderByPriorityAsc(userId);
    }

    @Transactional
    public EmergencyContact addContact(Long userId, ContactRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));

        if (contactRepository.existsByUserIdAndPhone(userId, request.getPhone())) {
            throw new IllegalArgumentException("A contact with this phone number already exists");
        }

        EmergencyContact contact = EmergencyContact.builder()
                .user(user)
                .contactName(request.getContactName().trim())
                .phone(request.getPhone().trim())
                .relationship(request.getRelationship())
                .priority(request.getPriority())
                .notifySms(request.getNotifySms() != null ? request.getNotifySms() : true)
                .notifyPush(request.getNotifyPush() != null ? request.getNotifyPush() : true)
                .isVerified(false)
                .build();

        return contactRepository.save(contact);
    }

    @Transactional
    public EmergencyContact updateContact(Long userId, Long contactId, ContactRequest request) {
        EmergencyContact contact = contactRepository.findByIdAndUserId(contactId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Contact not found"));

        contact.setContactName(request.getContactName().trim());
        contact.setPhone(request.getPhone().trim());
        contact.setRelationship(request.getRelationship());
        contact.setPriority(request.getPriority());
        if (request.getNotifySms() != null) contact.setNotifySms(request.getNotifySms());
        if (request.getNotifyPush() != null) contact.setNotifyPush(request.getNotifyPush());

        return contactRepository.save(contact);
    }

    @Transactional
    public void deleteContact(Long userId, Long contactId) {
        EmergencyContact contact = contactRepository.findByIdAndUserId(contactId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Contact not found"));
        contactRepository.delete(contact);
    }
}
