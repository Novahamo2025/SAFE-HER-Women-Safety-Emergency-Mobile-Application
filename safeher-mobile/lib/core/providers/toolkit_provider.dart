import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';
import '../../services/vibration_service.dart';
import '../models/incident_model.dart';

class ToolkitProvider extends ChangeNotifier {
  bool _isFlashlightOn = false;
  bool _isSirenActive = false;
  List<IncidentModel> _incidents = [];
  bool _isSosTestModeActive = false;

  bool get isFlashlightOn => _isFlashlightOn;
  bool get isSirenActive => _isSirenActive;
  List<IncidentModel> get incidents => _incidents;
  bool get isSosTestModeActive => _isSosTestModeActive;

  static const String _incidentStorageKey = 'safeher_saved_incidents';

  ToolkitProvider() {
    _loadIncidents();
  }

  Future<void> toggleFlashlight() async {
    try {
      if (_isFlashlightOn) {
        await TorchLight.disableTorch();
        _isFlashlightOn = false;
      } else {
        await TorchLight.enableTorch();
        _isFlashlightOn = true;
      }
    } catch (_) {
      // Fallback toggle for emulator or unsupported hardware
      _isFlashlightOn = !_isFlashlightOn;
    }
    notifyListeners();
  }

  Future<void> toggleSiren() async {
    _isSirenActive = !_isSirenActive;
    if (_isSirenActive) {
      try {
        await VibrationService.vibrateEmergency();
      } catch (_) {}
    }
    notifyListeners();
  }

  void stopSiren() {
    _isSirenActive = false;
    notifyListeners();
  }

  Future<void> _loadIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_incidentStorageKey);
    if (raw != null) {
      try {
        final List<dynamic> list = jsonDecode(raw);
        _incidents = list.map((item) => IncidentModel.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    if (_incidents.isEmpty) {
      // Demo record
      _incidents = [
        IncidentModel(
          id: 'inc_101',
          title: 'Suspicious vehicle note',
          description: 'Dark blue sedan was following at a slow pace near Sector 4 metro entrance.',
          timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
          isEncryptedLocally: true,
          isUploaded: false,
        ),
      ];
      _saveIncidents();
    }
    notifyListeners();
  }

  Future<void> addIncident({
    required String title,
    required String description,
    String? audioPath,
    String? photoPath,
    double? latitude,
    double? longitude,
  }) async {
    final newIncident = IncidentModel(
      id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
      title: title.isNotEmpty ? title : 'Safety Note',
      description: description,
      timestamp: DateTime.now(),
      audioPath: audioPath,
      photoPath: photoPath,
      latitude: latitude,
      longitude: longitude,
      isEncryptedLocally: true,
      isUploaded: false,
    );

    _incidents.insert(0, newIncident);
    await _saveIncidents();
    notifyListeners();
  }

  Future<void> deleteIncident(String id) async {
    _incidents.removeWhere((item) => item.id == id);
    await _saveIncidents();
    notifyListeners();
  }

  Future<void> _saveIncidents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _incidents.map((i) => i.toJson()).toList();
    await prefs.setString(_incidentStorageKey, jsonEncode(jsonList));
  }
}
