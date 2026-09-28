import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _secondsRemaining = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
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

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
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

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // Proceed to Secure PIN setup screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          phoneOrEmail: widget.phoneOrEmail,
          userName: widget.userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Verification'),
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
                      onChanged: (value) {
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
                      },
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
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

              const SizedBox(height: 28),

              // Resend Countdown
              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        'Resend code in $_secondsRemaining seconds',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      )
                    : TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Resend Code Now'),
                        onPressed: () {
                          _startCountdown();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('A new verification code has been dispatched.')),
                          );
                        },
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
