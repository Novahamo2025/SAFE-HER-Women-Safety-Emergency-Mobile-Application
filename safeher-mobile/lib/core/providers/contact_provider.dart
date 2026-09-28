import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_model.dart';
import '../services/contact_service.dart';

class ContactProvider extends ChangeNotifier {
  final ContactApiService _service = ContactApiService();
  List<ContactModel> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ContactModel> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static const String _localContactsKey = 'safeher_saved_contacts';

  ContactProvider() {
    loadContacts();
  }

  Future<void> loadContacts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Try fetching from backend API
      final remoteContacts = await _service.getContacts();
      _contacts = remoteContacts;
      _sortContacts();
      await _cacheContactsLocally();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // 2. Fallback to cached local contacts
      final localContacts = await _getCachedContacts();
      if (localContacts.isNotEmpty) {
        _contacts = localContacts;
        _sortContacts();
      } else {
        // Initialize with default demo contacts for instant out-of-the-box readiness
        _contacts = [
          ContactModel(
            id: 1,
            contactName: 'Papa',
            phone: '+91 98765 43210',
            relationship: 'Father',
            priority: 1,
            notifySms: true,
            notifyPush: true,
            isVerified: true,
          ),
          ContactModel(
            id: 2,
            contactName: 'Mom',
            phone: '+91 98765 43211',
            relationship: 'Mother',
            priority: 2,
            notifySms: true,
            notifyPush: true,
            isVerified: true,
          ),
          ContactModel(
            id: 3,
            contactName: 'Priya (Best Friend)',
            phone: '+91 98765 43212',
            relationship: 'Friend',
            priority: 3,
            notifySms: true,
            notifyPush: false,
            isVerified: true,
          ),
        ];
        await _cacheContactsLocally();
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  void _sortContacts() {
    _contacts.sort((a, b) => a.priority.compareTo(b.priority));
  }

  Future<bool> addContact({
    required String name,
    required String phone,
    String? relationship,
    required int priority,
    bool notifySms = true,
    bool notifyPush = true,
  }) async {
    try {
      final newContactMap = {
        'contactName': name,
        'phone': phone,
        'relationship': relationship,
        'priority': priority,
        'notifySms': notifySms,
        'notifyPush': notifyPush,
      };

      try {
        final created = await _service.createContact(newContactMap);
        _contacts.add(created);
      } catch (_) {
        // Local fallback
        final localId = _contacts.isEmpty ? 1 : (_contacts.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1);
        final localContact = ContactModel(
          id: localId,
          contactName: name,
          phone: phone,
          relationship: relationship,
          priority: priority,
          notifySms: notifySms,
          notifyPush: notifyPush,
          isVerified: true,
        );
        _contacts.add(localContact);
      }

      _sortContacts();
      await _cacheContactsLocally();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add contact';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateContact(ContactModel contact) async {
    try {
      try {
        await _service.updateContact(contact.id, contact.toJson());
      } catch (_) {}

      final idx = _contacts.indexWhere((c) => c.id == contact.id);
      if (idx != -1) {
        _contacts[idx] = contact;
        _sortContacts();
        await _cacheContactsLocally();
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update contact';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteContact(int id) async {
    try {
      try {
        await _service.deleteContact(id);
      } catch (_) {}

      _contacts.removeWhere((c) => c.id == id);
      await _cacheContactsLocally();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete contact';
      notifyListeners();
      return false;
    }
  }

  Future<void> _cacheContactsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _contacts.map((c) => {
      'id': c.id,
      'contactName': c.contactName,
      'phone': c.phone,
      'relationship': c.relationship,
      'priority': c.priority,
      'notifySms': c.notifySms,
      'notifyPush': c.notifyPush,
      'isVerified': c.isVerified,
    }).toList();
    await prefs.setString(_localContactsKey, jsonEncode(jsonList));
  }

  Future<List<ContactModel>> _getCachedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localContactsKey);
    if (raw == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((item) => ContactModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }
}
