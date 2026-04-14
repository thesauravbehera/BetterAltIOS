import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/widgets/app_text_field.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Page 1 Inputs
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  int _selectedAge = 25; // Default age for scroller

  // Page 3 Selection
  String _selectedTiming = "";
  bool _isSaving = false;

  void _nextPage() {
    // Validation
    if (_currentPage == 0) {
      if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out all fields')));
        return;
      }
      if (_phoneController.text.trim().length != 10) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter exactly 10 digits for your phone number')));
        return;
      }
    }
    
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _completeOnboarding() async {
    if (_selectedTiming.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a preferred timing')));
      return;
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'age': _selectedAge,
        'dose_preference': _selectedTiming,
        'onboardingCompleted': true,
      }, SetOptions(merge: true));

      // Subscribe to FCM topic for selected dose timing
      final topicName = 'dose_${_selectedTiming.replaceAll('-', '_')}';
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topicName);
      } catch (e) {
        debugPrint('FCM Subscribe Error: $e');
      }

      if (mounted) context.go('/dashboard');
    } else {
      // User hasn't signed up yet, pass data to SignUpScreen
      if (mounted) {
        context.push('/signup', extra: {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'age': _selectedAge,
          'dose_preference': _selectedTiming,
        });
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage >= index ? AppColors.accent : (isDark ? Colors.grey[800] : Colors.grey[300]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildPage1(isDark),
                  _buildPage2(isDark),
                  _buildPage3(isDark),
                ],
              ),
            ),

            // Bottom Buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Text("Back", style: AppTypography.body(color: isDark ? Colors.white54 : Colors.black54)),
                    )
                  else
                    const SizedBox(width: 60),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : (_currentPage == 2 ? _completeOnboarding : _nextPage),
                    child: _isSaving 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_currentPage == 2 ? "Finish" : "Next", style: AppTypography.h3(color: AppColors.textOnAccent)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FadeInRight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Let's get to know you!", style: AppTypography.h1(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text("Tell us a little bit about yourself so we can personalize your journey.", style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
            const SizedBox(height: 40),
            AppTextField(
              label: "Your Name",
              hint: "Enter your full name",
              controller: _nameController,
              prefixIcon: Icons.person_rounded,
              isPremiumWhite: true,
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: "Phone Number",
              hint: "Enter your 10-digit number",
              controller: _phoneController,
              prefixIcon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              isPremiumWhite: true,
            ),
            const SizedBox(height: 20),
            
            // Age Scroller
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Text("Age", style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _selectedAge,
                    underline: const SizedBox(),
                    dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
                    icon: Icon(Icons.keyboard_arrow_down, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                    items: List.generate(82, (index) => index + 18).map((int value) {
                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text("$value", style: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setState(() => _selectedAge = newValue);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage2(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FadeInRight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("The 90-Day Challenge", style: AppTypography.h1(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text("Consistency is key. Here is how BetterAlt Fat Burner helps you over 90 days.", style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
            const SizedBox(height: 30),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.info.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: AppColors.info, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Our Full Refund Guarantee",
                          style: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "We are absolutely committed to your transformation journey. Our 90-Day Protocol is simple:\n\n"
                    "1. Take Both Capsules Daily (Dose 1 and Dose 2)\n"
                    "2. Maintain Your Recommended Metrics\n"
                    "3. Complete the Full 90 Days\n\n"
                    "If you follow the program consistently for all 90 days without missing a dose and still don't see any positive changes in your body composition, we will initiate a FULL REFUND. No questions asked. We actively push you to succeed!",
                    style: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary).copyWith(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage3(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FadeInRight(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Schedule Your Dose", style: AppTypography.h1(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text("When is your preferred time to take the BetterAlt capsule?", style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
            const SizedBox(height: 30),
            
            _buildTimingRadio(isDark, "8:00 AM - 12:00 PM", "8-12"),
            const SizedBox(height: 8),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  "🔥 Highly Recommended for Best Results!", 
                  style: GoogleFonts.caveat(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
            
            _buildTimingRadio(isDark, "12:00 PM - 4:00 PM", "12-4"),
            const SizedBox(height: 16),
            _buildTimingRadio(isDark, "4:00 PM - 8:00 PM", "4-8"),
            
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.info.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "We will send you a reminder exactly 15 minutes before your schedule to keep your streak alive!",
                      style: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary).copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingRadio(bool isDark, String label, String value) {
    final isSelected = _selectedTiming == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedTiming = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.1) : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.accent : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.accent : Colors.grey,
            ),
            const SizedBox(width: 16),
            Text(label, style: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary).copyWith(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, String title, String subtitle, String desc, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDk.withOpacity(0.5) : AppColors.surfaceElevated.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AppTypography.label(color: AppColors.accent)),
                    Text(subtitle, style: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary).copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(desc, style: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
