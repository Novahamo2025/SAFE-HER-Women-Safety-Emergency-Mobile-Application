import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../auth/login_screen.dart';
import '../onboarding/user_guide_screen.dart';
import '../../core/theme/theme_provider.dart';
import 'privacy_permissions_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameCtrl = TextEditingController(text: auth.userName);
    final emailCtrl = TextEditingController(text: auth.userEmail);
    final phoneCtrl = TextEditingController(text: auth.userPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_outlined)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              auth.updateProfile(
                name: nameCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated successfully!')),
              );
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, AuthProvider auth) {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Security PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a new 4-6 digit security PIN for resolving emergencies:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'New PIN', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'Confirm PIN', counterText: ''),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text.trim().length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be at least 4 digits.')),
                );
                return;
              }
              if (pinCtrl.text.trim() != confirmCtrl.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match.')),
                );
                return;
              }
              auth.setUserPin(pinCtrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Security PIN updated.'),
                  backgroundColor: AppTheme.safeGreen,
                ),
              );
            },
            child: const Text('Update PIN'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose App Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              title: const Text('System Default'),
              subtitle: const Text('Matches device appearance'),
              secondary: const Icon(Icons.brightness_auto_outlined),
              onChanged: (mode) {
                if (mode != null) {
                  themeProvider.setThemeMode(mode);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              title: const Text('Light Theme'),
              subtitle: const Text('Clean, bright display'),
              secondary: const Icon(Icons.light_mode_outlined),
              onChanged: (mode) {
                if (mode != null) {
                  themeProvider.setThemeMode(mode);
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              title: const Text('Dark Theme'),
              subtitle: const Text('Dark slate, battery efficient'),
              secondary: const Icon(Icons.dark_mode_outlined),
              onChanged: (mode) {
                if (mode != null) {
                  themeProvider.setThemeMode(mode);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _showInfoModal(BuildContext context, String title, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SafeButton(text: 'Understood', onPressed: () => Navigator.pop(ctx)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card
            SafeCard(
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.brandPrimary, AppTheme.brandPrimaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.userName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auth.userEmail,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          auth.userPhone,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppTheme.brandPrimary),
                    onPressed: () => _showEditProfileDialog(context, auth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Security & PIN Section
            Text(
              'Security & Access',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),

            SafeCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pin, color: AppTheme.brandPrimary, size: 20),
                    ),
                    title: const Text('Change Security PIN', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('PIN required to end active SOS', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => _showChangePinDialog(context, auth),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Appearance & Customization Section
            Text(
              'Appearance & Experience',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),

            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                String themeSubtitle = 'System Default';
                IconData themeIcon = Icons.brightness_auto_outlined;
                if (themeProvider.themeMode == ThemeMode.light) {
                  themeSubtitle = 'Light Theme Active';
                  themeIcon = Icons.light_mode_outlined;
                } else if (themeProvider.themeMode == ThemeMode.dark) {
                  themeSubtitle = 'Dark Theme Active';
                  themeIcon = Icons.dark_mode_outlined;
                }

                return SafeCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(themeIcon, color: const Color(0xFF8B5CF6), size: 20),
                        ),
                        title: const Text('App Theme & Display', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(themeSubtitle, style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                        onTap: () => _showThemeDialog(context, themeProvider),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.infoLightBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.menu_book_outlined, color: AppTheme.infoBlue, size: 20),
                        ),
                        title: const Text('Interactive User Guide', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: const Text('Walkthrough of SOS, safety tools & features', style: TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UserGuideScreen(isReviewMode: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Privacy & Permissions Section
            Text(
              'Privacy & Transparency',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),

            SafeCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.safeGreenLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.privacy_tip_outlined, color: AppTheme.safeGreen, size: 20),
                    ),
                    title: const Text('Privacy & Permissions Center', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Manage location, retention, and data controls', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PrivacyPermissionsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Legal & Disclaimers
            Text(
              'About & Legal',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 10),

            SafeCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 20),
                    title: const Text('About SvaShield', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Version 1.0.0 • Production Build', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => _showInfoModal(
                      context,
                      'About SvaShield',
                      'SvaShield is a comprehensive women safety, emergency SOS, live location, safe journey, and trusted contact management system engineered for high-stress reliability and privacy-first data protection.',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.gavel_outlined, color: AppTheme.textSecondary, size: 20),
                    title: const Text('Emergency Terms & Disclaimer', style: TextStyle(fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => _showInfoModal(
                      context,
                      'Emergency Disclaimer',
                      'SvaShield is a safety companion tool that alerts designated trusted emergency contacts and facilitates location broadcasting. In life-threatening emergencies, always dial national emergency numbers (112 / 100 / 1091) whenever feasible.',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined, color: AppTheme.textSecondary, size: 20),
                    title: const Text('Privacy Policy', style: TextStyle(fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                    onTap: () => _showInfoModal(
                      context,
                      'Privacy Policy Summary',
                      'SvaShield does not track your location continuously in the background. GPS coordinates are collected and broadcast only during active SOS alerts or monitored Safe Walk sessions, with a strict 7-day retention limit.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Logout Button
            SafeButton(
              text: 'Log Out of SvaShield',
              icon: Icons.logout,
              type: SafeButtonType.outline,
              onPressed: () async {
                await auth.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
