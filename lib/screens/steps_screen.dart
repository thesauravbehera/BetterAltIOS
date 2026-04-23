import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fat_burner/services/health_service.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/theme/app_spacing.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  List<int> weeklySteps = List.filled(7, 0);
  List<String> weeklyDays = List.filled(7, '');
  int todaySteps = 0;
  int avgSteps = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSteps();
  }

  Future<void> _fetchSteps() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final stepsList = await HealthService.instance.fetch7DaysStepsWithFallback();
      int total = 0;
      List<String> daysList = [];
      final now = DateTime.now();

      for (int i = 6; i >= 0; i--) {
        total += stepsList[6 - i];
        final date = now.subtract(Duration(days: i));
        const weedays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        daysList.add(weedays[date.weekday - 1]);
      }

      if (mounted) {
        setState(() {
          weeklySteps = stepsList;
          weeklyDays = daysList;
          todaySteps = stepsList.isNotEmpty ? stepsList.last : 0;
          avgSteps = (total / 7).round();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    double maxSteps = 10000;
    for (int s in weeklySteps) {
      if (s > maxSteps) maxSteps = s.toDouble() + 2000;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeIn(
                duration: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      FadeInDown(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          "Steps",
                          style: AppTypography.h1(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FadeInDown(
                        delay: const Duration(milliseconds: 100),
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          "Keep moving champion!",
                          style: AppTypography.body(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 30),

                      /// Big stat card
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.gradientPrimary,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      todaySteps.toString(),
                                      style: AppTypography.statLarge(color: Colors.white).copyWith(fontSize: 48),
                                    ),
                                    Text(
                                      "steps today",
                                      style: AppTypography.body(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 20),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: (todaySteps / 10000).clamp(0.0, 1.0),
                                        backgroundColor: Colors.white24,
                                        valueColor: const AlwaysStoppedAnimation(AppColors.accentGlow),
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${((todaySteps / 10000) * 100).toStringAsFixed(0)}% of 10,000 goal",
                                      style: AppTypography.caption(color: Colors.white70),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.directions_walk_rounded, color: Colors.white, size: 40),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      /// Week label
                      FadeInUp(
                        delay: const Duration(milliseconds: 300),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "LAST 7 DAYS",
                              style: AppTypography.label(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                            ),
                            Text(
                              "Avg $avgSteps/day",
                              style: AppTypography.caption(color: AppColors.accent).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Chart
                      Expanded(
                        child: FadeInUp(
                          delay: const Duration(milliseconds: 400),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 0.5),
                            ),
                            child: LineChart(
                              LineChartData(
                                maxY: maxSteps,
                                minY: 0,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: maxSteps / 4 == 0 ? 1 : maxSteps / 4,
                                  getDrawingHorizontalLine: (_) => FlLine(
                                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                    strokeWidth: 1,
                                    dashArray: [5, 5],
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      interval: 1, // Fixes repeated letters
                                      getTitlesWidget: (v, _) {
                                        if (v.toInt() >= weeklyDays.length || v.toInt() < 0) return const SizedBox();
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 12),
                                          child: Text(
                                            weeklyDays[v.toInt()],
                                            style: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    isCurved: true,
                                    curveSmoothness: 0.35,
                                    spots: List.generate(
                                      weeklySteps.length,
                                      (i) => FlSpot(i.toDouble(), weeklySteps[i].toDouble()),
                                    ),
                                    color: AppColors.accent,
                                    barWidth: 4,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                                        radius: 6,
                                        color: AppColors.accent,
                                        strokeColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [AppColors.accent.withValues(alpha: 0.3), AppColors.accent.withValues(alpha: 0)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
