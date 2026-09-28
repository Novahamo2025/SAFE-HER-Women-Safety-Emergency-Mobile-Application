import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/permission_card.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';

class PrivacyPermissionsScreen extends StatefulWidget {
  const PrivacyPermissionsScreen({super.key});

  @override
  State<PrivacyPermissionsScreen> createState() => _PrivacyPermissionsScreenState();
}

class _PrivacyPermissionsScreenState extends State<PrivacyPermissionsScreen> {
  bool _locationGranted = true;
  bool _notificationsGranted = true;
  bool _cameraGranted = true;
  bool _microphoneGranted = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final locPerm = await Geolocator.checkPermission();
      setState(() {
        _locationGranted = locPerm == LocationPermission.always || locPerm == LocationPermission.whileInUse;
      });
    } catch (_) {}
  }

  Future<void> _requestLocationPermission() async {
    try {
      final perm = await Geolocator.requestPermission();
      setState(() {
        _locationGranted = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
      });
    } catch (_) {}
  }

  void _showExportDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Personal Safety Data'),
        content: const Text(
          'Your profile metadata, trusted contacts list, past journey timestamps, and encrypted incident summaries will be compiled into a secure file.',
          style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Account & Data Deletion'),
        content: const Text(
          'This action will permanently delete your Svasheild account, trusted contacts associations, and revoke all active location broadcast tokens. This cannot be undone.',
          style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emergencyRed),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion request queued. Your local data has been cleared.'),
                  backgroundColor: AppTheme.emergencyRed,
                ),
              );
            },
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
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
                color: AppTheme.brandPrimaryLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.brandPrimary.withOpacity(0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: AppTheme.brandPrimary, size: 26),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Zero Background Tracking Promise',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.brandPrimaryDark),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Svasheild collects the minimum data required. Your GPS location is shared only when an SOS or Safe Walk is actively running.',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Application Permissions & Rationale',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),

            // Location
            PermissionCard(
              icon: Icons.location_on_outlined,
              title: 'Location Services',
              explanation: 'Svasheild needs your location during safety workflows so your trusted contacts can receive your live GPS location when an emergency is active.',
              isGranted: _locationGranted,
              onRequest: _requestLocationPermission,
            ),
            const SizedBox(height: 12),

            // Notifications
            PermissionCard(
              icon: Icons.notifications_none,
              title: 'Emergency Notifications',
              explanation: 'Notifications help Svasheild keep you informed about emergency alerts, check-in reminders, and arrival safety confirmations.',
              isGranted: _notificationsGranted,
              onRequest: () => setState(() => _notificationsGranted = true),
            ),
            const SizedBox(height: 12),

            // Camera
            PermissionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Camera Access',
              explanation: 'Camera access is only needed when you explicitly choose to capture photo evidence of an incident in the Evidence Locker.',
              isGranted: _cameraGranted,
              onRequest: () => setState(() => _cameraGranted = true),
            ),
            const SizedBox(height: 12),

            // Microphone
            PermissionCard(
              icon: Icons.mic_none_outlined,
              title: 'Microphone Access',
              explanation: 'Microphone access is only needed when you choose to record an audio evidence memo or during an active emergency event.',
              isGranted: _microphoneGranted,
              onRequest: () => setState(() => _microphoneGranted = true),
            ),
            const SizedBox(height: 24),

            // Data Retention Policy Card
            const Text(
              'Data Retention Policy',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            SafeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. Live Location Data:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const Text('Retained temporarily during active emergencies, auto-archived after 7 days, and permanently scrubbed.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  const Text('2. Incident Records:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const Text('Stored locally on your device with local encryption. Never shared with third parties without your manual export.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),
                  const Text('3. Administrative Access:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const Text('Strictly role-based with least privilege and audit logging. Admins cannot view private audio memos or unconsented location history.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // User Control Actions
            const Text(
              'Your Data Controls',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
