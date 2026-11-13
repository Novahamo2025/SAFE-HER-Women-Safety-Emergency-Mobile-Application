import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/widgets/safe_button.dart';
import 'package:safeher/widgets/status_badge.dart';
import 'package:safeher/widgets/safe_card.dart';
import 'package:safeher/widgets/empty_state_widget.dart';
import 'package:safeher/widgets/permission_card.dart';
import 'package:safeher/screens/onboarding/user_guide_screen.dart';

void main() {
  testWidgets('SafeButton renders text and triggers callback on tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeButton(
            text: 'Trigger Alert',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Trigger Alert'), findsOneWidget);
    await tester.tap(find.text('Trigger Alert'));
    expect(tapped, true);
  });

  testWidgets('StatusBadge displays correct label and icon', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(
            label: 'PROTECTED',
            type: StatusBadgeType.success,
            icon: Icons.check_circle,
          ),
        ),
      ),
    );

    expect(find.text('PROTECTED'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('SafeCard renders child and responds to tap', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeCard(
            onTap: () => tapped = true,
            child: const Text('Card Content'),
          ),
        ),
      ),
    );

    expect(find.text('Card Content'), findsOneWidget);
    await tester.tap(find.text('Card Content'));
    expect(tapped, true);
  });

  testWidgets('EmptyStateWidget renders title, description, and button', (WidgetTester tester) async {
    bool buttonPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.contacts,
            title: 'No Contacts',
            description: 'Add your emergency contacts.',
            buttonText: 'Add Contact',
            onButtonPressed: () => buttonPressed = true,
          ),
        ),
      ),
    );

    expect(find.text('No Contacts'), findsOneWidget);
    expect(find.text('Add your emergency contacts.'), findsOneWidget);
    expect(find.text('Add Contact'), findsOneWidget);

    await tester.tap(find.text('Add Contact'));
    expect(buttonPressed, true);
  });

  testWidgets('PermissionCard renders title, rationale, and button', (WidgetTester tester) async {
    bool requested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionCard(
            icon: Icons.location_on,
            title: 'Location Services',
            explanation: 'Required to broadcast coordinates during SOS.',
            isGranted: false,
            onRequest: () => requested = true,
          ),
        ),
      ),
    );

    expect(find.text('Location Services'), findsOneWidget);
    expect(find.text('Required to broadcast coordinates during SOS.'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);

    await tester.tap(find.text('Allow'));
    expect(requested, true);
  });

  testWidgets('User guide shows step count and clear navigation labels', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserGuideScreen(),
      ),
    );

    expect(find.text('Step 1 of 6'), findsOneWidget);
    expect(find.text('Previous'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
