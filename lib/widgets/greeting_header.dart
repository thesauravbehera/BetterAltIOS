import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final name = (user == null || user.displayName == null || user.displayName!.isEmpty) 
        ? 'Champion' 
        : user.displayName ?? 'Champion';
        
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr.toUpperCase(),
            style: AppTypography.label(color: AppColors.accent),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                _getGreeting(),
                style: AppTypography.h2(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
              ),
              Text(
                name,
                style: AppTypography.h2(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
