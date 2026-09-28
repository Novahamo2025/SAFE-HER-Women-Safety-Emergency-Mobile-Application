import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/checkin_model.dart';

class CheckInProvider extends ChangeNotifier {
  List<CheckInModel> _checkIns = [];
  Timer? _checkInTicker;
  bool _hasMissedCheckIn = false;

  List<CheckInModel> get checkIns => _checkIns;
  bool get hasMissedCheckIn => _hasMissedCheckIn;

  CheckInModel? get nextActiveCheckIn {
    final active = _checkIns.where((c) => c.isScheduled).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    return active.first;
  }

  CheckInProvider() {
    // Default demo check-in for instant user visibility
    final now = DateTime.now();
    _checkIns = [
      CheckInModel(
        id: 1,
        intervalMinutes: 45,
        scheduledTime: now.add(const Duration(minutes: 45)),
        status: 'SCHEDULED',
        note: 'Evening commute check-in',
        createdAt: now,
      ),
    ];
    _startTicker();
  }

  void _startTicker() {
    _checkInTicker?.cancel();
    _checkInTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final active = nextActiveCheckIn;
      if (active != null) {
        if (DateTime.now().isAfter(active.scheduledTime) && active.isScheduled) {
          _hasMissedCheckIn = true;
          // Mark as missed
          final idx = _checkIns.indexWhere((c) => c.id == active.id);
          if (idx != -1) {
            _checkIns[idx] = _checkIns[idx].copyWith(status: 'MISSED');
          }
        }
      }
      notifyListeners();
    });
  }

  void createCheckIn({
    required int intervalMinutes,
    String note = '',
  }) {
    final now = DateTime.now();
    final newCheckIn = CheckInModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      intervalMinutes: intervalMinutes,
      scheduledTime: now.add(Duration(minutes: intervalMinutes)),
      status: 'SCHEDULED',
      note: note.isNotEmpty ? note : 'Scheduled safety check',
      createdAt: now,
    );

    _checkIns.insert(0, newCheckIn);
    _hasMissedCheckIn = false;
    notifyListeners();
  }

  void confirmCheckInSafe(int id) {
    final idx = _checkIns.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _checkIns[idx] = _checkIns[idx].copyWith(status: 'CONFIRMED_SAFE');
      _hasMissedCheckIn = false;
      notifyListeners();
    }
  }

  void acknowledgeMissedCheckIn(int id, bool markSafe) {
    final idx = _checkIns.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _checkIns[idx] = _checkIns[idx].copyWith(
        status: markSafe ? 'CONFIRMED_SAFE' : 'ESCALATED',
      );
      _hasMissedCheckIn = false;
      notifyListeners();
    }
  }

  void deleteCheckIn(int id) {
    _checkIns.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _checkInTicker?.cancel();
    super.dispose();
  }
}
