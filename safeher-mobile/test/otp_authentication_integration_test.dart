import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safeher/core/auth/auth_provider.dart';
import 'package:safeher/core/services/auth_service.dart';
import 'package:safeher/core/storage/local_storage.dart';

class MockAuthApiService extends AuthApiService {
  Map<String, dynamic>? mockRegisterResponse;
  Map<String, dynamic>? mockVerifyResponse;
  Map<String, dynamic>? mockResendResponse;
  Map<String, dynamic>? mockLoginResponse;
  Map<String, dynamic>? mockRefreshResponse;

  DioException? mockRegisterException;
  DioException? mockVerifyException;
  DioException? mockResendException;
  DioException? mockLoginException;
  DioException? mockRefreshException;

  int registerCallCount = 0;
  int verifyCallCount = 0;
  int resendCallCount = 0;
  int loginCallCount = 0;
  int refreshCallCount = 0;
  int logoutCallCount = 0;

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? pin,
  }) async {
    registerCallCount++;
    if (mockRegisterException != null) throw mockRegisterException!;
    return mockRegisterResponse ?? {
      'success': true,
      'message': 'User registered successfully. Please verify your phone number with the OTP sent via SMS.',
      'data': {
        'userId': 10,
        'name': name,
        'email': email,
        'phone': phone,
        'accessToken': null,
        'refreshToken': null,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    verifyCallCount++;
    if (mockVerifyException != null) throw mockVerifyException!;
    return mockVerifyResponse ?? {
      'success': true,
      'message': 'Phone verified successfully.',
      'data': {
        'accessToken': 'jwt_access_token_mock_verified',
        'refreshToken': 'jwt_refresh_token_mock_verified',
        'tokenType': 'Bearer',
        'userId': 10,
        'name': 'Priya Sharma',
        'email': 'priya@example.com',
        'phone': phone,
        'role': 'ROLE_USER',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> resendOtp({
    required String phone,
  }) async {
    resendCallCount++;
    if (mockResendException != null) throw mockResendException!;
    return mockResendResponse ?? {
      'success': true,
      'message': 'A fresh verification code has been dispatched via SMS.',
      'data': {
        'phoneMasked': '+91****210',
        'cooldownSeconds': 45,
        'expiresInSeconds': 600,
        'dispatchStatus': 'ACCEPTED',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    loginCallCount++;
    if (mockLoginException != null) throw mockLoginException!;
    return mockLoginResponse ?? {
      'success': true,
      'message': 'Login successful',
      'data': {
        'accessToken': 'jwt_login_access_token',
        'refreshToken': 'jwt_login_refresh_token',
        'tokenType': 'Bearer',
        'userId': 1,
        'name': 'Legacy User',
        'email': 'legacy@example.com',
        'phone': '+919876543001',
        'role': 'ROLE_ADMIN',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    refreshCallCount++;
    if (mockRefreshException != null) throw mockRefreshException!;
    return mockRefreshResponse ?? {
      'success': true,
      'message': 'Token refreshed successfully',
      'data': {
        'accessToken': 'new_jwt_access_token',
        'refreshToken': 'new_jwt_refresh_token',
        'tokenType': 'Bearer',
        'userId': 10,
        'name': 'Priya Sharma',
        'email': 'priya@example.com',
        'phone': '+919876543210',
        'role': 'ROLE_USER',
      },
    };
  }

  @override
  Future<void> logout(String refreshToken) async {
    logoutCallCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SvaShield Phase 2C Stage 7: OTP & Authentication Tests', () {
    late MockAuthApiService mockService;
    late AuthProvider authProvider;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      mockService = MockAuthApiService();
      authProvider = AuthProvider(authService: mockService);
    });

    tearDown(() async {
      await LocalStorage.clearAll();
    });

    // 1. Registration
    test('1. Registration submits fields, succeeds, but NEVER creates authenticated session', () async {
      final result = await authProvider.register(
        name: 'Priya Sharma',
        email: 'priya@example.com',
        phone: '+919876543210',
        password: 'Password@123',
        pin: '1234',
      );

      expect(result.success, isTrue);
      expect(result.phone, equals('+919876543210'));
      expect(result.userName, equals('Priya Sharma'));

      // Critical Invariant: User MUST NOT be authenticated yet
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.state, equals(AuthState.unauthenticated));
      expect(authProvider.userData, isNull);

      // Critical Invariant: No tokens stored
      expect(await LocalStorage.getAccessToken(), isNull);
      expect(await LocalStorage.getRefreshToken(), isNull);

      // PIN is saved for later
      expect(await LocalStorage.getUserPin(), equals('1234'));
      expect(mockService.registerCallCount, equals(1));
    });

    test('2. Registration failure does not store tokens and returns error message', () async {
      mockService.mockRegisterException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/register'),
          statusCode: 409,
          data: {
            'success': false,
            'message': 'This mobile number is already registered',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final result = await authProvider.register(
        name: 'Duplicate',
        email: 'dup@example.com',
        phone: '+919876543210',
        password: 'Password@123',
      );

      expect(result.success, isFalse);
      expect(result.errorMessage, equals('This mobile number is already registered'));
      expect(authProvider.isAuthenticated, isFalse);
      expect(await LocalStorage.getAccessToken(), isNull);
    });

    // 2. OTP Verification
    test('3. Correct OTP verification transitions user to authenticated and saves tokens', () async {
      final success = await authProvider.verifyOtp(
        phone: '+919876543210',
        otp: '123456',
      );

      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.state, equals(AuthState.authenticated));
      expect(authProvider.userName, equals('Priya Sharma'));
      expect(authProvider.userEmail, equals('priya@example.com'));
      expect(authProvider.userPhone, equals('+919876543210'));

      // Secure tokens must be persisted
      expect(await LocalStorage.getAccessToken(), equals('jwt_access_token_mock_verified'));
      expect(await LocalStorage.getRefreshToken(), equals('jwt_refresh_token_mock_verified'));
      expect(mockService.verifyCallCount, equals(1));
    });

    test('4. Incorrect OTP returns false, sets error, and leaves user unauthenticated', () async {
      mockService.mockVerifyException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/otp/verify'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/otp/verify'),
          statusCode: 400,
          data: {
            'success': false,
            'message': 'Invalid OTP code. 2 attempts remaining.',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final success = await authProvider.verifyOtp(
        phone: '+919876543210',
        otp: '000000',
      );

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, equals('Invalid OTP code. 2 attempts remaining.'));
      expect(await LocalStorage.getAccessToken(), isNull);
    });

    test('5. Expired OTP returns false with expiration error message', () async {
      mockService.mockVerifyException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/otp/verify'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/otp/verify'),
          statusCode: 400,
          data: {
            'success': false,
            'message': 'Verification code has expired. Please request a new code.',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final success = await authProvider.verifyOtp(
        phone: '+919876543210',
        otp: '123456',
      );

      expect(success, isFalse);
      expect(authProvider.errorMessage, equals('Verification code has expired. Please request a new code.'));
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('6. Exceeded attempts returns false and lockout message', () async {
      mockService.mockVerifyException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/otp/verify'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/otp/verify'),
          statusCode: 400,
          data: {
            'success': false,
            'message': 'Maximum verification attempts exceeded. Please request a new code.',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final success = await authProvider.verifyOtp(
        phone: '+919876543210',
        otp: '999999',
      );

      expect(success, isFalse);
      expect(authProvider.errorMessage, contains('Maximum verification attempts exceeded'));
      expect(authProvider.isAuthenticated, isFalse);
    });

    // 3. OTP Resend
    test('7. OTP resend returns cooldown and dispatch success message', () async {
      final result = await authProvider.resendOtp('+919876543210');

      expect(result.success, isTrue);
      expect(result.cooldownSeconds, equals(45));
      expect(result.message, equals('A fresh verification code has been dispatched via SMS.'));
      expect(mockService.resendCallCount, equals(1));
    });

    test('8. OTP resend during active cooldown (HTTP 429) extracts Retry-After', () async {
      mockService.mockResendException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/otp/resend'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/otp/resend'),
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['35'],
          }),
          data: {
            'success': false,
            'message': 'Please wait 35 seconds before requesting another OTP.',
            'data': {'retryAfterSeconds': 35},
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final result = await authProvider.resendOtp('+919876543210');

      expect(result.success, isFalse);
      expect(result.cooldownSeconds, equals(35));
      expect(result.message, equals('Please wait 35 seconds before requesting another OTP.'));
    });

    // 4. Login & Legacy Account Management
    test('9. Legacy account login succeeds without phone verification and stores tokens', () async {
      final success = await authProvider.login(
        identifier: 'legacy@example.com',
        password: 'AdminPassword123!',
      );

      expect(success, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.state, equals(AuthState.authenticated));
      expect(authProvider.userName, equals('Legacy User'));
      expect(await LocalStorage.getAccessToken(), equals('jwt_login_access_token'));
      expect(await LocalStorage.getRefreshToken(), equals('jwt_login_refresh_token'));
    });

    test('10. Non-legacy unverified account login is strictly rejected (400)', () async {
      mockService.mockLoginException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          statusCode: 400,
          data: {
            'success': false,
            'message': 'Account phone number is not verified. Please complete OTP verification.',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final success = await authProvider.login(
        identifier: 'user3@example.com',
        password: 'User3Password!',
      );

      expect(success, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.errorMessage, contains('Account phone number is not verified'));
      expect(await LocalStorage.getAccessToken(), isNull);
    });

    // 5. Session Refresh & Logout
    test('11. Logout clears tokens and session data in secure storage', () async {
      // First authenticate
      await authProvider.verifyOtp(phone: '+919876543210', otp: '123456');
      expect(authProvider.isAuthenticated, isTrue);
      expect(await LocalStorage.getAccessToken(), isNotNull);

      // Now logout
      await authProvider.logout();

      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.state, equals(AuthState.unauthenticated));
      expect(authProvider.userData, isNull);
      expect(await LocalStorage.getAccessToken(), isNull);
      expect(await LocalStorage.getRefreshToken(), isNull);
      expect(mockService.logoutCallCount, equals(1));
    });

    test('12. Auto-login validates session with backend refresh token', () async {
      // Save valid tokens to mock storage
      await LocalStorage.saveTokens(
        accessToken: 'initial_access_token',
        refreshToken: 'initial_refresh_token',
      );
      await LocalStorage.saveUserData({
        'userId': 10,
        'name': 'Priya Sharma',
        'email': 'priya@example.com',
        'phone': '+919876543210',
        'role': 'ROLE_USER',
      });

      await authProvider.tryAutoLogin();

      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.userName, equals('Priya Sharma'));
      expect(mockService.refreshCallCount, equals(1));
      expect(await LocalStorage.getAccessToken(), equals('new_jwt_access_token'));
    });
  });
}
