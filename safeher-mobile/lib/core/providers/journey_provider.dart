import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/journey_model.dart';

class JourneyProvider extends ChangeNotifier {
  JourneyModel? _activeJourney;
  Timer? _journeyTicker;
  bool _shouldPromptSafetyArrival = false;
  List<JourneyModel> _pastJourneys = [];

  JourneyModel? get activeJourney => _activeJourney;
  bool get hasActiveJourney => _activeJourney != null && _activeJourney!.isActive;
  bool get shouldPromptSafetyArrival => _shouldPromptSafetyArrival;
  List<JourneyModel> get pastJourneys => _pastJourneys;

  void startJourney({
    required String destination,
    required int durationMinutes,
  }) {
    final now = DateTime.now();
    final arrival = now.add(Duration(minutes: durationMinutes));

    _activeJourney = JourneyModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      destination: destination,
      durationMinutes: durationMinutes,
      startedAt: now,
      expectedArrival: arrival,
      status: 'ACTIVE',
      checkpoints: ['Started journey towards $destination at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}'],
    );
    _shouldPromptSafetyArrival = false;
    notifyListeners();

    _startTicker();
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
      if (now.isAfter(_activeJourney!.expectedArrival) && !_shouldPromptSafetyArrival) {
        _shouldPromptSafetyArrival = true;
      }

      notifyListeners();
    });
  }

  void addCheckpoint(String note) {
    if (_activeJourney == null) return;
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final updatedCheckpoints = List<String>.from(_activeJourney!.checkpoints)..add('$note ($timeStr)');

    _activeJourney = _activeJourney!.copyWith(checkpoints: updatedCheckpoints);
    notifyListeners();
  }

  void completeJourneySafely() {
    if (_activeJourney == null) return;
    _journeyTicker?.cancel();

    final completed = _activeJourney!.copyWith(
      status: 'COMPLETED',
      checkpoints: List<String>.from(_activeJourney!.checkpoints)..add('Arrived safely at destination!'),
    );
    _pastJourneys.insert(0, completed);
    _activeJourney = null;
    _shouldPromptSafetyArrival = false;
    notifyListeners();
  }

  void cancelJourney() {
    if (_activeJourney == null) return;
    _journeyTicker?.cancel();

    final cancelled = _activeJourney!.copyWith(status: 'CANCELLED');
    _pastJourneys.insert(0, cancelled);
    _activeJourney = null;
    _shouldPromptSafetyArrival = false;
    notifyListeners();
  }

  void dismissArrivalPrompt() {
    _shouldPromptSafetyArrival = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _journeyTicker?.cancel();
    super.dispose();
  }
}
