import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/journey_model.dart';
import '../services/journey_api_service.dart';

class JourneyProvider extends ChangeNotifier {
  final JourneyApiService _apiService = JourneyApiService();
  JourneyModel? _activeJourney;
  Timer? _journeyTicker;
  bool _shouldPromptSafetyArrival = false;
  final List<JourneyModel> _pastJourneys = [];
  bool _disposed = false;

  JourneyModel? get activeJourney => _activeJourney;
  bool get hasActiveJourney =>
      _activeJourney != null && _activeJourney!.isActive;
  bool get shouldPromptSafetyArrival => _shouldPromptSafetyArrival;
  List<JourneyModel> get pastJourneys => _pastJourneys;

  void startJourney({
    required String destination,
    required int durationMinutes,
  }) {
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: durationMinutes));

    _activeJourney = JourneyModel(
      id: now.millisecondsSinceEpoch,
      destination: destination,
      durationMinutes: durationMinutes,
      startedAt: now,
      expectedArrival: arrival,
      status: 'ACTIVE',
      checkpoints: [
        'Started journey towards $destination at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'
      ],
    );
    _shouldPromptSafetyArrival = false;
    notifyListeners();

    unawaited(_syncJourneyStart(_activeJourney!));
    _startTicker();
  }

  Future<void> _syncJourneyStart(JourneyModel journey) async {
    try {
      final serverId = await _apiService.startJourney(
        destination: journey.destination,
        expectedArrival: journey.expectedArrival,
      );

      if (_activeJourney?.id == journey.id) {
        _activeJourney = _activeJourney!.copyWith(serverId: serverId);
        if (!_disposed) notifyListeners();
        return;
      }

      final pastIndex =
          _pastJourneys.indexWhere((item) => item.id == journey.id);
      if (pastIndex == -1) {
        await _apiService.cancel(serverId);
        return;
      }

      final savedJourney =
          _pastJourneys[pastIndex].copyWith(serverId: serverId);
      _pastJourneys[pastIndex] = savedJourney;
      if (savedJourney.status == 'COMPLETED') {
        await _apiService.complete(serverId);
      } else if (savedJourney.status == 'CANCELLED') {
        await _apiService.cancel(serverId);
      }
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }

  void _startTicker() {
    _journeyTicker?.cancel();
    _journeyTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeJourney == null || !_activeJourney!.isActive) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      // If arrival time reached or within 1 minute, trigger arrival confirmation prompt
      if (now.isAfter(_activeJourney!.expectedArrival) &&
          !_shouldPromptSafetyArrival) {
        _shouldPromptSafetyArrival = true;
      }

      notifyListeners();
    });
  }

  void addCheckpoint(String note) {
    if (_activeJourney == null) return;
    final serverId = _activeJourney!.serverId;
    if (serverId != null) unawaited(_apiService.checkIn(serverId));
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final updatedCheckpoints = List<String>.from(_activeJourney!.checkpoints)
      ..add('$note ($timeStr)');

    _activeJourney = _activeJourney!.copyWith(checkpoints: updatedCheckpoints);
    notifyListeners();
  }

  void completeJourneySafely() {
    if (_activeJourney == null) return;
    _journeyTicker?.cancel();

    final completed = _activeJourney!.copyWith(
      status: 'COMPLETED',
      checkpoints: List<String>.from(_activeJourney!.checkpoints)
        ..add('Arrived safely at destination!'),
    );
    _syncJourneyStatus(completed);
    _pastJourneys.insert(0, completed);
    _activeJourney = null;
    _shouldPromptSafetyArrival = false;
    notifyListeners();
  }

  void cancelJourney() {
    if (_activeJourney == null) return;
    _journeyTicker?.cancel();

    final cancelled = _activeJourney!.copyWith(status: 'CANCELLED');
    _syncJourneyStatus(cancelled);
    _pastJourneys.insert(0, cancelled);
    _activeJourney = null;
    _shouldPromptSafetyArrival = false;
    notifyListeners();
  }

  void dismissArrivalPrompt() {
    _shouldPromptSafetyArrival = false;
    notifyListeners();
  }

  void _syncJourneyStatus(JourneyModel journey) {
    final serverId = journey.serverId;
    if (serverId == null) return;
    if (journey.status == 'COMPLETED') {
      unawaited(_apiService.complete(serverId));
    } else if (journey.status == 'CANCELLED') {
      unawaited(_apiService.cancel(serverId));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _journeyTicker?.cancel();
    super.dispose();
  }
}
