import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum SafeButtonType { primary, secondary, danger, outline }

class SafeButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final SafeButtonType type;
  final IconData? icon;
  final bool isLoading;
  final double? height;
  final double? width;

  const SafeButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = SafeButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.height = 52,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide? border;

    switch (type) {
      case SafeButtonType.primary:
        bg = AppTheme.brandPrimary;
        fg = Colors.white;
        border = null;
        break;
      case SafeButtonType.secondary:
        bg = AppTheme.brandPrimaryLight;
        fg = AppTheme.brandPrimaryDark;
        border = null;
        break;
      case SafeButtonType.danger:
        bg = AppTheme.emergencyRed;
        fg = Colors.white;
        border = null;
        break;
      case SafeButtonType.outline:
        bg = Colors.transparent;
        fg = AppTheme.textPrimary;
        border = const BorderSide(color: AppTheme.borderMedium);
        break;
    }

    final isActionDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withOpacity(0.5),
          disabledForegroundColor: fg.withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: border ?? BorderSide.none,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        onPressed: isActionDisabled ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
