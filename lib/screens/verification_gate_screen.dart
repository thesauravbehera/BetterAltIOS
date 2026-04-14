import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:fat_burner/providers/purchase_status_provider.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';

class VerificationGateScreen extends StatefulWidget {
  const VerificationGateScreen({super.key});

  @override
  State<VerificationGateScreen> createState() => _VerificationGateScreenState();
}

class _VerificationGateScreenState extends State<VerificationGateScreen> {
  bool _isChecking = true;

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

      final String? email = userData['email'] ?? user.email;
      final String? phone = userData['phone_number'];

      // 2. Perform Shopify Validation
      final provider = PurchaseStatusProvider.instance;
      await provider.checkPurchase(email: email, phone: phone);

      if (provider.hasPurchased == true) {
        // Validation success. Save state to cache so we skip this next time!
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'has_purchased': true,
        }, SetOptions(merge: true));
      } else {
        // Failed purchase check, record it
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'has_purchased': false,
        }, SetOptions(merge: true));
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
