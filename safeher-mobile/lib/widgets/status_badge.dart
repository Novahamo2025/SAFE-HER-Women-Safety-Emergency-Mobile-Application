import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum StatusBadgeType { success, error, warning, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;
  final IconData? icon;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusBadgeType.success,
    this.icon,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    switch (type) {
      case StatusBadgeType.success:
        bg = AppTheme.safeGreenLight;
        fg = AppTheme.safeGreenDark;
        border = AppTheme.safeGreen.withOpacity(0.3);
        break;
      case StatusBadgeType.error:
        bg = AppTheme.emergencyLightRed;
        fg = AppTheme.emergencyDarkRed;
        border = AppTheme.emergencyRed.withOpacity(0.3);
        break;
      case StatusBadgeType.warning:
        bg = AppTheme.warningLightAmber;
        fg = AppTheme.warningAmber;
        border = AppTheme.warningAmber.withOpacity(0.3);
        break;
      case StatusBadgeType.info:
        bg = AppTheme.infoLightBlue;
        fg = AppTheme.infoBlue;
        border = AppTheme.infoBlue.withOpacity(0.3);
        break;
      case StatusBadgeType.neutral:
        bg = AppTheme.surfaceMuted;
        fg = AppTheme.textSecondary;
        border = AppTheme.borderLight;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
