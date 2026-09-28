import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'status_badge.dart';

class PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String explanation;
  final bool isGranted;
  final VoidCallback onRequest;

  const PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.explanation,
    required this.isGranted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? AppTheme.safeGreen.withOpacity(0.3) : AppTheme.borderLight,
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
                  color: isGranted ? AppTheme.safeGreenLight : AppTheme.brandPrimaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isGranted ? AppTheme.safeGreen : AppTheme.brandPrimary,
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
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    StatusBadge(
                      label: isGranted ? 'Granted' : 'Action Needed',
                      type: isGranted ? StatusBadgeType.success : StatusBadgeType.warning,
                      showDot: true,
                    ),
                  ],
                ),
              ),
              if (!isGranted)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.brandPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onRequest,
                  child: const Text('Allow', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
