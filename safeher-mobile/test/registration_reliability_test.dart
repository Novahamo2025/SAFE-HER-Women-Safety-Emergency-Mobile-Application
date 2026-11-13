import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:safeher/core/auth/auth_provider.dart';
import 'package:safeher/core/services/auth_service.dart';
import 'package:safeher/core/storage/local_storage.dart';
import 'package:safeher/core/utils/password_validator.dart';

/// Fake AuthApiService for testing registration responses without real network calls.
class FakeAuthApiService extends AuthApiService {
  Map<String, dynamic>? mockSuccessResponse;
  DioException? mockDioException;
  Exception? mockGeneralException;

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? pin,
  }) async {
    if (mockDioException != null) {
      throw mockDioException!;
    }
    if (mockGeneralException != null) {
      throw mockGeneralException!;
    }
    if (mockSuccessResponse != null) {
      return mockSuccessResponse!;
    }
    return {
      'success': true,
      'message': 'User registered successfully. Please verify your phone number with the OTP sent via SMS.',
      'data': {
        'userId': 99,
        'name': name,
        'email': email,
        'phone': phone,
        'role': 'ROLE_USER',
        'accessToken': null,
        'refreshToken': null,
      },
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('Requirement 5.1: Client Password Validation Tests', () {
    test('Null or empty password is rejected', () {
      expect(PasswordValidator.validate(null), 'Please enter an account password.');
      expect(PasswordValidator.validate(''), 'Please enter an account password.');
    });

    test('Password shorter than 8 characters is rejected', () {
      expect(PasswordValidator.validate('Pass1!'), 'Password must be at least 8 characters.');
      expect(PasswordValidator.validate('1234567'), 'Password must be at least 8 characters.');
    });

    test('Password longer than 128 characters is rejected', () {
      final longPassword = 'A1!${'a' * 130}';
      expect(PasswordValidator.validate(longPassword), 'Password must not exceed 128 characters.');
    });

    test('Password without uppercase letter is rejected', () {
      expect(PasswordValidator.validate('password@123'), 'Password must contain at least one uppercase letter (A-Z).');
    });

    test('Password without lowercase letter is rejected', () {
      expect(PasswordValidator.validate('PASSWORD@123'), 'Password must contain at least one lowercase letter (a-z).');
    });

    test('Password without digit is rejected', () {
      expect(PasswordValidator.validate('Password@Special'), 'Password must contain at least one digit (0-9).');
    });

    test('Password without special character is rejected', () {
      expect(PasswordValidator.validate('Password123'), 'Password must contain at least one special character (@\$!%*?&#^()-_+=).');
    });

    test('Password with unsupported characters is rejected', () {
      expect(PasswordValidator.validate('Password 123!'), 'Password contains unsupported characters.'); // space
      expect(PasswordValidator.validate('Password#123✨'), 'Password contains unsupported characters.'); // emoji
    });

    test('Valid passwords matching backend policy pass validation', () {
      expect(PasswordValidator.validate('SvaShield@2026'), isNull);
      expect(PasswordValidator.validate('Secure#Password9'), isNull);
      expect(PasswordValidator.validate('Pass_word-123+='), isNull);
      expect(PasswordValidator.validate('Valid^Password%9'), isNull);
    });
  });

  group('Requirement 5.2 - 5.5: Registration Error Handling & Persistence Tests', () {
    late FakeAuthApiService fakeService;
    late AuthProvider authProvider;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      fakeService = FakeAuthApiService();
      authProvider = AuthProvider(authService: fakeService);
    });

    test('5.2: Backend HTTP 400 is shown as a registration failure with exact message', () async {
      fakeService.mockDioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/register'),
          statusCode: 400,
          data: {
            'success': false,
            'message': 'Validation failed',
            'data': {
              'password': 'Password must contain at least one uppercase letter, one lowercase letter, one digit, and one special character',
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final result = await authProvider.register(
        name: 'Test User',
        email: 'test@example.com',
        phone: '+919876543210',
        password: 'weak',
      );

      expect(result.success, isFalse);
      expect(authProvider.state, equals(AuthState.unauthenticated));
      expect(authProvider.userData, isNull);
      expect(
        result.errorMessage,
        'Password must contain at least one uppercase letter, one lowercase letter, one digit, and one special character',
      );
    });

    test('5.3: Duplicate email/mobile HTTP 409 is shown correctly without creating session', () async {
      fakeService.mockDioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/register'),
          statusCode: 409,
          data: {
            'success': false,
            'message': 'This email address is already registered',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      final result = await authProvider.register(
        name: 'Duplicate User',
        email: 'admin@safeher.org',
        phone: '+919999999999',
        password: 'Password@123',
      );

      expect(result.success, isFalse);
      expect(authProvider.state, equals(AuthState.unauthenticated));
      expect(authProvider.userData, isNull);
      expect(result.errorMessage, 'This email address is already registered');
    });

    test('5.4: Network failure does not create an authenticated offline registration', () async {
      fakeService.mockDioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/register'),
        type: DioExceptionType.connectionError,
        message: 'SocketException: Connection refused',
      );

      final result = await authProvider.register(
        name: 'Offline Attempt',
        email: 'offline@example.com',
        phone: '+919876543210',
        password: 'Password@123',
      );

      // Must be false — never create a fake offline account on registration
      expect(result.success, isFalse);
      expect(authProvider.state, equals(AuthState.unauthenticated));
      expect(authProvider.userData, isNull);
      expect(result.errorMessage, contains('Unable to connect to server'));
    });

    test('5.5: Successful registration creates pending user and does NOT create authenticated session', () async {
      final result = await authProvider.register(
        name: 'Real User',
        email: 'real@example.com',
        phone: '+919876543210',
        password: 'Password@123',
      );

      // Registration must succeed, but user remains unauthenticated pending OTP verification
      expect(result.success, isTrue);
      expect(authProvider.state, equals(AuthState.unauthenticated));
      expect(authProvider.userData, isNull);
      expect(authProvider.errorMessage, isNull);
      expect(await LocalStorage.getAccessToken(), isNull);
      expect(await LocalStorage.getRefreshToken(), isNull);
    });

    test('5.6: No password, PIN, hash, JWT, or refresh token appears in error messages', () async {
      const rawPassword = 'SecretPassword@123';
      const rawPin = '9876';

      fakeService.mockDioException = DioException(
        requestOptions: RequestOptions(path: '/api/auth/register'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/auth/register'),
          statusCode: 400,
          data: {
            'success': false,
            'message': 'Phone number is already registered',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      await authProvider.register(
        name: 'Privacy Audit',
        email: 'privacy@example.com',
        phone: '+919876543210',
        password: rawPassword,
        pin: rawPin,
      );

      final errorMsg = authProvider.errorMessage ?? '';
      expect(errorMsg.contains(rawPassword), isFalse);
      expect(errorMsg.contains(rawPin), isFalse);
      expect(errorMsg.contains('jwt'), isFalse);
      expect(errorMsg.contains('token'), isFalse);
    });
  });
}
