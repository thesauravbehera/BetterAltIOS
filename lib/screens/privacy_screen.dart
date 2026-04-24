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
            Text("Effective Date: April 1, 2026", style: AppTypography.caption(color: AppColors.accent)),
            const SizedBox(height: 24),
            _buildSection(isDark, "1. Information We Collect",
                "We only collect data necessary to help you track your fitness progress:\n\n"
                "• Health & Fitness Data: Daily steps, active calories burned, walking/running distance, and sleep duration — read locally from Apple HealthKit (iOS) and Google Health Connect (Android).\n\n"
                "• Account Data: Phone number (for authentication via OTP), display name, email address, age, and profile photo.\n\n"
                "• Usage Data: Capsule intake logs, streak records, dose preferences, and notification history.\n\n"
                "We do NOT collect location data, contacts, browsing history, or any data beyond what is described above."),
            _buildSection(isDark, "2. How We Use Your Data",
                "Your data is used exclusively to:\n\n"
                "• Display your daily health metrics on the dashboard.\n"
                "• Track your 90-day Fat Burner capsule streak.\n"
                "• Send you timely capsule reminders based on your chosen dose schedule.\n"
                "• Verify purchase status via our secure backend (Shopify integration through Firebase Cloud Functions).\n\n"
                "We do NOT use your Health data for advertising, analytics profiling, or any purpose other than displaying your personal fitness progress."),
            _buildSection(isDark, "3. Data Sharing & Third Parties",
                "We strictly do NOT sell, share, or disclose your personal or HealthKit/Health Connect data to third parties, data brokers, or advertising platforms.\n\n"
                "Third-party services used by this app:\n\n"
                "• Firebase (Google): Authentication, Cloud Firestore database, Cloud Functions, Cloud Messaging, Cloud Storage, App Check, and Analytics. Data is stored on Google's secure cloud infrastructure.\n"
                "• Shopify: Purchase verification only — processed server-side via Firebase Cloud Functions. Your Shopify order data never touches the app directly.\n"
                "• Google ML Kit: On-device image labeling for capsule photo verification. Processing happens entirely on your device — no images are sent to external servers.\n\n"
                "All third-party services comply with their respective privacy policies and data protection regulations."),
            _buildSection(isDark, "4. Health Data Compliance",
                "This app reads from Apple HealthKit and Google Health Connect exclusively in read-only mode. We do NOT write data back to your health timeline.\n\n"
                "In accordance with Apple's HealthKit guidelines:\n"
                "• Health data is never used for advertising or marketing.\n"
                "• Health data is not shared with third parties.\n"
                "• Health data is not sold to data brokers.\n"
                "• Health data is stored securely using Firebase with strict per-user access controls.\n\n"
                "We prioritize your privacy and strictly adhere to the Apple HealthKit and Google Health Connect developer guidelines."),
            _buildSection(isDark, "5. Data Retention",
                "Your health metrics and streak data are retained in our Firebase database for as long as your account is active. This allows you to track your progress over time and maintain streaks across devices.\n\n"
                "If you delete your account, all associated data — including daily logs, streak records, notification history, and profile information — is permanently removed from our servers."),
            _buildSection(isDark, "6. Data Security",
                "We implement industry-standard security measures to protect your data:\n\n"
                "• Firebase App Check prevents unauthorized API access.\n"
                "• Firestore Security Rules ensure users can only access their own data.\n"
                "• All data is transmitted over encrypted HTTPS connections.\n"
                "• Shopify API credentials are stored server-side and never exposed to the client app.\n"
                "• Phone-based OTP authentication via Firebase ensures secure account access."),
            _buildSection(isDark, "7. Account Deletion",
                "You can permanently delete your account and all corresponding data from our servers at any time:\n\n"
                "1. Open the app and navigate to Profile → Edit Profile.\n"
                "2. Scroll down and tap \"Delete Account\".\n"
                "3. Confirm the deletion.\n\n"
                "This action is irreversible. All your health data, streak records, notification history, and profile information will be permanently erased."),
            _buildSection(isDark, "8. Children's Privacy",
                "BetterAlt is not intended for use by children under the age of 18. We do not knowingly collect personal information from children. If you believe a child under 18 has provided us with personal data, please contact us immediately so we can delete it."),
            _buildSection(isDark, "9. Changes to This Policy",
                "We may update this Privacy Policy from time to time. Any changes will be reflected with a new \"Effective Date\" at the top of this page. We encourage you to review this policy periodically."),
            _buildSection(isDark, "10. Contact Us",
                "If you have any questions, concerns, or requests regarding this Privacy Policy or your personal data, please contact us at:\n\n"
                "Email: support@betteralt.in\n"
                "Website: https://betteralt.in"),
            const SizedBox(height: 40),
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
