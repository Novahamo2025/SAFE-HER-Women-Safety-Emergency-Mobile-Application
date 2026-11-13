import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/emergency_event_model.dart';
import '../services/emergency_api_service.dart';
import '../services/emergency_foreground_service.dart';
import '../services/location_autosave_service.dart';
import '../services/sos_persistence_service.dart';
import '../../services/location_service.dart';
import '../../services/sms_service.dart';
import '../models/contact_model.dart';

enum EmergencyState {
  idle,
  activating,
  active,
  networkOffline,
  locationUnavailable,
  cancelling,
  cancelled,
  error,
  resolved,
}

class ContactDeliveryStatus {
  final String contactName;
  final String phone;
  final String channel; // Carrier SMS, Push Notification
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
  String? _idempotencyKey;
  double _latitude = 28.6139; // Default fallback coordinates (Delhi)
  double _longitude = 77.2090;
  double _accuracy = 8.5; // Meters
  bool _isLocationFresh = false;
  DateTime? _lastLocationUpdate;
  Timer? _stationaryLocationTimer;
  StreamSubscription<Position>? _distanceStreamSubscription;
  List<ContactDeliveryStatus> _deliveryStatuses = [];
  bool _isTestMode = false;
  String? _resolvedSummary;
  String? _errorMessage;

  EmergencyState get state => _state;
  bool get isEmergencyActive =>
      _state == EmergencyState.active ||
      _state == EmergencyState.networkOffline ||
      _state == EmergencyState.locationUnavailable;
  bool get isActivating => _state == EmergencyState.activating;
  bool get isCancelling => _state == EmergencyState.cancelling;
  bool get isNetworkOffline => _state == EmergencyState.networkOffline;
  bool get isLocationUnavailable => _state == EmergencyState.locationUnavailable;
  bool get isLocationFresh => _isLocationFresh;
  String? get idempotencyKey => _idempotencyKey;
  EmergencyEventModel? get activeEvent => _activeEvent;
  double get latitude => _latitude;
  double get longitude => _longitude;
  double get accuracy => _accuracy;
  DateTime? get lastLocationUpdate => _lastLocationUpdate;
  List<ContactDeliveryStatus> get deliveryStatuses => _deliveryStatuses;
  bool get isTestMode => _isTestMode;
  String? get resolvedSummary => _resolvedSummary;
  String? get errorMessage => _errorMessage;

  /// Triggered when SOS button is pressed (Section 2, 13, 14a)
  Future<void> triggerEmergency({
    required List<ContactModel> contacts,
    required String userName,
    bool isTest = false,
  }) async {
    // 1. Prevent duplicate triggers (Multi-tap idempotency protection - Section 14)
    if (_state == EmergencyState.activating || isEmergencyActive) {
      debugPrint('[EmergencyProvider] Duplicate trigger rejected. Current state: $_state');
      return;
    }

    // 2. Generate client-side UUID idempotency key before any network call (Section 14a)
    _idempotencyKey = const Uuid().v4();
    _isTestMode = isTest;
    _errorMessage = null;

    // 3. Immediately lock button and display ACTIVATING state (Section 2 & 20)
    _state = EmergencyState.activating;
    notifyListeners();
    debugPrint('[EmergencyProvider] SOS activating with idempotency key: $_idempotencyKey');

    // 4. Obtain FRESH GPS fix with bounded 10s timeout — strictly no stale getLastKnownPosition()
    _isLocationFresh = false;
    try {
      final position = await LocationService.getFreshCurrentLocation(
        timeLimit: const Duration(seconds: 10),
      );

      if (position != null) {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _accuracy = position.accuracy;
        _isLocationFresh = true;
      } else {
        // Fallback to locally auto-saved record per Section 2a & 12
        final saved = await LocationAutoSaveService.getLastSavedLocation();
        if (saved != null) {
          _latitude = saved.latitude;
          _longitude = saved.longitude;
          _accuracy = saved.accuracy;
          _isLocationFresh = false;
          debugPrint('[EmergencyProvider] Using auto-saved location (non-fresh)');
        }
      }
    } catch (e) {
      debugPrint('[EmergencyProvider] Error acquiring location: $e');
      final saved = await LocationAutoSaveService.getLastSavedLocation();
      if (saved != null) {
        _latitude = saved.latitude;
        _longitude = saved.longitude;
        _accuracy = saved.accuracy;
        _isLocationFresh = false;
      }
    }

    _lastLocationUpdate = DateTime.now();

    // 5. Synchronously persist active SOS state for crash recovery (Section 16a)
    final initialId = DateTime.now().millisecondsSinceEpoch % 100000;
    await SosPersistenceService.saveActiveSession(
      emergencyId: initialId,
      idempotencyKey: _idempotencyKey!,
      startedAt: DateTime.now(),
      latitude: _latitude,
      longitude: _longitude,
      accuracy: _accuracy,
    );

    // 6. Start Android Foreground Service (Section 4 & 5)
    try {
      await EmergencyForegroundServiceManager.startEmergencyTrackingService();
    } catch (e) {
      debugPrint('[EmergencyProvider] Foreground service start error: $e');
    }

    // 7. Dispatch to Backend API with Idempotency Key (Section 7 & 14a)
    try {
      if (!isTest) {
        final event = await _apiService.startEmergency(
          latitude: _latitude,
          longitude: _longitude,
          accuracy: _accuracy,
          eventType: 'SOS',
          clientEventUuid: _idempotencyKey,
        );
        _activeEvent = event;

        // Update persisted session with backend-assigned ID
        await SosPersistenceService.saveActiveSession(
          emergencyId: event.id,
          idempotencyKey: _idempotencyKey!,
          startedAt: event.startedAt ?? DateTime.now(),
          latitude: _latitude,
          longitude: _longitude,
          accuracy: _accuracy,
        );
      } else {
        _activeEvent = EmergencyEventModel(
          id: 9999,
          eventType: 'TEST_SOS',
          status: 'ACTIVE',
          startedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('[EmergencyProvider] Backend SOS creation error (proceeding in local active mode): $e');
      _activeEvent = EmergencyEventModel(
        id: initialId,
        eventType: isTest ? 'TEST_SOS' : 'SOS',
        status: 'ACTIVE',
        startedAt: DateTime.now(),
      );
    }

    // 8. Trusted Emergency Contact Alerting (Section 8 & 9)
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
      try {
        await SmsService.sendNativeEmergencySms(
          recipientNumbers: recipientPhones,
          userName: userName.isNotEmpty ? userName : 'SvaShield User',
          latitude: _latitude,
          longitude: _longitude,
        );
      } catch (e) {
        debugPrint('[EmergencyProvider] Native SMS dispatch error: $e');
      }
    }

    // 9. Transition to Active state
    if (!_isLocationFresh) {
      _state = EmergencyState.locationUnavailable;
    } else {
      _state = EmergencyState.active;
    }
    notifyListeners();

    // 10. Start continuous dual location tracking (Section 6)
    _startDualLocationTracking();
  }

  /// Dual update strategy: distance filter (15m) OR time interval (8-10s) (Section 6)
  void _startDualLocationTracking() {
    _stopLocationListeners();

    // 1. Distance filter stream: triggers when user moves 15-20m
    try {
      _distanceStreamSubscription = LocationService.getPositionStream(
        distanceFilter: 15,
      ).listen((Position pos) {
        _onNewLocationFix(pos, source: 'DISTANCE');
      }, onError: (err) {
        debugPrint('[EmergencyProvider] Distance stream error: $err');
      });
    } catch (e) {
      debugPrint('[EmergencyProvider] Failed to attach distance stream: $e');
    }

    // 2. Periodic timer (9 seconds): triggers for stationary / incapacitated users (Section 6)
    _stationaryLocationTimer = Timer.periodic(const Duration(seconds: 9), (timer) async {
      if (!isEmergencyActive) {
        timer.cancel();
        return;
      }

      try {
        final pos = await LocationService.getFreshCurrentLocation(
          timeLimit: const Duration(seconds: 6),
        );
        if (pos != null) {
          _onNewLocationFix(pos, source: 'TIMER');
        }
      } catch (e) {
        debugPrint('[EmergencyProvider] Periodic location tick error: $e');
      }
    });
  }

  void _onNewLocationFix(Position pos, {required String source}) async {
    _latitude = pos.latitude;
    _longitude = pos.longitude;
    _accuracy = pos.accuracy;
    _isLocationFresh = true;
    _lastLocationUpdate = DateTime.now();

    if (_state == EmergencyState.locationUnavailable) {
      _state = EmergencyState.active;
    }

    // Auto-save locally (Section 2a)
    await LocationAutoSaveService.saveLocation(
      latitude: _latitude,
      longitude: _longitude,
      accuracy: _accuracy,
      timestamp: pos.timestamp,
    );

    // Sync to backend if active
    if (_activeEvent != null && !_isTestMode) {
      try {
        await _apiService.updateLocation(
          eventId: _activeEvent!.id,
          latitude: _latitude,
          longitude: _longitude,
          accuracy: _accuracy,
        );
      } catch (e) {
        debugPrint('[EmergencyProvider] Failed to push location update: $e');
      }
    }

    notifyListeners();
  }

  /// Cancel SOS (Section 15, Phase 1 P0)
  Future<bool> endEmergency({String? pin, String? reason}) async {
    // 1. Prevent duplicate cancellation submissions while a request is in progress
    if (_state == EmergencyState.cancelling) {
      debugPrint('[EmergencyProvider] Cancellation already in progress. Ignoring duplicate.');
      return false;
    }

    final previousState = _state;
    _state = EmergencyState.cancelling;
    _errorMessage = null;
    notifyListeners();

    // 2. If it's a real active event on backend, require backend confirmation BEFORE stopping tracking
    if (_activeEvent != null && !_isTestMode) {
      try {
        await _apiService.cancelEmergency(
          eventId: _activeEvent!.id,
          reason: reason ?? 'User marked safe',
          pin: pin,
        );
      } catch (e) {
        debugPrint('[EmergencyProvider] Backend cancel call failed: $e');
        // Restore active state, preserve foreground tracking & session recovery!
        _state = previousState == EmergencyState.cancelling ? EmergencyState.active : previousState;
        _errorMessage = 'Failed to end emergency: ${e.toString().replaceAll('Exception:', '').trim()}';
        notifyListeners();
        return false;
      }
    }

    // 3. Backend confirmed (or test mode): now safely stop foreground tracking and clear persisted session
    _stopLocationListeners();

    try {
      await EmergencyForegroundServiceManager.stopEmergencyTrackingService();
    } catch (e) {
      debugPrint('[EmergencyProvider] Error stopping foreground service: $e');
    }

    await SosPersistenceService.clearActiveSession();

    _state = EmergencyState.resolved;
    _resolvedSummary =
        'Emergency cancelled safely at ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}. Live location sharing stopped.';
    notifyListeners();

    // Transition back to idle
    Future.delayed(const Duration(seconds: 4), () {
      if (_state == EmergencyState.resolved) {
        _state = EmergencyState.idle;
        _activeEvent = null;
        _isTestMode = false;
        _idempotencyKey = null;
        notifyListeners();
      }
    });

    return true;
  }

  void _stopLocationListeners() {
    _stationaryLocationTimer?.cancel();
    _stationaryLocationTimer = null;
    _distanceStreamSubscription?.cancel();
    _distanceStreamSubscription = null;
  }

  @override
  void dispose() {
    _stopLocationListeners();
    super.dispose();
  }
}
