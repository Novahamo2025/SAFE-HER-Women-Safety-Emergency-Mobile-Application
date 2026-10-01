import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/checkin_model.dart';
import '../services/checkin_api_service.dart';

class CheckInProvider extends ChangeNotifier {
  final CheckInApiService _apiService = CheckInApiService();
  List<CheckInModel> _checkIns = [];
  Timer? _checkInTicker;
  bool _hasMissedCheckIn = false;
  bool _disposed = false;

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
        if (DateTime.now().isAfter(active.scheduledTime) &&
            active.isScheduled) {
          _hasMissedCheckIn = true;
          // Mark as missed
          final idx = _checkIns.indexWhere((c) => c.id == active.id);
          if (idx != -1) {
            final missed = _checkIns[idx].copyWith(status: 'MISSED');
            _checkIns[idx] = missed;
            _syncCheckInStatus(missed);
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
      id: DateTime.now().millisecondsSinceEpoch,
      intervalMinutes: intervalMinutes,
      scheduledTime: now.add(Duration(minutes: intervalMinutes)),
      status: 'SCHEDULED',
      note: note.isNotEmpty ? note : 'Scheduled safety check',
      createdAt: now,
    );

    _checkIns.insert(0, newCheckIn);
    unawaited(_syncCheckInStart(newCheckIn));
    _hasMissedCheckIn = false;
    notifyListeners();
  }

  Future<void> _syncCheckInStart(CheckInModel checkIn) async {
    try {
      final serverId =
          await _apiService.schedule(scheduledTime: checkIn.scheduledTime);
      final index = _checkIns.indexWhere((item) => item.id == checkIn.id);
      if (index == -1) {
        await _apiService.cancel(serverId);
        return;
      }

      final savedCheckIn = _checkIns[index].copyWith(serverId: serverId);
      _checkIns[index] = savedCheckIn;
      _syncCheckInStatus(savedCheckIn);
      if (!_disposed) notifyListeners();
    } catch (_) {}
  }

  void confirmCheckInSafe(int id) {
    final idx = _checkIns.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _checkIns[idx] = _checkIns[idx].copyWith(status: 'CONFIRMED_SAFE');
      _syncCheckInStatus(_checkIns[idx]);
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
      _syncCheckInStatus(_checkIns[idx]);
      _hasMissedCheckIn = false;
      notifyListeners();
    }
  }

  void deleteCheckIn(int id) {
    final index = _checkIns.indexWhere((item) => item.id == id);
    final checkIn = index == -1 ? null : _checkIns[index];
    _checkIns.removeWhere((c) => c.id == id);
    if (checkIn?.serverId != null) {
      unawaited(_apiService.cancel(checkIn!.serverId!));
    }
    notifyListeners();
  }

  void _syncCheckInStatus(CheckInModel checkIn) {
    final serverId = checkIn.serverId;
    if (serverId == null) return;
    switch (checkIn.status) {
      case 'CONFIRMED_SAFE':
        unawaited(_apiService.complete(serverId));
      case 'MISSED':
        unawaited(_apiService.markMissed(serverId));
      case 'ESCALATED':
        unawaited(_apiService.escalate(serverId));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _checkInTicker?.cancel();
    super.dispose();
  }
}
