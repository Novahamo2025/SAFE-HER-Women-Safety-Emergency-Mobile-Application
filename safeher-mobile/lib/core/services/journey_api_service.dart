import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';

class JourneyApiService {
  final Dio _dio = ApiClient.client;

  Future<int> startJourney({
    required String destination,
    required DateTime expectedArrival,
  }) async {
    final response = await _dio.post(
      ApiConstants.journeys,
      data: {
        'destination': destination,
        'expectedArrival': expectedArrival.toUtc().toIso8601String(),
        'gracePeriodMinutes': 5,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return (data['id'] as num).toInt();
  }

  Future<void> checkIn(int journeyId) async {
    await _dio.post(ApiConstants.journeyCheckIn(journeyId));
  }

  Future<void> complete(int journeyId) async {
    await _dio.post(ApiConstants.journeyComplete(journeyId));
  }

  Future<void> cancel(int journeyId) async {
    await _dio.post(ApiConstants.journeyCancel(journeyId));
  }
}
