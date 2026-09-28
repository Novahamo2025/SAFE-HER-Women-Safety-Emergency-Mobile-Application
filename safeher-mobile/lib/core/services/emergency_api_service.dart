import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../models/emergency_event_model.dart';
import '../network/api_client.dart';

class EmergencyApiService {
  final Dio _dio = ApiClient.client;

  Future<EmergencyEventModel> startEmergency({
    required double latitude,
    required double longitude,
    double? accuracy,
    String eventType = 'SOS',
    String? clientEventUuid,
  }) async {
    final response = await _dio.post(
      ApiConstants.emergencyStart,
      data: {
        'eventType': eventType,
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracyMeters': accuracy,
        if (clientEventUuid != null) 'clientEventUuid': clientEventUuid,
      },
    );
    return EmergencyEventModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> updateLocation({
    required int eventId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    await _dio.post(
      ApiConstants.emergencyLocation(eventId),
      data: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracyMeters': accuracy,
      },
    );
  }

  Future<EmergencyEventModel> cancelEmergency({
    required int eventId,
    String? reason,
    String? pin,
  }) async {
    final response = await _dio.post(
      ApiConstants.emergencyCancel(eventId),
      data: {
        if (reason != null) 'reason': reason,
        if (pin != null) 'pin': pin,
      },
    );
    return EmergencyEventModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<EmergencyEventModel> getStatus(int eventId) async {
    final response = await _dio.get(ApiConstants.emergencyStatus(eventId));
    return EmergencyEventModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
