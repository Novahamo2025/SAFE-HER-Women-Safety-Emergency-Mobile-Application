import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'location_autosave_service.dart';
import 'sos_persistence_service.dart';
import 'emergency_api_service.dart';

@pragma('vm:entry-point')
void startEmergencyCallback() {
  FlutterForegroundTask.setTaskHandler(EmergencyLocationTaskHandler());
}

class EmergencyLocationTaskHandler extends TaskHandler {
  final EmergencyApiService _apiService = EmergencyApiService();
  StreamSubscription<Position>? _positionStreamSubscription;
  DateTime? _lastUpdateSentTime;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[EmergencyForegroundService] Started at $timestamp by $starter');

    // Subscribe to distance-based position stream (15 meters per Section 6)
    _initDistanceStream();
  }

  void _initDistanceStream() {
    try {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15, // 15-20 meters per Section 6
        ),
      ).listen((Position position) {
        _handleNewPosition(position, reason: 'DISTANCE_MOVED');
      }, onError: (e) {
        debugPrint('[EmergencyForegroundService] Distance stream error: $e');
      });
    } catch (e) {
      debugPrint('[EmergencyForegroundService] Failed to init distance stream: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    // Periodic time-based trigger (8-10 seconds per Section 6)
    // Ensures stationary / incapacitated users continue sending updates
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );
      await _handleNewPosition(position, reason: 'TIME_INTERVAL');
    } catch (e) {
      debugPrint('[EmergencyForegroundService] Periodic GPS error: $e');
    }
  }

  Future<void> _handleNewPosition(Position position, {required String reason}) async {
    // 1. Independent local auto-save (Section 2a) - always executes regardless of network
    await LocationAutoSaveService.saveLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
    );

    // Rate-limiting: do not send if less than 6 seconds since last send unless moved > 15m
    final now = DateTime.now();
    if (_lastUpdateSentTime != null && now.difference(_lastUpdateSentTime!).inSeconds < 6) {
      if (reason == 'TIME_INTERVAL') return;
    }

    _lastUpdateSentTime = now;

    // 2. Check for active emergency session to sync with backend
    try {
      final session = await SosPersistenceService.getActiveSession();
      if (session != null) {
        await _apiService.updateLocation(
          eventId: session.emergencyId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );

        // Update notification per Section 5 requirement
        FlutterForegroundTask.updateService(
          notificationTitle: 'SvaShield Emergency Active',
          notificationText: 'Emergency live location sharing is active.',
        );
      }
    } catch (e) {
      debugPrint('[EmergencyForegroundService] Failed to sync location to backend: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[EmergencyForegroundService] Destroyed at $timestamp (isTimeout: $isTimeout)');
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
}

class EmergencyForegroundServiceManager {
  static bool _isInitialized = false;

  static void init() {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'svashield_emergency_tracking',
        channelName: 'SvaShield Emergency Tracking',
        channelDescription: 'Continuous location sharing during active emergency SOS',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(9000), // 9s interval (8-10s per Section 6)
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    _isInitialized = true;
  }

  static Future<bool> startEmergencyTrackingService() async {
    init();

    // Check notification permission (Android 13+)
    final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'SvaShield Emergency Active',
      notificationText: 'Emergency live location sharing is active.',
      callback: startEmergencyCallback,
    );

    return result is ServiceRequestSuccess;
  }

  static Future<bool> stopEmergencyTrackingService() async {
    if (await FlutterForegroundTask.isRunningService) {
      final result = await FlutterForegroundTask.stopService();
      return result is ServiceRequestSuccess;
    }
    return true;
  }

  static Future<bool> isRunning() async {
    return await FlutterForegroundTask.isRunningService;
  }
}
