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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    Color border;

    if (isDark) {
      switch (type) {
        case StatusBadgeType.success:
          bg = const Color(0xFF064E3B);
          fg = const Color(0xFF34D399);
          border = const Color(0xFF059669).withValues(alpha: 0.5);
          break;
        case StatusBadgeType.error:
          bg = const Color(0xFF450A0A);
          fg = const Color(0xFFFCA5A5);
          border = const Color(0xFFDC2626).withValues(alpha: 0.5);
          break;
        case StatusBadgeType.warning:
          bg = const Color(0xFF451A03);
          fg = const Color(0xFFFCD34D);
          border = const Color(0xFFD97706).withValues(alpha: 0.5);
          break;
        case StatusBadgeType.info:
          bg = const Color(0xFF172554);
          fg = const Color(0xFF93C5FD);
          border = const Color(0xFF2563EB).withValues(alpha: 0.5);
          break;
        case StatusBadgeType.neutral:
          bg = const Color(0xFF334155);
          fg = const Color(0xFFCBD5E1);
          border = const Color(0xFF475569);
          break;
      }
    } else {
      switch (type) {
        case StatusBadgeType.success:
          bg = AppTheme.safeGreenLight;
          fg = AppTheme.safeGreenDark;
          border = AppTheme.safeGreen.withValues(alpha: 0.3);
          break;
        case StatusBadgeType.error:
          bg = AppTheme.emergencyLightRed;
          fg = AppTheme.emergencyDarkRed;
          border = AppTheme.emergencyRed.withValues(alpha: 0.3);
          break;
        case StatusBadgeType.warning:
          bg = AppTheme.warningLightAmber;
          fg = AppTheme.warningAmber;
          border = AppTheme.warningAmber.withValues(alpha: 0.3);
          break;
        case StatusBadgeType.info:
          bg = AppTheme.infoLightBlue;
          fg = AppTheme.infoBlue;
          border = AppTheme.infoBlue.withValues(alpha: 0.3);
          break;
        case StatusBadgeType.neutral:
          bg = AppTheme.surfaceMuted;
          fg = AppTheme.textSecondaryFor(context);
          border = AppTheme.borderLight;
          break;
      }
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
