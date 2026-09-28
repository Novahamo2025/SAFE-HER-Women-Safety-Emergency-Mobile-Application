import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import '../dashboard/dashboard_screen.dart';
import 'otp_verification_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController(text: 'anu@safeher.app');
  final _passwordController = TextEditingController(text: 'Password123!');
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
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
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
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
                    child: Image.asset(
                      'assets/images/svasheild_logo.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Welcome to Svasheild',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Sign in to access your personal safety dashboard',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
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
                            border: Border.all(color: AppTheme.emergencyRed.withOpacity(0.3)),
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
                  const Text(
                    'Email or Mobile Number',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'name@example.com or phone',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your registered email or phone.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Password field
                  const Text(
                    'Password or PIN',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password or PIN',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textSecondary,
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
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OtpVerificationScreen(
                            phoneOrEmail: _identifierController.text.trim().isNotEmpty
                                ? _identifierController.text.trim()
                                : '+91 98765 43210',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Switch to Register
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
