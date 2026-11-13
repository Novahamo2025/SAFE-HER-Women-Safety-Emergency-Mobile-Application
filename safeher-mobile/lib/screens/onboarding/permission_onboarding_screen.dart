import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/permission_card.dart';
import '../../widgets/safe_button.dart';
import '../dashboard/dashboard_screen.dart';
import 'user_guide_screen.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const PermissionOnboardingScreen({
    super.key,
    this.onComplete,
  });

  static const String prefKey = 'has_completed_permission_onboarding';

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, true);
  }

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;

  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _microphoneStatus = PermissionStatus.denied;
  PermissionStatus _contactsStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isLoading = true);
    final loc = await Permission.location.status;
    final notif = await Permission.notification.status;
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    final cont = await Permission.contacts.status;

    if (!mounted) return;
    setState(() {
      _locationStatus = loc;
      _notificationStatus = notif;
      _cameraStatus = cam;
      _microphoneStatus = mic;
      _contactsStatus = cont;
      _isLoading = false;
    });
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.status;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await permission.request();
    }
    await _checkAllPermissions();
  }

  Future<void> _grantAllSequential() async {
    if (!_locationStatus.isGranted) {
      await Permission.location.request();
    }
    if (!_notificationStatus.isGranted) {
      await Permission.notification.request();
    }
    if (!_cameraStatus.isGranted) {
      await Permission.camera.request();
    }
    if (!_microphoneStatus.isGranted) {
      await Permission.microphone.request();
    }
    if (!_contactsStatus.isGranted) {
      await Permission.contacts.request();
    }
    await _checkAllPermissions();
  }

  void _proceed() async {
    await PermissionOnboardingScreen.markCompleted();
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      final hasCompletedGuide = await UserGuideScreen.hasCompletedGuide();
      if (!mounted) return;
      if (!hasCompletedGuide) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const UserGuideScreen(),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final allGranted = _locationStatus.isGranted &&
        _notificationStatus.isGranted &&
        _cameraStatus.isGranted &&
        _microphoneStatus.isGranted &&
        _contactsStatus.isGranted;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Device Permissions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _proceed,
            child: Text(
              'Skip',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Information header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : AppTheme.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : AppTheme.brandPrimary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_rounded,
                            color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SvaShield Privacy & Safety Setup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.brandPrimaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'To protect you instantly during an emergency, SvaShield requires essential device permissions. Your data remains strictly private and encrypted.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Permission 1: Location
                    PermissionCard(
                      icon: Icons.location_on_rounded,
                      title: 'Precise GPS Location',
                      explanation:
                          'Essential for transmitting your real-time coordinates to trusted contacts when an SOS or Safe Walk session is activated.',
                      isGranted: _locationStatus.isGranted,
                      isPermanentlyDenied: _locationStatus.isPermanentlyDenied,
                      onRequest: () => _requestPermission(Permission.location),
                    ),
                    const SizedBox(height: 12),

                    // Permission 2: Notifications
                    PermissionCard(
                      icon: Icons.notifications_active_rounded,
                      title: 'Emergency Notifications',
                      explanation:
                          'Keeps you informed about active SOS telemetry, background tracking status, and critical safety check-in reminders.',
                      isGranted: _notificationStatus.isGranted,
                      isPermanentlyDenied: _notificationStatus.isPermanentlyDenied,
                      onRequest: () => _requestPermission(Permission.notification),
                    ),
                    const SizedBox(height: 12),

                    // Permission 3: Camera
                    PermissionCard(
                      icon: Icons.camera_alt_rounded,
                      title: 'Camera Access',
                      explanation:
                          'Allows capturing photo and video evidence directly into the encrypted Safety Toolkit Evidence Locker during incidents.',
                      isGranted: _cameraStatus.isGranted,
                      isPermanentlyDenied: _cameraStatus.isPermanentlyDenied,
                      onRequest: () => _requestPermission(Permission.camera),
                    ),
                    const SizedBox(height: 12),

                    // Permission 4: Microphone
                    PermissionCard(
                      icon: Icons.mic_rounded,
                      title: 'Microphone & Audio',
                      explanation:
                          'Enables discreet voice memo recording and ambient audio capture when suspicious activity or danger is detected.',
                      isGranted: _microphoneStatus.isGranted,
                      isPermanentlyDenied: _microphoneStatus.isPermanentlyDenied,
                      onRequest: () => _requestPermission(Permission.microphone),
                    ),
                    const SizedBox(height: 12),

                    // Permission 5: Contacts
                    PermissionCard(
                      icon: Icons.contacts_rounded,
                      title: 'Trusted Contacts Access',
                      explanation:
                          'Enables seamless selection and setup of your emergency circle without manually typing contact information.',
                      isGranted: _contactsStatus.isGranted,
                      isPermanentlyDenied: _contactsStatus.isPermanentlyDenied,
                      onRequest: () => _requestPermission(Permission.contacts),
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    if (!allGranted) ...[
                      SafeButton(
                        text: 'Grant All Permissions',
                        icon: Icons.security_rounded,
                        type: SafeButtonType.primary,
                        onPressed: _grantAllSequential,
                      ),
                      const SizedBox(height: 12),
                    ],

                    SafeButton(
                      text: allGranted ? 'Proceed to User Guide' : 'Continue Anyway',
                      icon: Icons.arrow_forward_rounded,
                      type: allGranted ? SafeButtonType.primary : SafeButtonType.outline,
                      onPressed: _proceed,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
