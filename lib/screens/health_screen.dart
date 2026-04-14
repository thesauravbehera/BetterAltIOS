import 'package:flutter/material.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'steps_screen.dart';
import 'calories_screen.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 0, // hide main toolbar
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEBEBEB),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: isDark ? AppColors.accent.withOpacity(0.8) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: isDark ? Colors.white : Colors.black87,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                labelStyle: AppTypography.label(color: AppColors.accent).copyWith(fontWeight: FontWeight.w800, fontSize: 13),
                unselectedLabelStyle: AppTypography.label(color: isDark ? Colors.white54 : Colors.black54).copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: "STEPS", height: 44),
                  Tab(text: "CALORIES", height: 44),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            StepsScreen(),
            CaloriesScreen(),
          ],
        ),
      ),
    );
  }
}
