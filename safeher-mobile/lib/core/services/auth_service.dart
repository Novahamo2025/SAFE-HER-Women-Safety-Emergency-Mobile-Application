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

  Future<bool> verifyPassword(String password) async {
    try {
      final response = await _dio.post(
        ApiConstants.verifyPassword,
        data: {'password': password},
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          return data['data'] == true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAccount(String password) async {
    try {
      final response = await _dio.delete(
        ApiConstants.deleteAccount,
        data: {'password': password},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await _dio.post(
      ApiConstants.sendOtp,
      data: {'phone': phone},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _dio.post(
      ApiConstants.verifyOtp,
      data: {
        'phone': phone,
        'otp': otp,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resendOtp({
    required String phone,
  }) async {
    final response = await _dio.post(
      ApiConstants.resendOtp,
      data: {
        'phone': phone,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}
