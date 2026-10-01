class ApiConstants {
  // Use 10.0.2.2 for Android Emulator, or your local machine IP (e.g. 192.168.1.X) for physical devices
  static const String baseUrl = 'http://10.0.2.2:8081/api';

  // Auth endpoints
  static const String register = '$baseUrl/auth/register';
  static const String login = '$baseUrl/auth/login';
  static const String refreshToken = '$baseUrl/auth/refresh';
  static const String logout = '$baseUrl/auth/logout';

  // Emergency endpoints
  static const String emergencyStart = '$baseUrl/emergency/start';
  static String emergencyLocation(int eventId) =>
      '$baseUrl/emergency/$eventId/location';
  static String emergencyCancel(int eventId) =>
      '$baseUrl/emergency/$eventId/cancel';
  static String emergencyStatus(int eventId) => '$baseUrl/emergency/$eventId';

  // Contacts endpoints
  static const String contacts = '$baseUrl/contacts';
  static String contactDetail(int contactId) => '$baseUrl/contacts/$contactId';

  // Journey & Checkin endpoints
  static const String journeys = '$baseUrl/journeys';
  static String journeyCheckIn(int journeyId) =>
      '$baseUrl/journeys/$journeyId/check-in';
  static String journeyComplete(int journeyId) =>
      '$baseUrl/journeys/$journeyId/complete';
  static String journeyCancel(int journeyId) =>
      '$baseUrl/journeys/$journeyId/cancel';
  static const String checkins = '$baseUrl/checkins';
  static String checkinComplete(int checkinId) =>
      '$baseUrl/checkins/$checkinId/complete';
  static String checkinMissed(int checkinId) =>
      '$baseUrl/checkins/$checkinId/missed';
  static String checkinEscalate(int checkinId) =>
      '$baseUrl/checkins/$checkinId/escalate';
  static String checkinCancel(int checkinId) =>
      '$baseUrl/checkins/$checkinId/cancel';
}
