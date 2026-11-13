import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import '../dashboard/dashboard_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';
import '../../core/utils/phone_validator.dart';
import '../onboarding/permission_onboarding_screen.dart';
import '../onboarding/user_guide_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isOtpLoading = false;
  String? _otpPhoneError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleOtpSignIn() async {
    if (_isOtpLoading || _isLoading) return;

    final rawInput = _identifierController.text;
    final validationError = PhoneValidator.validate(rawInput);

    if (validationError != null) {
      setState(() {
        _otpPhoneError = validationError;
      });
      _identifierFocusNode.requestFocus();
      return;
    }

    setState(() {
      _otpPhoneError = null;
      _isOtpLoading = true;
    });

    final normalizedPhone = PhoneValidator.normalize(rawInput);
    final authProvider = context.read<AuthProvider>();

    final result = await authProvider.sendOtp(normalizedPhone);

    if (!mounted) return;
    setState(() => _isOtpLoading = false);

    if (result['success'] == true) {
      final isMock = result['isMock'] == true;
      if (isMock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Simulation Mode: SMS delivery is simulated.'),
            backgroundColor: AppTheme.warningAmber,
          ),
        );
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneOrEmail: normalizedPhone,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] as String? ?? 'Failed to send verification code.'),
          backgroundColor: AppTheme.emergencyRed,
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.login(
      identifier: _identifierController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
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
    } else {
      final errorMsg = authProvider.errorMessage ?? 'Login failed. Please check your credentials.';
      final isUnverified = errorMsg.contains('not verified') || errorMsg.contains('OTP verification');

      if (isUnverified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.warningAmber,
            action: SnackBarAction(
              label: 'Verify Now',
              textColor: Colors.white,
              onPressed: () {
                final rawIdentifier = _identifierController.text.trim();
                final phoneOrEmail = rawIdentifier.contains('@')
                    ? rawIdentifier
                    : PhoneValidator.normalize(rawIdentifier);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OtpVerificationScreen(
                      phoneOrEmail: phoneOrEmail,
                    ),
                  ),
                );
              },
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.emergencyRed,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _identifierController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password or PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email or phone number to receive a secure recovery code:',
              style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email or Phone',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OtpVerificationScreen(
                    phoneOrEmail: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : 'your mobile',
                  ),
                ),
              );
            },
            child: const Text('Send Code'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/images/svashield_logo.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Welcome to SvaShield',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Sign in to access your personal safety dashboard',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Error Banner
                  Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      if (auth.errorMessage != null && auth.state == AuthState.unauthenticated) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.emergencyLightRed,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.emergencyRed.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppTheme.emergencyRed, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  auth.errorMessage!,
                                  style: const TextStyle(color: AppTheme.emergencyDarkRed, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  // Identifier field
                  Text(
                    'Email or Mobile Number',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _identifierController,
                    focusNode: _identifierFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'name@example.com or phone',
                      prefixIcon: Icon(Icons.person_outline, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
                      errorText: _otpPhoneError,
                    ),
                    onChanged: (val) {
                      if (_otpPhoneError != null) {
                        setState(() => _otpPhoneError = null);
                      }
                    },
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your registered email or phone.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password field
                  Text(
                    'Password or PIN',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter your password or PIN',
                      prefixIcon: Icon(Icons.lock_outline, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) {
                        return 'Please enter your password.';
                      }
                      return null;
                    },
                  ),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text('Forgot Password / PIN?'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Button
                  SafeButton(
                    text: 'Sign In',
                    isLoading: _isLoading,
                    onPressed: _handleLogin,
                  ),
                  const SizedBox(height: 14),

                  // OTP Quick Login Alternative
                  SafeButton(
                    text: 'Sign In with OTP Verification',
                    type: SafeButtonType.secondary,
                    icon: Icons.sms_outlined,
                    isLoading: _isOtpLoading,
                    onPressed: (_isOtpLoading || _isLoading) ? null : _handleOtpSignIn,
                  ),
                  const SizedBox(height: 28),

                  // Switch to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary, fontSize: 14),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
