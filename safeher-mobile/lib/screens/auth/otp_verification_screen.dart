import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/storage/local_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/phone_validator.dart';
import '../../widgets/safe_button.dart';
import '../dashboard/dashboard_screen.dart';
import '../onboarding/permission_onboarding_screen.dart';
import '../onboarding/user_guide_screen.dart';
import 'pin_setup_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneOrEmail;
  final String? userName;

  const OtpVerificationScreen({
    super.key,
    required this.phoneOrEmail,
    this.userName,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  int _secondsRemaining = 45;
  Timer? _timer;
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown(45);
  }

  void _startCountdown([int seconds = 45]) {
    _secondsRemaining = seconds > 0 ? seconds : 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if (mounted) {
          setState(() => _secondsRemaining--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredOtp => _controllers.map((c) => c.text.trim()).join();

  void _onOtpChanged(int index, String value) {
    if (value.length > 1) {
      // Handle paste or auto-fill containing multiple digits
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        _focusNodes[5].unfocus();
        _handleVerify();
      } else if (digits.isNotEmpty) {
        final nextIdx = digits.length < 6 ? digits.length : 5;
        _focusNodes[nextIdx].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _handleVerify();
      }
    } else if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerify() async {
    if (_isLoading) return;
    final otp = _enteredOtp;
    if (otp.length < 6) {
      setState(() {
        _errorMessage = 'Please enter complete 6-digit verification code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final normalizedPhone = PhoneValidator.normalize(widget.phoneOrEmail);
    final success = await authProvider.verifyOtp(
      phone: normalizedPhone,
      otp: otp,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // Verify user has PIN set or onboarding completed
      final pin = await LocalStorage.getUserPin();
      final hasCompletedPerms = await PermissionOnboardingScreen.hasCompleted();
      final hasCompletedGuide = await UserGuideScreen.hasCompletedGuide();
      if (!mounted) return;

      if (pin == null || pin.isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PinSetupScreen(
              phoneOrEmail: widget.phoneOrEmail,
              userName: widget.userName,
            ),
          ),
        );
      } else if (!hasCompletedPerms) {
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
    } else {
      setState(() {
        _errorMessage = authProvider.errorMessage ?? 'Verification failed. Please check the code and try again.';
      });
    }
  }

  Future<void> _handleResend() async {
    if (_isResending || _secondsRemaining > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final normalizedPhone = PhoneValidator.normalize(widget.phoneOrEmail);

    final result = await authProvider.resendOtp(normalizedPhone);

    if (!mounted) return;
    setState(() => _isResending = false);

    _startCountdown(result.cooldownSeconds);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? AppTheme.brandPrimary : AppTheme.warningAmber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Phone Verification'),
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
                child: const Icon(Icons.mark_email_read_outlined, color: AppTheme.brandPrimary, size: 28),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter Verification Code',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit security code to ${widget.phoneOrEmail}',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 32),

              // OTP 6-Digit input boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 48,
                    height: 56,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        fillColor: AppTheme.surfaceMuted,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.borderLight),
                        ),
                      ),
                      onChanged: (value) => _onOtpChanged(index, value),
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.emergencyRed, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppTheme.emergencyRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // Resend Countdown
              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        'Resend code in $_secondsRemaining seconds',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      )
                    : _isResending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Resend Code Now'),
                            onPressed: _handleResend,
                          ),
              ),

              const SizedBox(height: 36),

              SafeButton(
                text: 'Verify & Continue',
                isLoading: _isLoading,
                onPressed: _handleVerify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
