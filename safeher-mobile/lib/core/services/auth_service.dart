import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';

class AuthApiService {
  final Dio _dio = ApiClient.client;

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? pin,
  }) async {
    final response = await _dio.post(
      ApiConstants.register,
      data: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiConstants.login,
      data: {
        'identifier': identifier,
        'password': password,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post(
      ApiConstants.refreshToken,
      data: {'refreshToken': refreshToken},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post(
      ApiConstants.logout,
      data: {'refreshToken': refreshToken},
    );
  }
}
