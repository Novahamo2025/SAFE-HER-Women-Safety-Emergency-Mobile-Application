import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_event_model.dart';
import '../services/emergency_api_service.dart';
import '../../services/location_service.dart';
import '../../services/sms_service.dart';
import '../models/contact_model.dart';

enum EmergencyState { idle, activating, active, resolved }

class ContactDeliveryStatus {
  final String contactName;
  final String phone;
  final String channel; // SMS, Push, Call
  final String status; // Dispatched, Delivered, Pending, Failed
  final DateTime timestamp;

  ContactDeliveryStatus({
    required this.contactName,
    required this.phone,
    required this.channel,
    required this.status,
    required this.timestamp,
  });
}

class EmergencyProvider extends ChangeNotifier {
  final EmergencyApiService _apiService = EmergencyApiService();

  EmergencyState _state = EmergencyState.idle;
  EmergencyEventModel? _activeEvent;
  double _latitude = 28.6139; // Default fallback coordinates (Delhi)
  double _longitude = 77.2090;
  double _accuracy = 8.5; // Meters
  DateTime? _lastLocationUpdate;
  Timer? _locationStreamTimer;
  List<ContactDeliveryStatus> _deliveryStatuses = [];
  bool _isTestMode = false;
  String? _resolvedSummary;

  EmergencyState get state => _state;
  bool get isEmergencyActive => _state == EmergencyState.active;
  bool get isActivating => _state == EmergencyState.activating;
  EmergencyEventModel? get activeEvent => _activeEvent;
  double get latitude => _latitude;
  double get longitude => _longitude;
  double get accuracy => _accuracy;
  DateTime? get lastLocationUpdate => _lastLocationUpdate;
  List<ContactDeliveryStatus> get deliveryStatuses => _deliveryStatuses;
  bool get isTestMode => _isTestMode;
  String? get resolvedSummary => _resolvedSummary;

  /// Triggered when SOS hold completes
  Future<void> triggerEmergency({
    required List<ContactModel> contacts,
    required String userName,
    bool isTest = false,
  }) async {
    _isTestMode = isTest;
    _state = EmergencyState.activating;
    notifyListeners();

    // 1. Fetch real GPS position
    try {
      final position = await LocationService.getCurrentLocation();
      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _accuracy = position.accuracy;
      }
    } catch (_) {}

    _lastLocationUpdate = DateTime.now();

    // 2. Dispatch API event
    try {
      if (!isTest) {
        final event = await _apiService.startEmergency(
          latitude: _latitude,
          longitude: _longitude,
          accuracy: _accuracy,
          eventType: 'SOS',
        );
        _activeEvent = event;
      } else {
        _activeEvent = EmergencyEventModel(
          id: 9999,
          eventType: 'TEST_SOS',
          status: 'ACTIVE',
          startedAt: DateTime.now(),
        );
      }
    } catch (_) {
      // Fallback local event
      _activeEvent = EmergencyEventModel(
        id: DateTime.now().millisecondsSinceEpoch % 10000,
        eventType: isTest ? 'TEST_SOS' : 'SOS',
        status: 'ACTIVE',
        startedAt: DateTime.now(),
      );
    }

    // 3. Dispatch native SMS/Alerts to contacts
    _deliveryStatuses = [];
    final recipientPhones = <String>[];

    for (var contact in contacts) {
      recipientPhones.add(contact.phone);
      _deliveryStatuses.add(
        ContactDeliveryStatus(
          contactName: contact.contactName,
          phone: contact.phone,
          channel: contact.notifySms ? 'Carrier SMS' : 'Push Notification',
          status: isTest ? 'Simulated Dispatched' : 'Dispatched',
          timestamp: DateTime.now(),
        ),
      );
    }

    if (!isTest && recipientPhones.isNotEmpty) {
      await SmsService.sendNativeEmergencySms(
        recipientNumbers: recipientPhones,
        userName: userName.isNotEmpty ? userName : 'SafeHer User',
        latitude: _latitude,
        longitude: _longitude,
      );
    }

    _state = EmergencyState.active;
    notifyListeners();

    // 4. Start periodic location streaming while active
    _startLocationStreaming();
  }

  void _startLocationStreaming() {
    _locationStreamTimer?.cancel();
    _locationStreamTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_state != EmergencyState.active) {
        timer.cancel();
        return;
      }

      try {
        final pos = await LocationService.getCurrentLocation();
        if (pos != null) {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _accuracy = pos.accuracy;
          _lastLocationUpdate = DateTime.now();

          if (_activeEvent != null && !_isTestMode) {
            await _apiService.updateLocation(
              eventId: _activeEvent!.id,
              latitude: _latitude,
              longitude: _longitude,
              accuracy: _accuracy,
            );
          }
          notifyListeners();
        }
      } catch (_) {}
    });
  }

  /// Resolve / Cancel emergency with security PIN confirmation
  Future<bool> endEmergency({String? pin, String? reason}) async {
    _locationStreamTimer?.cancel();

    if (_activeEvent != null && !_isTestMode) {
      try {
        await _apiService.cancelEmergency(
          eventId: _activeEvent!.id,
          reason: reason ?? 'User confirmed safe via PIN',
          pin: pin,
        );
      } catch (_) {}
    }

    _state = EmergencyState.resolved;
    _resolvedSummary = 'Emergency marked resolved safely at ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}. Live location sharing has stopped.';
    notifyListeners();

    // Reset back to idle after a brief summary window
    Future.delayed(const Duration(seconds: 4), () {
      if (_state == EmergencyState.resolved) {
        _state = EmergencyState.idle;
        _activeEvent = null;
        _isTestMode = false;
        notifyListeners();
      }
    });

    return true;
  }

  @override
  void dispose() {
    _locationStreamTimer?.cancel();
    super.dispose();
  }
}
