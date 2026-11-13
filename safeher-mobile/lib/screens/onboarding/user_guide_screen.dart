import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import '../dashboard/dashboard_screen.dart';

class UserGuideScreen extends StatefulWidget {
  final bool isReviewMode;
  final VoidCallback? onComplete;

  const UserGuideScreen({
    super.key,
    this.isReviewMode = false,
    this.onComplete,
  });

  static const String prefKey = 'has_completed_user_guide';

  static Future<bool> hasCompletedGuide() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefKey) ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, true);
  }

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_GuidePageData> _pages = const [
    _GuidePageData(
      icon: Icons.shield_rounded,
      iconColor: AppTheme.brandPrimary,
      title: 'Welcome to SvaShield',
      subtitle: 'Your Personal Safety Companion',
      description:
          'SvaShield is engineered to provide swift, dependable emergency response and peace of mind wherever you go.',
      bulletPoints: [
        'Rapid 3-second SOS alert system',
        'Direct connection to your trusted contacts',
        'End-to-end privacy and encrypted evidence',
      ],
    ),
    _GuidePageData(
      icon: Icons.emergency,
      iconColor: AppTheme.emergencyRed,
      title: 'Emergency SOS Activation',
      subtitle: 'Hold for 3 Seconds to Trigger',
      description:
          'When you feel in danger, press and hold the SOS button on the dashboard. A 3-second tactile countdown prevents accidental triggers.',
      bulletPoints: [
        'Instantly locks and initiates emergency tracking',
        'Dispatches high-priority SMS alerts to contacts',
        'Provides real-time GPS coordinates even when locked',
      ],
    ),
    _GuidePageData(
      icon: Icons.security_rounded,
      iconColor: AppTheme.infoBlue,
      title: 'Essential Permissions',
      subtitle: 'Why We Need Device Access',
      description:
          'To keep you protected during critical situations, SvaShield utilizes native device hardware with strict privacy boundaries.',
      bulletPoints: [
        'Location: Transmitted only during active SOS or Safe Walk',
        'Microphone & Camera: Captured exclusively for incident evidence',
        'Notifications: Alerts you to check-in and journey statuses',
      ],
    ),
    _GuidePageData(
      icon: Icons.contacts_rounded,
      iconColor: AppTheme.safeGreen,
      title: 'Trusted Emergency Circle',
      subtitle: 'Who Gets Notified First',
      description:
          'Add your family members, close friends, or colleagues to your emergency circle with customizable priority levels.',
      bulletPoints: [
        'Primary contacts receive instant SMS with live map link',
        'Supports up to 10 armed emergency contacts',
        'One-tap dial and direct SMS fallback',
      ],
    ),
    _GuidePageData(
      icon: Icons.videocam_rounded,
      iconColor: Color(0xFFD97706),
      title: 'Safety Media & Evidence',
      subtitle: 'Document Incidents Securely',
      description:
          'Quickly record audio, take photos, or shoot video during suspicious encounters. All evidence is securely preserved.',
      bulletPoints: [
        'App-private encrypted storage prevents external tampering',
        'Protected against accidental or unauthorized deletion',
        'Account password required for evidence removal',
      ],
    ),
    _GuidePageData(
      icon: Icons.palette_rounded,
      iconColor: Color(0xFF8B5CF6),
      title: 'Customizable Themes',
      subtitle: 'Light, Dark & System Adaptive',
      description:
          'Personalize SvaShield to suit day or nighttime visibility. High-contrast typography and red SOS remain distinct in every mode.',
      bulletPoints: [
        'Deep dark mode saves battery in low-light environments',
        'Clean high-legibility light theme for bright daylight',
        'Easily switch anytime in Profile > Appearance',
      ],
    ),
  ];

  void _finishGuide() async {
    await UserGuideScreen.markCompleted();
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (widget.isReviewMode) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isReviewMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: _finishGuide,
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
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Step ${_currentPage + 1} of ${_pages.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.textTertiary : AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        // Icon with decorative background ring
                        Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: page.iconColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: page.iconColor.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            page.icon,
                            size: 52,
                            color: page.iconColor,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Subtitle
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: page.iconColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bullet points card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: page.bulletPoints.map((point) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: page.iconColor,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        point,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.35,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
              ),
            ),

            // Bottom Navigation & Progress Dots
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary)
                              : (isDark ? AppTheme.surfaceDarkMuted : AppTheme.borderMedium),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),

                  // Button controls
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: SafeButton(
                          text: 'Previous',
                          type: SafeButtonType.outline,
                          onPressed: _currentPage > 0
                              ? () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SafeButton(
                          text: isLastPage ? 'Get Started' : 'Next',
                          icon: isLastPage ? Icons.check_circle_outline_rounded : Icons.arrow_forward,
                          type: SafeButtonType.primary,
                          onPressed: () {
                            if (isLastPage) {
                              _finishGuide();
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePageData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;
  final List<String> bulletPoints;

  const _GuidePageData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.bulletPoints,
  });
}
