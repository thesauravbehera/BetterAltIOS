import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';
import 'support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _streakCount = 0;
  int _totalUses = 0;
  int _activeDays = 0;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _calculateStreak();
    _fetchUserData();
  }

  String _userName = '';
  String _userEmail = '';

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            if (data['profile_photo_url'] != null && data['profile_photo_url'].toString().isNotEmpty) {
              _photoUrl = data['profile_photo_url'];
            } else if (data['profile_photo_base64'] != null && data['profile_photo_base64'].toString().isNotEmpty) {
              _photoUrl = 'base64:${data['profile_photo_base64']}';
            }
            _userName = data['name'] ?? '';
            _userEmail = data['email'] ?? '';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _calculateStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("daily_logs")
          .orderBy('lastUpdated', descending: true)
          .limit(60)
          .get();

      int currentStreak = 0;
      DateTime? expectedDate;

      final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
      final todayStr = now.toIso8601String().substring(0, 10);
      bool missedToday = true;

      int uses = 0;
      int activeDaysCount = 0;

      for (var d in snapshot.docs) {
        final bool am = d.data()["capsuleDose1"] ?? false;
        final bool pm = d.data()["capsuleDose2"] ?? false;

        // Increase uses
        if (am) uses++;
        if (pm) uses++;
        
        // Count active day if ANY dose taken
        if (am || pm) {
          activeDaysCount++;

          if (expectedDate == null) {
            // First valid record found
            currentStreak = 1;
            expectedDate = DateTime.parse(d.id).subtract(const Duration(days: 1));
            if (d.id == todayStr) missedToday = false;
          } else if (d.id == expectedDate!.toIso8601String().substring(0, 10)) {
            // Document matches expected continuous day
            currentStreak++;
            expectedDate = expectedDate.subtract(const Duration(days: 1));
          } else if (d.id.compareTo(expectedDate.toIso8601String().substring(0, 10)) < 0) {
            // Document is before expected date, streak is broken
            currentStreak = currentStreak; // break execution logic handled by setting state later
          }
        }
      }
      
      // Snapchat-style: show streak until the NEXT day after missing
      // If today missed but yesterday logged → still show streak (grace period, day not over)
      // Next day: yesterday is empty → streak = 0
      if (missedToday) {
        final yesterdayStr = now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
        final bool yesterdayMissed = !snapshot.docs.any((d) {
          final bool am = d.data()["capsuleDose1"] ?? false;
          final bool pm = d.data()["capsuleDose2"] ?? false;
          return d.id == yesterdayStr && (am || pm);
        });
        if (yesterdayMissed) {
          currentStreak = 0; // Both today and yesterday missed → streak broken
        }
        // Otherwise keep currentStreak (grace period: today not done yet)
      }
      
      if (mounted) {
        setState(() {
          _streakCount = currentStreak;
          _totalUses = uses;
          _activeDays = activeDaysCount;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = _userName.isNotEmpty ? _userName : (user?.displayName ?? '');
    final String initials = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  "Profile",
                  style: AppTypography.h1(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                ),
              ),

              const SizedBox(height: 28),

              /// Avatar + name row
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: Row(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.gradientPrimary,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.structurePrimary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        image: (() {
                          if (_photoUrl == null || _photoUrl!.isEmpty) return null;
                          try {
                            if (_photoUrl!.startsWith('base64:')) {
                              return DecorationImage(
                                image: MemoryImage(base64Decode(_photoUrl!.substring(7))),
                                fit: BoxFit.cover,
                              );
                            }
                            return DecorationImage(
                              image: NetworkImage(_photoUrl!),
                              fit: BoxFit.cover,
                            );
                          } catch (_) {
                            return null;
                          }
                        })(),
                      ),
                      child: (() {
                        bool showInitials = _photoUrl == null || _photoUrl!.isEmpty;
                        return showInitials ? Center(
                          child: Text(
                            initials,
                            style: AppTypography.h2(color: Colors.white).copyWith(fontSize: 32),
                          ),
                        ) : null;
                      })(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (_userName.isNotEmpty) 
                                ? _userName 
                                : (user?.displayName ?? 'User'),
                            style: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary).copyWith(fontSize: 22),
                          ),
                          const SizedBox(height: 4),
                          if (_userEmail.isNotEmpty)
                            Text(
                              _userEmail,
                              style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary).copyWith(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              /// Stats row
              FadeInUp(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 500),
                child: Row(
                  children: [
                    Expanded(child: _miniStat(_streakCount.toString(), "Day Streak", "🔥", isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _miniStat("$_totalUses", "Total Uses", "💊", isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _miniStat("$_activeDays", "Active Logs", "🎯", isDark)),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              /// Settings section
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  "ACCOUNT",
                  style: AppTypography.label(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 12),

              FadeInUp(
                delay: const Duration(milliseconds: 300),
                child: _settingsCard([
                  _settingsRow(Icons.person_outline_rounded, "Edit Profile", onTap: () async {
                    final shouldRefresh = await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                    if (shouldRefresh == true) {
                      await _fetchUserData();
                      await _calculateStreak();
                    }
                  }, isDark: isDark),
                  _divider(isDark),
                  _settingsRow(Icons.notifications_outlined, "Notifications", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                  }, isDark: isDark),
                  _divider(isDark),
                  _settingsRow(Icons.lock_outline_rounded, "Privacy", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                  }, isDark: isDark),
                ], isDark),
              ),

              const SizedBox(height: 24),

              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Text(
                  "SUPPORT",
                  style: AppTypography.label(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 12),

              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: _settingsCard([
                  _settingsRow(Icons.help_outline_rounded, "Help & Support", onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()));
                  }, isDark: isDark),
                  _divider(isDark),
                  _settingsRow(Icons.star_outline_rounded, "Rate the App", onTap: () async {
                    try {
                      final InAppReview inAppReview = InAppReview.instance;
                      if (await inAppReview.isAvailable()) {
                        await inAppReview.requestReview();
                      } else {
                        // NOTE: For Android, openStoreListing routes via app bundle id (which it detects automatically). 
                        // For iOS, appStoreId must be your numeric App Store Connect ID.
                        await inAppReview.openStoreListing(appStoreId: 'YOUR_APPLE_ID');
                      }
                    } catch (e) {
                      debugPrint('Error opening review: $e');
                    }
                  }, isDark: isDark),
                ], isDark),
              ),

              const SizedBox(height: 32),

              /// Logout
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: GestureDetector(
                  onTap: () async => await FirebaseAuth.instance.signOut(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          "Log out",
                          style: AppTypography.body(color: AppColors.error).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label, String emoji, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceElevatedDk : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 0.5),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.h2(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard(List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(children: children),
    );
  }

  Widget _settingsRow(IconData icon, String label, {required VoidCallback onTap, required bool isDark}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
    height: 1,
    color: isDark ? AppColors.borderDark : AppColors.borderLight,
    indent: 52,
  );
}
