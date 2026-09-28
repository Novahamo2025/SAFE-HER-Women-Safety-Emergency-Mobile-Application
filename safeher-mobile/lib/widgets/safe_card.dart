import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class SafeCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;

  const SafeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppTheme.surfaceWhite,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor ?? AppTheme.borderLight),
          ),
          child: child,
        ),
      ),
    );
  }
}
