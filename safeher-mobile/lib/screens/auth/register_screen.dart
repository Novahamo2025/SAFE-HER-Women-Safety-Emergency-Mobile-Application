import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import 'login_screen.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _pinController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Privacy Policy and Terms of Use to continue.'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      pin: _pinController.text.trim().isNotEmpty ? _pinController.text.trim() : null,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // Direct user to 6-digit OTP verification flow
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phoneOrEmail: _phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : _emailController.text.trim(),
            userName: _nameController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Join Svasheild',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your privacy-first emergency protection and safety network',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 28),

                // Full Name
                const Text(
                  'Full Name',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Priya Sharma',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.textSecondary),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter your full name.';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Email Address
                const Text(
                  'Email Address',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary),
                  ),
                  validator: (val) {
                    if (val == null || !val.contains('@')) return 'Please enter a valid email address.';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Mobile Phone
                const Text(
                  'Mobile Number (for SMS Alerts)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '+91 98765 43210',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.textSecondary),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 10) return 'Please enter a valid 10-digit mobile number.';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Password
                const Text(
                  'Account Password',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'At least 8 characters',
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
                    if (val == null || val.length < 6) return 'Password must be at least 6 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Confirm Password
                const Text(
                  'Confirm Password',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Repeat password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (val) {
                    if (val != _passwordController.text) return 'Passwords do not match.';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Terms & Privacy Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _acceptedTerms,
                        activeColor: AppTheme.brandPrimary,
                        onChanged: (val) => setState(() => _acceptedTerms = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'I agree to the Svasheild Privacy Policy and understand that my location is shared only during active emergency workflows.',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Submit Button
                SafeButton(
                  text: 'Create Account & Continue',
                  isLoading: _isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 20),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?', style: TextStyle(color: AppTheme.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
