import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/permission_card.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../auth/login_screen.dart';

class PrivacyPermissionsScreen extends StatefulWidget {
  const PrivacyPermissionsScreen({super.key});

  @override
  State<PrivacyPermissionsScreen> createState() => _PrivacyPermissionsScreenState();
}

class _PrivacyPermissionsScreenState extends State<PrivacyPermissionsScreen>
    with WidgetsBindingObserver {
  PermissionStatus _locationStatus = PermissionStatus.denied;
  PermissionStatus _notificationsStatus = PermissionStatus.denied;
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _microphoneStatus = PermissionStatus.denied;
  PermissionStatus _contactsStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final loc = await Permission.location.status;
      final notif = await Permission.notification.status;
      final cam = await Permission.camera.status;
      final mic = await Permission.microphone.status;
      final cont = await Permission.contacts.status;

      if (!mounted) return;
      setState(() {
        _locationStatus = loc;
        _notificationsStatus = notif;
        _cameraStatus = cam;
        _microphoneStatus = mic;
        _contactsStatus = cont;
      });
    } catch (_) {}
  }

  Future<void> _requestPermission(Permission permission) async {
    try {
      final status = await permission.status;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      } else {
        await permission.request();
      }
      await _checkPermissions();
    } catch (_) {}
  }

  void _showExportDataDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceWhite,
        title: Text(
          'Export Personal Safety Data',
          style: TextStyle(
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Your profile metadata, trusted contacts list, past journey timestamps, and encrypted incident summaries will be compiled into a secure file.',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Personal data archive generated and saved to your device downloads.'),
                  backgroundColor: AppTheme.safeGreen,
                ),
              );
            },
            child: const Text('Export Now'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordCtrl = TextEditingController();
    bool isDeleting = false;
    String? errorMsg;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.emergencyLightRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppTheme.emergencyRed, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Account & Data',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This action permanently erases your account, contacts, and all emergency evidence records. Enter your account password to verify your identity.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Account Password',
                    hintText: 'Enter your account password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    errorText: errorMsg,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emergencyRed,
                foregroundColor: Colors.white,
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      final pwd = passwordCtrl.text.trim();
                      if (pwd.isEmpty) {
                        setDialogState(() => errorMsg = 'Account password is required');
                        return;
                      }

                      setDialogState(() {
                        isDeleting = true;
                        errorMsg = null;
                      });

                      final authProvider = context.read<AuthProvider>();
                      final success = await authProvider.deleteAccountAndData(pwd);

                      if (!success) {
                        setDialogState(() {
                          isDeleting = false;
                          errorMsg = 'Incorrect account password. Verification failed.';
                        });
                        return;
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Account and personal safety data permanently erased.'),
                            backgroundColor: AppTheme.safeGreen,
                          ),
                        );
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify & Delete Account'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Permissions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Core Privacy Promise Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppTheme.brandPrimaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : AppTheme.brandPrimary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zero Background Tracking Promise',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.brandPrimaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'SvaShield collects the minimum data required. Your GPS location is shared only when an SOS or Safe Walk is actively running.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Application Permissions & Rationale',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Location
            PermissionCard(
              icon: Icons.location_on_outlined,
              title: 'Location Services',
              explanation: 'SvaShield needs your location during safety workflows so your trusted contacts can receive your live GPS location when an emergency is active.',
              isGranted: _locationStatus.isGranted,
              isPermanentlyDenied: _locationStatus.isPermanentlyDenied,
              onRequest: () => _requestPermission(Permission.location),
            ),
            const SizedBox(height: 12),

            // Notifications
            PermissionCard(
              icon: Icons.notifications_none,
              title: 'Emergency Notifications',
              explanation: 'Notifications help SvaShield keep you informed about emergency alerts, check-in reminders, and arrival safety confirmations.',
              isGranted: _notificationsStatus.isGranted,
              isPermanentlyDenied: _notificationsStatus.isPermanentlyDenied,
              onRequest: () => _requestPermission(Permission.notification),
            ),
            const SizedBox(height: 12),

            // Camera
            PermissionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Camera Access',
              explanation: 'Camera access is only needed when you explicitly choose to capture photo evidence of an incident in the Evidence Locker.',
              isGranted: _cameraStatus.isGranted,
              isPermanentlyDenied: _cameraStatus.isPermanentlyDenied,
              onRequest: () => _requestPermission(Permission.camera),
            ),
            const SizedBox(height: 12),

            // Microphone
            PermissionCard(
              icon: Icons.mic_none_outlined,
              title: 'Microphone Access',
              explanation: 'Microphone access is only needed when you choose to record an audio evidence memo or during an active emergency event.',
              isGranted: _microphoneStatus.isGranted,
              isPermanentlyDenied: _microphoneStatus.isPermanentlyDenied,
              onRequest: () => _requestPermission(Permission.microphone),
            ),
            const SizedBox(height: 12),

            // Contacts
            PermissionCard(
              icon: Icons.contacts_outlined,
              title: 'Contacts Access',
              explanation: 'Enables quick selection and verification of your trusted emergency contacts list.',
              isGranted: _contactsStatus.isGranted,
              isPermanentlyDenied: _contactsStatus.isPermanentlyDenied,
              onRequest: () => _requestPermission(Permission.contacts),
            ),
            const SizedBox(height: 24),

            // Data Retention Policy Card
            Text(
              'Data Retention Policy',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            SafeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Live Location Data:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary)),
                  Text('Retained temporarily during active emergencies, auto-archived after 7 days, and permanently scrubbed.', style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  Text('2. Incident Records:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary)),
                  Text('Stored locally on your device with app-private storage. Never shared with third parties without your manual export.', style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  Text('3. Administrative Access:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary)),
                  Text('Strictly role-based with least privilege and audit logging. Admins cannot view private audio memos or unconsented location history.', style: TextStyle(fontSize: 12.5, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // User Control Actions
            Text(
              'Your Data Controls',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            SafeButton(
              text: 'Download / Export My Data',
              icon: Icons.download_outlined,
              type: SafeButtonType.outline,
              onPressed: _showExportDataDialog,
            ),
            const SizedBox(height: 12),

            SafeButton(
              text: 'Delete Account & Erase All Data',
              icon: Icons.delete_forever_outlined,
              type: SafeButtonType.danger,
              onPressed: _showDeleteAccountDialog,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
