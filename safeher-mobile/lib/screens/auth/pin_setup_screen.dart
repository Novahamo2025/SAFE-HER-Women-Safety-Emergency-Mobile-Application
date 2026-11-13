import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import '../dashboard/dashboard_screen.dart';
import '../onboarding/permission_onboarding_screen.dart';
import '../onboarding/user_guide_screen.dart';

class PinSetupScreen extends StatefulWidget {
  final String? phoneOrEmail;
  final String? userName;

  const PinSetupScreen({
    super.key,
    this.phoneOrEmail,
    this.userName,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleSavePin() async {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin.length < 4) {
      setState(() {
        _errorMessage = 'PIN must be at least 4 digits.';
      });
      return;
    }

    if (pin != confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please verify.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    await authProvider.setUserPin(pin);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Security PIN created successfully! Welcome to SvaShield.'),
        backgroundColor: AppTheme.safeGreen,
      ),
    );

    final hasCompletedPerms = await PermissionOnboardingScreen.hasCompleted();
    final hasCompletedGuide = await UserGuideScreen.hasCompletedGuide();
    if (!mounted) return;

    if (!hasCompletedPerms) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PermissionOnboardingScreen()),
      );
    } else if (!hasCompletedGuide) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserGuideScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Setup Security PIN'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shield_outlined, color: AppTheme.brandPrimary, size: 28),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create Your Safety PIN',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'This PIN prevents unauthorized persons from canceling your SOS or accessing private incident evidence.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),

              // PIN Input
              const Text(
                'Enter 4-6 Digit Security PIN',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Confirm PIN
              const Text(
                'Confirm Security PIN',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  fillColor: AppTheme.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.emergencyRed, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.emergencyRed, fontSize: 13),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Informational trust card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.infoLightBlue,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.infoBlue, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your PIN is stored locally on this device in secure storage and is never transmitted in plain text.',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              SafeButton(
                text: 'Complete Setup & Go to App',
                isLoading: _isLoading,
                onPressed: _handleSavePin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
