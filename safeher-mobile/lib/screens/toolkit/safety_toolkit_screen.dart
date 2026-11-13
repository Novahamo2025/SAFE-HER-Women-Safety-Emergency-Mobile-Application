import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/toolkit_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_card.dart';
import '../emergency/sos_test_screen.dart';
import 'ambient_audio_sheet.dart';
import 'incident_record_screen.dart';
import 'nearby_police_screen.dart';
import 'vehicle_photo_sheet.dart';

class SafetyToolkitScreen extends StatelessWidget {
  const SafetyToolkitScreen({super.key});

  Future<void> _callHelpline(BuildContext context, String number, String name) async {
    final uri = Uri.parse('tel:$number');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Calling $name: $number')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dialing $name: $number')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final toolkit = context.watch<ToolkitProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Safety Toolkit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instant Tools',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Flashlight & Siren Tiles Row
            Row(
              children: [
                // Flashlight Toggle
                Expanded(
                  child: SafeCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: toolkit.isFlashlightOn
                        ? (isDark ? Colors.amber.shade900.withValues(alpha: 0.3) : Colors.amber.shade50)
                        : null,
                    borderColor: toolkit.isFlashlightOn
                        ? (isDark ? Colors.amber.shade600 : Colors.amber.shade400)
                        : null,
                    onTap: () => toolkit.toggleFlashlight(),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: toolkit.isFlashlightOn
                                ? (isDark ? Colors.amber.shade800 : Colors.amber.shade200)
                                : (isDark ? AppTheme.surfaceDarkMuted : AppTheme.surfaceMuted),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            toolkit.isFlashlightOn ? Icons.flash_on : Icons.flash_off,
                            color: toolkit.isFlashlightOn
                                ? Colors.amber.shade300
                                : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Flashlight',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          toolkit.isFlashlightOn ? 'ON' : 'OFF',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: toolkit.isFlashlightOn
                                ? Colors.amber.shade400
                                : (isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Deterrent Siren Toggle
                Expanded(
                  child: SafeCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: toolkit.isSirenActive
                        ? (isDark ? AppTheme.emergencyDarkRed.withValues(alpha: 0.35) : AppTheme.emergencyLightRed)
                        : null,
                    borderColor: toolkit.isSirenActive ? AppTheme.emergencyRed : null,
                    onTap: () => toolkit.toggleSiren(),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: toolkit.isSirenActive
                                ? AppTheme.emergencyRed
                                : (isDark ? AppTheme.surfaceDarkMuted : AppTheme.surfaceMuted),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            toolkit.isSirenActive ? Icons.volume_up : Icons.volume_off,
                            color: toolkit.isSirenActive
                                ? Colors.white
                                : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Deterrent Siren',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          toolkit.isSirenActive ? 'ALARM ACTIVE' : 'Loud deterrent',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: toolkit.isSirenActive
                                ? AppTheme.emergencyRed
                                : (isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Navigation Hub: Practice Test & Incident Evidence Locker
            Text(
              'Safety Resources & Tools',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            SafeCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosTestScreen())),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.amber.shade900.withValues(alpha: 0.25) : AppTheme.warningLightAmber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.science_outlined,
                      color: isDark ? Colors.amber.shade400 : AppTheme.warningAmber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOS Practice & Test Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Safely simulate emergency hold without alarming contacts',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: 10),

            SafeCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IncidentRecordScreen())),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3730A3).withValues(alpha: 0.3) : AppTheme.brandPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shield_moon_outlined,
                      color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Incident & Evidence Locker',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${toolkit.incidents.length} encrypted records saved locally',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Vehicle Photo Evidence Card
            SafeCard(
              onTap: () => VehiclePhotoSheet.show(context),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : AppTheme.safeGreenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_outlined,
                      color: AppTheme.safeGreen,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle Photo Evidence',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Capture & encrypt license plate or taxi photo before boarding',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Surrounding Sound Recorder Card
            SafeCard(
              onTap: () => AmbientAudioSheet.show(context),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.emergencyDarkRed.withValues(alpha: 0.3) : AppTheme.emergencyLightRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mic_none_rounded,
                      color: AppTheme.emergencyRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Surrounding Sound Recorder',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Explicitly record and encrypt ambient audio during encounters',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Nearby Police Stations Discovery Card
            SafeCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NearbyPoliceScreen()),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF312E81) : AppTheme.brandPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_police_outlined,
                      color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nearby Police Stations',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Live GPS-based station discovery, directions & helpline calling',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Emergency Helplines Directory
            Text(
              'National Emergency Helplines (One-Tap Dial)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildHelplineTile(context, '112', 'National Emergency Unified', Icons.local_police, Colors.indigo),
            const SizedBox(height: 8),
            _buildHelplineTile(context, '1091', 'Women Safety Helpline', Icons.support_agent, AppTheme.emergencyRed),
            const SizedBox(height: 8),
            _buildHelplineTile(context, '181', 'Women in Distress Helpline', Icons.favorite, Colors.purple),
            const SizedBox(height: 8),
            _buildHelplineTile(context, '108', 'Emergency Ambulance', Icons.medical_services, AppTheme.safeGreen),
            const SizedBox(height: 24),

            // Safety Guides & Educational Walkthroughs
            Text(
              'Safety Tips & Awareness',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _buildGuideCard(
              context,
              title: 'Transit & Ride-Hailing Security',
              tip: 'Always match the vehicle license plate, driver photo, and share your live Safe Walk journey before boarding any taxi or auto.',
            ),
            const SizedBox(height: 8),
            _buildGuideCard(
              context,
              title: 'Situational Awareness & Commute',
              tip: 'Avoid walking with noise-canceling headphones in unlit or quiet alleys. Keep phone easily reachable and stay attentive to surroundings.',
            ),
            const SizedBox(height: 8),
            _buildGuideCard(
              context,
              title: 'Active Threat & Deterrence',
              tip: 'If followed or confronted, activate the loud Deterrent Siren to attract public attention and move swiftly towards illuminated crowded spaces.',
            ),
            const SizedBox(height: 8),
            _buildGuideCard(
              context,
              title: 'Zero-Data Emergency Fallback',
              tip: 'SvaShield triggers direct carrier SMS with GPS links even when you have zero mobile data or Wi-Fi connection.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelplineTile(BuildContext context, String number, String name, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _callHelpline(context, number, name),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                  ),
                ),
                Text('Dial $number', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDarkMuted : AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.phone,
              size: 18,
              color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(BuildContext context, {required String title, required String tip}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tip,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
