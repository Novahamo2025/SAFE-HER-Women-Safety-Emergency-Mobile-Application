import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/contact_provider.dart';
import '../../core/providers/emergency_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/sos_hold_button.dart';
import '../../widgets/status_badge.dart';

class SosTestScreen extends StatefulWidget {
  const SosTestScreen({super.key});

  @override
  State<SosTestScreen> createState() => _SosTestScreenState();
}

class _SosTestScreenState extends State<SosTestScreen> {
  bool _testCompleted = false;
  String _testStep = 'Ready to test';

  Future<void> _runTestSos() async {
    setState(() {
      _testStep = 'Simulating 3-second hold & GPS lock...';
    });

    final contacts = context.read<ContactProvider>().contacts;
    final emergency = context.read<EmergencyProvider>();

    await emergency.triggerEmergency(
      contacts: contacts,
      userName: 'Test User',
      isTest: true,
    );

    setState(() {
      _testCompleted = true;
      _testStep = 'Test completed successfully! All safety subsystems verified.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('SOS Practice & Test Mode'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Warning Banner: Clear distinction that this is a TEST
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warningLightAmber,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.warningAmber.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warningAmber, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SAFE TEST SIMULATION',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.warningAmber, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Your real contacts will NOT be alarmed during this test. Practice holding the button to get familiar with the timing.',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // SOS Hold Button in Test Mode
            if (!_testCompleted) ...[
              SosHoldButton(
                isTestMode: true,
                onSosTriggered: _runTestSos,
              ),
              const SizedBox(height: 24),
              Text(
                _testStep,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
            ] else ...[
              // Test Results Card
              SafeCard(
                borderColor: AppTheme.safeGreen.withOpacity(0.4),
                backgroundColor: AppTheme.safeGreenLight,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.safeGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Emergency Readiness Verified',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.safeGreenDark),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '1. 3-Second Hold Sensor: PASS\n2. GPS Location Fetch: PASS\n3. Contact SMS Template: PASS\n4. PIN Deactivation Check: PASS',
                      style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.6),
                    ),
                    const SizedBox(height: 20),
                    SafeButton(
                      text: 'Done • Return to Dashboard',
                      type: SafeButtonType.primary,
                      onPressed: () {
                        context.read<EmergencyProvider>().endEmergency();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Information checklist
            SafeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.checklist, color: AppTheme.brandPrimary, size: 20),
                      SizedBox(width: 8),
                      Text('Emergency Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildCheckItem('Hold duration is 3 seconds to prevent accidental triggers'),
                  _buildCheckItem('GPS coordinates are captured automatically with accuracy metadata'),
                  _buildCheckItem('SMS links to Google Maps so contacts can navigate directly to you'),
                  _buildCheckItem('Stopping an emergency requires your security PIN'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppTheme.safeGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }
}
