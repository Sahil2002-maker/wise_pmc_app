import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SidebarMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final double iconSize;
  final double fontSize;
  final FontWeight? fontWeight;
  final double horizontalPadding;
  final bool useGradient;

  const SidebarMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.active = false,
    this.onTap,
    this.trailing,
    this.margin,
    this.iconSize = 20,
    this.fontSize = 15,
    this.fontWeight,
    this.horizontalPadding = 0,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final showGradient = active && useGradient;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: showGradient
            ? const LinearGradient(
                colors: [
                  AppColors.sidebarActiveStart,
                  AppColors.sidebarActiveEnd,
                ],
              )
            : null,
        color: showGradient ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: showGradient
            ? [
                BoxShadow(
                  color: AppColors.primaryGreen.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: ListTile(
              dense: true,
              minLeadingWidth: 20,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              leading: Icon(
                icon,
                color: active ? Colors.white : AppColors.textMutedDark,
                size: iconSize,
              ),
              title: Text(
                title,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textMutedDark,
                  fontWeight: fontWeight ?? (active ? FontWeight.w600 : FontWeight.w500),
                  fontSize: fontSize,
                ),
              ),
              trailing: trailing,
            ),
          ),
        ),
      ),
    );
  }
}