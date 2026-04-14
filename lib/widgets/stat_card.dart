import 'package:flutter/material.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_spacing.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:animate_do/animate_do.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? colorOverride;
  final int index;
  final String? actionText;
  final VoidCallback? onTapAction;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.colorOverride,
    this.index = 0,
    this.actionText,
    this.onTapAction,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = colorOverride ?? AppColors.accent;

    return FadeInUp(
      delay: Duration(milliseconds: 100 * index),
      duration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevatedDk : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title.toUpperCase(),
                  style: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTypography.statMedium(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.body(color: accentColor).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (actionText != null && onTapAction != null) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: onTapAction,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      actionText!,
                      style: AppTypography.caption(color: accentColor).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
