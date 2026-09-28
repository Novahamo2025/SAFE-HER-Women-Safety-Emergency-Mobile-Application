import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/local_storage.dart';

class ApiClient {
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
            // Attempt automatic token refresh
            try {
              final refreshToken = await LocalStorage.getRefreshToken();
              if (refreshToken != null) {
                final refreshDio = Dio();
                final response = await refreshDio.post(
                  ApiConstants.refreshToken,
                  data: {'refreshToken': refreshToken},
                );

                final data = response.data['data'] as Map<String, dynamic>?;
                if (data != null) {
                  final newAccessToken = data['accessToken'] as String;
                  final newRefreshToken = data['refreshToken'] as String;
                  await LocalStorage.saveTokens(
                    accessToken: newAccessToken,
                    refreshToken: newRefreshToken,
                  );

                  // Retry the original request with new token
                  error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                  final retryResponse = await _dio.fetch(error.requestOptions);
                  return handler.resolve(retryResponse);
                }
              }
            } catch (_) {
              // Refresh failed — clear tokens, let error propagate
              await LocalStorage.clearAll();
            }
          }
          return handler.next(error);
        },
      ),
    );

  static Dio get client => _dio;
}
