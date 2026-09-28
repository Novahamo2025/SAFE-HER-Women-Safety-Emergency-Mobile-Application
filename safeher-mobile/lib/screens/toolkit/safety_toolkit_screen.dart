import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/toolkit_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/status_badge.dart';
import '../emergency/sos_test_screen.dart';
import 'incident_record_screen.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Safety Toolkit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instant Tools',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),

            // Flashlight & Siren Tiles Row
            Row(
              children: [
                // Flashlight Toggle
                Expanded(
                  child: SafeCard(
                    padding: const EdgeInsets.all(16),
                    backgroundColor: toolkit.isFlashlightOn ? Colors.amber.shade50 : AppTheme.surfaceWhite,
                    borderColor: toolkit.isFlashlightOn ? Colors.amber.shade400 : AppTheme.borderLight,
                    onTap: () => toolkit.toggleFlashlight(),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: toolkit.isFlashlightOn ? Colors.amber.shade200 : AppTheme.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            toolkit.isFlashlightOn ? Icons.flash_on : Icons.flash_off,
                            color: toolkit.isFlashlightOn ? Colors.amber.shade900 : AppTheme.textSecondary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Flashlight', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          toolkit.isFlashlightOn ? 'ON' : 'OFF',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: toolkit.isFlashlightOn ? Colors.amber.shade900 : AppTheme.textTertiary,
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
                    backgroundColor: toolkit.isSirenActive ? AppTheme.emergencyLightRed : AppTheme.surfaceWhite,
                    borderColor: toolkit.isSirenActive ? AppTheme.emergencyRed : AppTheme.borderLight,
                    onTap: () => toolkit.toggleSiren(),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: toolkit.isSirenActive ? AppTheme.emergencyRed : AppTheme.surfaceMuted,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            toolkit.isSirenActive ? Icons.volume_up : Icons.volume_off,
                            color: toolkit.isSirenActive ? Colors.white : AppTheme.textSecondary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Deterrent Siren', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(
                          toolkit.isSirenActive ? 'ALARM ACTIVE' : 'Loud deterrent',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: toolkit.isSirenActive ? AppTheme.emergencyRed : AppTheme.textTertiary,
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
            const Text(
              'Safety Resources & Tools',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),

            SafeCard(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SosTestScreen())),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.warningLightAmber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.science_outlined, color: AppTheme.warningAmber, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SOS Practice & Test Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('Safely simulate emergency hold without alarming contacts', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
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
                      color: AppTheme.brandPrimaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_moon_outlined, color: AppTheme.brandPrimary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Incident & Evidence Locker', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(
                          '${toolkit.incidents.length} encrypted records saved locally',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Emergency Helplines Directory
            const Text(
              'National Emergency Helplines (One-Tap Dial)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
            const Text(
              'Safety Tips & Awareness',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),

            _buildGuideCard(
              title: 'Night Transit & Ride Hailing',
              tip: 'Always match the vehicle license plate, driver photo, and share your live Safe Walk journey before boarding.',
            ),
            const SizedBox(height: 8),
            _buildGuideCard(
              title: 'Situational Awareness',
              tip: 'Avoid walking with noise-canceling headphones in unlit or quiet alleys. Keep phone easily reachable.',
            ),
            const SizedBox(height: 8),
            _buildGuideCard(
              title: 'Zero-DLT Offline Safety',
              tip: 'Svasheild sends direct carrier SMS with GPS links even when you have zero mobile data or WiFi.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelplineTile(BuildContext context, String number, String name, IconData icon, Color color) {
    return SafeCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => _callHelpline(context, number, name),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Dial $number', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.phone, size: 18, color: AppTheme.brandPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard({required String title, required String tip}) {
    return SafeCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: AppTheme.brandPrimary, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 6),
          Text(tip, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}
