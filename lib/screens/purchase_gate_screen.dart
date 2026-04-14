import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/theme/app_spacing.dart';

class PurchaseGateScreen extends StatelessWidget {
  const PurchaseGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeInUp(
              duration: const Duration(milliseconds: 600),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Lock Icon
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppColors.error,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      "Purchase Required",
                      style: AppTypography.h2(
                          color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    Text(
                      "We couldn't find an active order for the BetterAlt Fat Burner linked to your account.",
                      style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    
                    Text(
                      "Please ensure you've purchased the product and are logged in with the same Email or Phone Number used at checkout.",
                      style: AppTypography.body(
                          color: isDark ? AppColors.textOnDarkMuted : AppColors.textTertiary),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 32),

                    /// Retry Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          // Bounce back to the Verification Gate to check again
                          context.go('/verify');
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: Text("Check Purchase Again",
                            style: AppTypography.h3(color: Colors.white).copyWith(fontSize: 15)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    /// Sign Out
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      child: const Text(
                        "Sign Out",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
