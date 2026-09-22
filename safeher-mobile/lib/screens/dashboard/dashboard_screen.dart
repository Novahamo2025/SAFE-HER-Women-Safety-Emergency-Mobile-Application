import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../services/sms_service.dart';
import '../contacts/contacts_screen.dart';
import '../emergency/sos_active_screen.dart';
import '../journey/safe_walk_screen.dart';
import '../toolkit/safety_toolkit_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  Timer? _holdTimer;
  double _holdProgress = 0.0;
  bool _isHolding = false;
  static const int _holdDurationSeconds = 3;

  void _onSosPressDown() {
    setState(() {
      _isHolding = true;
      _holdProgress = 0.0;
    });

    HapticFeedback.heavyImpact();

    const stepMs = 50;
    final totalSteps = (_holdDurationSeconds * 1000) / stepMs;
    int currentStep = 0;

    _holdTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      currentStep++;
      setState(() {
        _holdProgress = currentStep / totalSteps;
      });

      if (currentStep % 10 == 0) {
        HapticFeedback.selectionClick();
      }

      if (_holdProgress >= 1.0) {
        timer.cancel();
        _triggerEmergencySos();
      }
    });
  }

  void _onSosPressUp() {
    _holdTimer?.cancel();
    setState(() {
      _isHolding = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _triggerEmergencySos() async {
    // Vibrate phone strongly
    try {
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    } catch (_) {}

    // 1. Fetch current GPS location
    final position = await LocationService.getCurrentLocation();
    final lat = position?.latitude ?? 0.0;
    final lng = position?.longitude ?? 0.0;

    // 2. Immediate Native SMS Dispatch (Blocker 2 & 4: Zero-DLT & Offline-First)
    // In production, these numbers are pulled from LocalStorage/Database
    await SmsService.sendNativeEmergencySms(
      recipientNumbers: ['+919876543210'],
      userName: 'SafeHer User',
      latitude: lat,
      longitude: lng,
    );

    if (!mounted) return;

    // 3. Navigate to Active Emergency Screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SosActiveScreen(latitude: lat, longitude: lng),
      ),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.emergencyRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield, color: AppTheme.emergencyRed),
            ),
            const SizedBox(width: 8),
            const Text('SafeHer', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.safeGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: AppTheme.safeGreen, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Protection Active • GPS Ready',
                    style: TextStyle(color: AppTheme.safeGreen, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // SOS Hold Button
            Center(
              child: GestureDetector(
                onTapDown: (_) => _onSosPressDown(),
                onTapUp: (_) => _onSosPressUp(),
                onTapCancel: () => _onSosPressUp(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer animated progress ring
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: _holdProgress,
                        strokeWidth: 10,
                        backgroundColor: Colors.red.shade100,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emergencyDarkRed),
                      ),
                    ),
                    // Inner SOS core
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: _isHolding ? 180 : 190,
                      height: _isHolding ? 180 : 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppTheme.emergencyRed, AppTheme.emergencyDarkRed],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.emergencyRed.withOpacity(0.4),
                            blurRadius: _isHolding ? 30 : 20,
                            spreadRadius: _isHolding ? 10 : 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.emergency, color: Colors.white, size: 48),
                          SizedBox(height: 6),
                          Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            'HOLD 3 SEC',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Quick Safety Features Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.25,
              children: [
                _buildQuickCard(
                  icon: Icons.directions_walk,
                  title: 'Safe Walk',
                  subtitle: 'Monitored journey',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeWalkScreen())),
                ),
                _buildQuickCard(
                  icon: Icons.timer,
                  title: 'Safety Check-In',
                  subtitle: 'Periodic check',
                  color: Colors.teal,
                  onTap: () {},
                ),
                _buildQuickCard(
                  icon: Icons.contacts,
                  title: 'Trusted Contacts',
                  subtitle: 'Manage alerts',
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())),
                ),
                _buildQuickCard(
                  icon: Icons.build_circle,
                  title: 'Safety Toolkit',
                  subtitle: 'Siren, Flash, Helplines',
                  color: Colors.deepOrange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyToolkitScreen())),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
