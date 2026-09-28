import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../storage/local_storage.dart';
import 'package:dio/dio.dart';

enum AuthState { initial, loading, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthApiService _authService = AuthApiService();

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
      if (savedUserData != null) {
        _userData = savedUserData;
        _state = AuthState.authenticated;
        notifyListeners();
        return;
      }

      final accessToken = await LocalStorage.getAccessToken();
      final refreshTokenStr = await LocalStorage.getRefreshToken();

      if (accessToken == null || refreshTokenStr == null) {
        _state = AuthState.unauthenticated;
        notifyListeners();
        return;
      }

      // Try refreshing the token to validate the session
      try {
        final response = await _authService.refreshToken(refreshTokenStr);
        await _handleAuthSuccess(response);
      } catch (e) {
        if (savedUserData != null) {
          _userData = savedUserData;
          _state = AuthState.authenticated;
        } else {
          _state = AuthState.unauthenticated;
        }
      }
    } catch (e) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
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
      await _handleAuthSuccess(response);
      if (pin != null && pin.isNotEmpty) {
        await LocalStorage.saveUserPin(pin);
      }
      return true;
    } catch (e) {
      // Offline fallback: Allow user registration in offline/standalone mode
      _userData = {
        'userId': DateTime.now().millisecondsSinceEpoch % 10000,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'USER',
      };
      await LocalStorage.saveUserData(_userData!);
      await LocalStorage.saveTokens(
        accessToken: 'offline_token_${DateTime.now().millisecondsSinceEpoch}',
        refreshToken: 'offline_refresh_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (pin != null && pin.isNotEmpty) {
        await LocalStorage.saveUserPin(pin);
      }
      _state = AuthState.authenticated;
      notifyListeners();
      return true;
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
      // Offline fallback for testing/demo
      if (identifier.isNotEmpty && password.length >= 6) {
        _userData = {
          'userId': 1,
          'name': identifier.contains('@') ? identifier.split('@').first : 'Anu',
          'email': identifier.contains('@') ? identifier : '$identifier@safeher.app',
          'phone': identifier.contains('@') ? '+91 98765 43210' : identifier,
          'role': 'USER',
        };
        await LocalStorage.saveUserData(_userData!);
        await LocalStorage.saveTokens(
          accessToken: 'offline_token_demo',
          refreshToken: 'offline_refresh_demo',
        );
        _state = AuthState.authenticated;
        notifyListeners();
        return true;
      }
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
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] as String? ?? 'Invalid credentials or request error';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Please check your internet.';
      }
      if (error.type == DioExceptionType.connectionError) {
        return 'Cannot connect to server. Running in offline safety mode.';
      }
    }
    return 'Invalid credentials. Please verify and try again.';
  }
}
