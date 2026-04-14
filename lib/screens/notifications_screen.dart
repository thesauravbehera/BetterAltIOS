import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:animate_do/animate_do.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("Notifications", style: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
        iconTheme: IconThemeData(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
      ),
      body: user == null 
        ? const Center(child: Text("Please log in to see notifications."))
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: FadeInUp(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                        const SizedBox(height: 16),
                        Text("No recent notifications", style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final title = data['title'] ?? 'Notification';
                  final body = data['body'] ?? '';
                  final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                  
                  return FadeInUp(
                    delay: Duration(milliseconds: 50 * index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notifications_active_rounded, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(body, style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                Text(DateFormat('MMM d, h:mm a').format(ts), style: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted.withValues(alpha: 0.5) : AppColors.textTertiary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}
