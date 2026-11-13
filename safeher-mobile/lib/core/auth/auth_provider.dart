import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../storage/local_storage.dart';
import 'package:dio/dio.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class RegistrationResult {
  final bool success;
  final String phone;
  final String? userName;
  final String? message;
  final String? errorMessage;

  RegistrationResult({
    required this.success,
    required this.phone,
    this.userName,
    this.message,
    this.errorMessage,
  });
}

class OtpResendResult {
  final bool success;
  final int cooldownSeconds;
  final String message;

  OtpResendResult({
    required this.success,
    required this.cooldownSeconds,
    required this.message,
  });
}

class AuthProvider extends ChangeNotifier {
  final AuthApiService _authService;

  AuthProvider({AuthApiService? authService})
      : _authService = authService ?? AuthApiService();

  AuthState _state = AuthState.initial;
  String? _errorMessage;
  Map<String, dynamic>? _userData;

  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get userData => _userData;
  bool get isAuthenticated => _state == AuthState.authenticated;

  String get userName => _userData?['name'] as String? ?? 'Anu';
  String get userEmail => _userData?['email'] as String? ?? 'anu@safeher.app';
  String get userPhone => _userData?['phone'] as String? ?? '+91 98765 43210';

  /// Called on app startup to restore session
  Future<void> tryAutoLogin() async {
    _state = AuthState.loading;
    notifyListeners();

    try {
      final savedUserData = await LocalStorage.getUserData();
      final accessToken = await LocalStorage.getAccessToken();
      final refreshTokenStr = await LocalStorage.getRefreshToken();

      if (accessToken == null || refreshTokenStr == null || savedUserData == null) {
        _state = AuthState.unauthenticated;
        notifyListeners();
        return;
      }

      // Try refreshing the token to validate the session
      try {
        final response = await _authService.refreshToken(refreshTokenStr);
        await _handleAuthSuccess(response);
      } catch (e) {
        if (e is DioException) {
          final resData = e.response?.data;
          final msg = resData is Map ? resData['message']?.toString() : '';
          // Unverified account cannot enter authenticated screen
          if (msg != null && msg.contains('Account phone number is not verified')) {
            _state = AuthState.unauthenticated;
            notifyListeners();
            return;
          }
          if (e.response?.statusCode == 401) {
            await LocalStorage.clearTokens();
            _state = AuthState.unauthenticated;
            notifyListeners();
            return;
          }
        }
        // If network connectivity issue, fall back to valid saved session
        _userData = savedUserData;
        _state = AuthState.authenticated;
        notifyListeners();
      }
    } catch (_) {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  Future<RegistrationResult> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? pin,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        pin: pin,
      );

      final data = response['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('Invalid response data from server');
      }

      // SECURITY INVARIANT: Do NOT treat registration as completed authentication.
      // Do NOT store null/placeholder JWTs or mark authenticated.
      if (pin != null && pin.isNotEmpty) {
        await LocalStorage.saveUserPin(pin);
      }

      _state = AuthState.unauthenticated;
      _errorMessage = null;
      notifyListeners();

      return RegistrationResult(
        success: true,
        phone: phone,
        userName: name,
        message: response['message'] as String? ?? 'Registration successful. Please verify OTP.',
      );
    } catch (e) {
      _errorMessage = _extractError(e);
      _state = AuthState.unauthenticated;
      notifyListeners();
      return RegistrationResult(
        success: false,
        phone: phone,
        userName: name,
        errorMessage: _errorMessage,
      );
    }
  }

  Future<bool> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.verifyOtp(phone: phone, otp: otp);
      await _handleAuthSuccess(response);
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<OtpResendResult> resendOtp(String phone) async {
    try {
      final response = await _authService.resendOtp(phone: phone);
      final data = response['data'] as Map<String, dynamic>?;
      final cooldown = data?['cooldownSeconds'] as int? ?? 45;
      final msg = response['message'] as String? ?? 'A fresh verification code has been dispatched via SMS.';
      return OtpResendResult(
        success: true,
        cooldownSeconds: cooldown,
        message: msg,
      );
    } catch (e) {
      int cooldown = 45;
      if (e is DioException) {
        final retryHeader = e.response?.headers.value('retry-after');
        if (retryHeader != null) {
          cooldown = int.tryParse(retryHeader) ?? 45;
        }
        final resData = e.response?.data;
        if (resData is Map && resData['data'] is Map && resData['data']['retryAfterSeconds'] != null) {
          cooldown = resData['data']['retryAfterSeconds'] as int;
        }
      }
      return OtpResendResult(
        success: false,
        cooldownSeconds: cooldown,
        message: _extractError(e),
      );
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        identifier: identifier,
        password: password,
      );
      await _handleAuthSuccess(response);
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String phone,
  }) async {
    _userData = {
      ...(_userData ?? {}),
      'name': name,
      'email': email,
      'phone': phone,
    };
    await LocalStorage.saveUserData(_userData!);
    notifyListeners();
  }

  Future<void> setUserPin(String pin) async {
    await LocalStorage.saveUserPin(pin);
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      final refreshTokenStr = await LocalStorage.getRefreshToken();
      if (refreshTokenStr != null) {
        await _authService.logout(refreshTokenStr);
      }
    } catch (_) {
      // Logout should succeed even if server call fails
    } finally {
      await LocalStorage.clearAll();
      _userData = null;
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> refreshSession() async {
    try {
      final refreshTokenStr = await LocalStorage.getRefreshToken();
      if (refreshTokenStr == null) return false;

      final response = await _authService.refreshToken(refreshTokenStr);
      await _handleAuthSuccess(response);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> verifyPassword(String password) async {
    if (password.trim().isEmpty) return false;

    // Verify password strictly against backend authentication credentials
    try {
      final backendValid = await _authService.verifyPassword(password.trim());
      return backendValid;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAccountAndData(String password) async {
    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) return false;

    // 1. Authenticate and execute deletion on backend server
    final backendSuccess = await _authService.deleteAccount(trimmedPassword);
    if (!backendSuccess) {
      return false;
    }

    // 2. Cascade delete all local sensitive evidence & reset security keys
    try {
      await MediaService.clearAllEvidence();
      await LocalStorage.clearAll();
      _userData = null;
      _state = AuthState.unauthenticated;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    try {
      final response = await _authService.sendOtp(phone);
      final data = response['data'] as Map<String, dynamic>?;
      return {
        'success': true,
        'message': response['message'] as String? ?? 'Verification code dispatched.',
        'isMock': data?['isMock'] as bool? ?? false,
      };
    } catch (e) {
      if (e is DioException && (e.type == DioExceptionType.connectionError || e.response == null)) {
        return {
          'success': true,
          'message': 'Demo Mode: Verification code generated in offline safety mode.',
          'isMock': true,
        };
      }
      final msg = _extractError(e);
      return {
        'success': false,
        'message': msg,
        'isMock': false,
      };
    }
  }

  // --- Private helpers ---

  Future<void> _handleAuthSuccess(Map<String, dynamic> response) async {
    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('Invalid response');

    final accessToken = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw Exception('Missing tokens in response');
    }

    await LocalStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    _userData = {
      'userId': data['userId'],
      'name': data['name'],
      'email': data['email'],
      'phone': data['phone'],
      'role': data['role'],
    };
    await LocalStorage.saveUserData(_userData!);

    _state = AuthState.authenticated;
    notifyListeners();
  }

  String _extractError(dynamic error) {
    if (error is DioException) {
      final resData = error.response?.data;
      if (resData is Map<String, dynamic>) {
        // 1. Check top-level message if meaningful
        final msg = resData['message'] as String?;
        if (msg != null && msg.trim().isNotEmpty && msg.trim() != 'Validation failed') {
          return msg.trim();
        }

        // 2. Check if specific field validation errors exist in 'data' map (Spring MethodArgumentNotValidException)
        final nestedData = resData['data'];
        if (nestedData is Map<String, dynamic> && nestedData.isNotEmpty) {
          final firstError = nestedData.values.first;
          if (firstError != null && firstError.toString().trim().isNotEmpty) {
            return firstError.toString().trim();
          }
        }
      }

      final statusCode = error.response?.statusCode;
      if (statusCode == 429) {
        return 'Too many requests. Please wait before trying again.';
      }
      if (statusCode == 409) {
        return 'An account with this email or mobile number already exists.';
      }
      if (statusCode == 401) {
        return 'Invalid credentials or session expired.';
      }
      if (statusCode == 400) {
        return 'Invalid request details. Please verify your entries.';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'Server error. Please try again later.';
      }

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Please check your internet connection.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Unable to connect to server. Please check your internet connection or verify the backend is running.';
      }
    }
    return error?.toString() ?? 'Operation failed. Please verify and try again.';
  }
}
