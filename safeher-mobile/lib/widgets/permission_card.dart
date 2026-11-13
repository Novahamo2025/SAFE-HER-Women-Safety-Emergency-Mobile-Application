import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'status_badge.dart';

class PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String explanation;
  final bool isGranted;
  final bool isPermanentlyDenied;
  final VoidCallback onRequest;

  const PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.explanation,
    required this.isGranted,
    this.isPermanentlyDenied = false,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted
              ? AppTheme.safeGreen.withValues(alpha: 0.35)
              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGranted
                      ? (isDark ? const Color(0xFF064E3B) : AppTheme.safeGreenLight)
                      : (isDark ? const Color(0xFF1E293B) : AppTheme.brandPrimaryLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isGranted
                      ? AppTheme.safeGreen
                      : (isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    StatusBadge(
                      label: isGranted
                          ? 'Granted'
                          : (isPermanentlyDenied ? 'Blocked in OS' : 'Action Needed'),
                      type: isGranted
                          ? StatusBadgeType.success
                          : (isPermanentlyDenied ? StatusBadgeType.error : StatusBadgeType.warning),
                      showDot: true,
                    ),
                  ],
                ),
              ),
              if (!isGranted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPermanentlyDenied ? AppTheme.warningAmber : AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onRequest,
                  child: Text(
                    isPermanentlyDenied ? 'Settings' : 'Allow',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
