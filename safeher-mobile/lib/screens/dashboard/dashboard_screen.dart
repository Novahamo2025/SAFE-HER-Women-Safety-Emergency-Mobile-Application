import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/providers/checkin_provider.dart';
import '../../core/providers/contact_provider.dart';
import '../../core/providers/emergency_provider.dart';
import '../../core/providers/journey_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/sos_hold_button.dart';
import '../../widgets/status_badge.dart';
import '../contacts/contacts_screen.dart';
import '../emergency/sos_active_screen.dart';
import '../journey/safe_walk_screen.dart';
import '../checkin/checkin_screen.dart';
import '../toolkit/safety_toolkit_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    _DashboardHomeTab(),
    SafeWalkScreen(),
    ContactsScreen(),
    SafetyToolkitScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.brandPrimary,
        unselectedItemColor: AppTheme.textTertiary,
        selectedFontSize: 11.5,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk_outlined),
            activeIcon: Icon(Icons.directions_walk),
            label: 'Journey',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build_circle_outlined),
            activeIcon: Icon(Icons.build_circle),
            label: 'Safety',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _DashboardHomeTab extends StatelessWidget {
  const _DashboardHomeTab();

  Future<void> _triggerSos(BuildContext context) async {
    final contacts = context.read<ContactProvider>().contacts;
    final auth = context.read<AuthProvider>();
    final emergency = context.read<EmergencyProvider>();

    await emergency.triggerEmergency(
      contacts: contacts,
      userName: auth.userName,
    );

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SosActiveScreen(
            latitude: emergency.latitude,
            longitude: emergency.longitude,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final contactProvider = context.watch<ContactProvider>();
    final journeyProvider = context.watch<JourneyProvider>();
    final checkInProvider = context.watch<CheckInProvider>();
    final emergency = context.watch<EmergencyProvider>();

    final contactCount = contactProvider.contacts.length;
    final hasActiveJourney = journeyProvider.hasActiveJourney;
    final activeCheckIn = checkInProvider.nextActiveCheckIn;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/svashield_logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text(
              'Svasheild',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All safety notifications and alerts active.')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Greeting Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hi, ${auth.userName}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      "Stay safe. We're here when you need us.",
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.safeGreenLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: AppTheme.safeGreen, size: 14),
                      SizedBox(width: 5),
                      Text(
                        'PROTECTED',
                        style: TextStyle(
                          color: AppTheme.safeGreenDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Active SOS Resumption Banner (if already active)
            if (emergency.isEmergencyActive) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.emergencyLightRed,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.emergencyRed),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: AppTheme.emergencyRed),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EMERGENCY SOS CURRENTLY ACTIVE',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emergencyDarkRed, fontSize: 13),
                          ),
                          Text('Live coordinates are currently streaming', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emergencyRed, minimumSize: const Size(70, 34)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SosActiveScreen(latitude: emergency.latitude, longitude: emergency.longitude),
                          ),
                        );
                      },
                      child: const Text('View', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],

            // Active Safe Walk Ongoing Banner
            if (hasActiveJourney) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimaryLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.brandPrimary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk, color: AppTheme.brandPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Safe Walk to ${journeyProvider.activeJourney!.destination}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.brandPrimaryDark),
                          ),
                          Text(
                            '${journeyProvider.activeJourney!.remainingDuration.inMinutes} mins remaining until ETA',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Protection Status Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppTheme.brandPrimary, size: 18),
                  const SizedBox(width: 8),
                  const Text('GPS Ready', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(width: 1, height: 16, color: AppTheme.borderLight),
                  const Spacer(),
                  const Icon(Icons.people, color: AppTheme.safeGreen, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$contactCount Contact${contactCount != 1 ? "s" : ""} Armed',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(width: 1, height: 16, color: AppTheme.borderLight),
                  const Spacer(),
                  const Icon(Icons.offline_bolt, color: AppTheme.warningAmber, size: 18),
                  const SizedBox(width: 6),
                  const Text('SMS Offline', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // SOS Dominant Hold Button Centerpiece
            Center(
              child: SosHoldButton(
                size: 210,
                onSosTriggered: () => _triggerSos(context),
              ),
            ),
            const SizedBox(height: 36),

            // Quick Safety Feature Grid
            const Text(
              'Quick Safety Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _buildActionCard(
                  icon: Icons.directions_walk,
                  title: 'Safe Walk',
                  subtitle: hasActiveJourney ? 'Ongoing journey' : 'Monitored transit',
                  color: AppTheme.brandPrimary,
                  badge: hasActiveJourney ? 'ACTIVE' : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafeWalkScreen())),
                ),
                _buildActionCard(
                  icon: Icons.timer,
                  title: 'Safety Check-In',
                  subtitle: activeCheckIn != null ? '${activeCheckIn.remainingDuration.inMinutes}m left' : 'Periodic checks',
                  color: Colors.teal,
                  badge: activeCheckIn != null ? 'SET' : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInScreen())),
                ),
                _buildActionCard(
                  icon: Icons.people_alt_outlined,
                  title: 'Trusted Contacts',
                  subtitle: '$contactCount armed',
                  color: Colors.blueAccent,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen())),
                ),
                _buildActionCard(
                  icon: Icons.build_circle_outlined,
                  title: 'Safety Toolkit',
                  subtitle: 'Siren, torch, helplines',
                  color: Colors.deepOrange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyToolkitScreen())),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Emergency National Helplines Quick Banner
            SafeCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emergencyLightRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.phone_in_talk, color: AppTheme.emergencyRed, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Emergency Helpline (112)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('Direct national women & police emergency dial', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textTertiary),
                ],
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyToolkitScreen())),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return SafeCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              if (badge != null)
                StatusBadge(label: badge, type: StatusBadgeType.success),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
