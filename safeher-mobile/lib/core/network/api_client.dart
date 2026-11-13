import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/local_storage.dart';

class ApiClient {
  static Completer<String?>? _refreshCompleter;

  static Future<String?> _performTokenRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await LocalStorage.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(null);
        return null;
      }

      final refreshDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        ),
      );

      final response = await refreshDio.post(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      final data = response.data['data'] as Map<String, dynamic>?;
      if (data != null) {
        final newAccessToken = data['accessToken'] as String?;
        final newRefreshToken = data['refreshToken'] as String?;
        if (newAccessToken != null && newRefreshToken != null) {
          await LocalStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          _refreshCompleter!.complete(newAccessToken);
          return newAccessToken;
        }
      }
      _refreshCompleter!.complete(null);
      return null;
    } catch (e) {
      // Check if error is unverified account (do not delete tokens) vs expired token
      if (e is DioException) {
        final resData = e.response?.data;
        final msg = resData is Map ? resData['message']?.toString() : '';
        if (msg != null && msg.contains('Account phone number is not verified')) {
          _refreshCompleter!.complete(null);
          return null;
        }
        if (e.response?.statusCode == 401) {
          await LocalStorage.clearTokens();
        }
      }
      _refreshCompleter!.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await LocalStorage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            // Prevent recursive refresh loops if the refresh call itself failed with 401
            if (error.requestOptions.path.contains('/auth/refresh')) {
              return handler.next(error);
            }

            final newAccessToken = await _performTokenRefresh();
            if (newAccessToken != null) {
              error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              try {
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (retryError) {
                if (retryError is DioException) {
                  return handler.next(retryError);
                }
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

  static Dio get client => _dio;
}
