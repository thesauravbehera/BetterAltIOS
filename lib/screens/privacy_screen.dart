import 'package:flutter/material.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        title: Text("Privacy Policy", style: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Privacy Policy", style: AppTypography.h1(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
            const SizedBox(height: 16),
            Text("Effective Date: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}", style: AppTypography.caption(color: AppColors.accent)),
            const SizedBox(height: 24),
            _buildSection(isDark, "1. Information We Collect", "We only collect data necessary to help you track your progress, including locally fetched step, calorie, and distance readings from Google Health Connect and Apple HealthKit, and basic account profile markers like email and display name."),
            _buildSection(isDark, "2. Data Usage", "Your progress tracking data is sent to our secure Firebase Cloud databases to maintain your streak over multiple devices. We do not sell your personal demographic data."),
            _buildSection(isDark, "3. Health Data Storage", "This app reads from Apple HealthKit and Google Health Connect exclusively. We do not permanently append destructive data into your core OS health timeline. Data is processed to compute your daily metrics."),
            _buildSection(isDark, "4. Account Deletion", "You can permanently delete your localized account and all corresponding streak records from our secure servers at any time."),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(bool isDark, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(body, style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
        ],
      ),
    );
  }
}
