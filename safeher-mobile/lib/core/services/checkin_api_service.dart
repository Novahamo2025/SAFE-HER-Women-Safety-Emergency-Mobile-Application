import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';

class CheckInApiService {
  final Dio _dio = ApiClient.client;

  Future<int> schedule({required DateTime scheduledTime}) async {
    final response = await _dio.post(
      ApiConstants.checkins,
      data: {
        'scheduledTime': scheduledTime.toUtc().toIso8601String(),
        'gracePeriodMinutes': 5,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }

  Future<void> complete(int checkInId) async {
    await _dio.post(ApiConstants.checkinComplete(checkInId));
  }

  Future<void> markMissed(int checkInId) async {
    await _dio.post(ApiConstants.checkinMissed(checkInId));
  }

  Future<void> escalate(int checkInId) async {
    await _dio.post(ApiConstants.checkinEscalate(checkInId));
  }

  Future<void> cancel(int checkInId) async {
    await _dio.post(ApiConstants.checkinCancel(checkInId));
  }
}
