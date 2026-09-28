import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:safeher/core/auth/auth_provider.dart';
import 'package:safeher/core/providers/contact_provider.dart';
import 'package:safeher/core/providers/emergency_provider.dart';
import 'package:safeher/core/providers/journey_provider.dart';
import 'package:safeher/core/providers/checkin_provider.dart';
import 'package:safeher/core/providers/toolkit_provider.dart';
import 'package:safeher/core/theme/app_theme.dart';
import 'package:safeher/screens/dashboard/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen smoke test - verifies core safety controls', (WidgetTester tester) async {
    final checkinProv = CheckInProvider();
    final journeyProv = JourneyProvider();
    final emergencyProv = EmergencyProvider();
    final contactProv = ContactProvider();
    final authProv = AuthProvider();
    final toolkitProv = ToolkitProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authProv),
          ChangeNotifierProvider.value(value: contactProv),
          ChangeNotifierProvider.value(value: emergencyProv),
          ChangeNotifierProvider.value(value: journeyProv),
          ChangeNotifierProvider.value(value: checkinProv),
          ChangeNotifierProvider.value(value: toolkitProv),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DashboardScreen(),
        ),
      ),
    );

    // Allow async providers to settle
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Svasheild'), findsOneWidget);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Safe Walk'), findsOneWidget);
    expect(find.text('Safety Check-In'), findsOneWidget);

    // Cleanly cancel provider tickers for test completion
    checkinProv.dispose();
    journeyProv.dispose();
    emergencyProv.dispose();
  });
}
