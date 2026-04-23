import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:fat_burner/providers/purchase_status_provider.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';

class VerificationGateScreen extends StatefulWidget {
  const VerificationGateScreen({super.key});

  @override
  State<VerificationGateScreen> createState() => _VerificationGateScreenState();
}

class _VerificationGateScreenState extends State<VerificationGateScreen> {


  @override
  void initState() {
    super.initState();
    _performVerification();
  }

  Future<void> _performVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) context.go('/login');
        return;
      }

      // 1. Fetch user data from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final bool hasCompletedOnboarding = userData['onboardingCompleted'] ?? false;
      if (!hasCompletedOnboarding) {
        if (mounted) context.go('/onboarding');
        return;
      }

      final bool hasPurchasedCache = userData['has_purchased'] ?? false;
      
      // If we already know they purchased, let them in immediately!
      if (hasPurchasedCache) {
        if (mounted) context.go('/dashboard');
        return;
      }

      String? actualEmail = userData['email'];
      if (actualEmail == null && user.email != null && !user.email!.endsWith('@betteralt.app')) {
        actualEmail = user.email;
      } else if (actualEmail != null && actualEmail.endsWith('@betteralt.app')) {
        actualEmail = null; // Don't send dummy email to Shopify
      }

      String? actualPhone = userData['phone'];
      if (actualPhone == null && user.email != null && user.email!.endsWith('@betteralt.app')) {
        actualPhone = user.email!.split('@')[0]; // Extract phone from dummy email
      }

      // Normalize phone to +91 format for Shopify matching
      if (actualPhone != null && actualPhone.isNotEmpty) {
        // Strip any non-digit characters first
        String digitsOnly = actualPhone.replaceAll(RegExp(r'\D'), '');
        // If it's a 10-digit number, add +91 prefix
        if (digitsOnly.length == 10) {
          actualPhone = '+91$digitsOnly';
        } else if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
          actualPhone = '+$digitsOnly';
        }
        // If already has country code, keep as-is
      }

      // 2. Perform Shopify Validation
      final provider = PurchaseStatusProvider.instance;
      await provider.checkPurchase(email: actualEmail, phone: actualPhone);

      if (provider.hasPurchased == true) {
        // Validation success. The Cloud Function already saved this state to Firestore.
      } else {
        // Failed purchase check. The Cloud Function already recorded this.
      }
      
      if (mounted) context.go('/dashboard');
    } catch (e) {
      // On catastrophic error, let them in anyway but don't save true
      if (mounted) context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.accent,
            ),
            const SizedBox(height: 20),
            Text(
              "Verifying Account...",
              style: AppTypography.body(
                  color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
