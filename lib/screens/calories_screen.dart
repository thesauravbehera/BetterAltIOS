import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fat_burner/services/health_service.dart';
import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/theme/app_spacing.dart';

class CaloriesScreen extends StatefulWidget {
  const CaloriesScreen({super.key});

  @override
  State<CaloriesScreen> createState() => _CaloriesScreenState();
}

class _CaloriesScreenState extends State<CaloriesScreen> {
  List<int> weeklyCalories = List.filled(7, 0);
  List<String> weeklyDays = List.filled(7, '');
  int todayCalories = 0;
  int avgCalories = 0;
  bool isLoading = true;

  /// Goal for active calories burned (kcal)
  static const int goalCalories = 500;

  @override
  void initState() {
    super.initState();
    _fetchCalories();
  }

  Future<void> _fetchCalories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final calList = await HealthService.instance.fetch7DaysCaloriesWithFallback();
      int total = 0;
      List<String> daysList = [];
      final now = DateTime.now();

      for (int i = 6; i >= 0; i--) {
        total += calList[6 - i];
        final date = now.subtract(Duration(days: i));
        const weedays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        daysList.add(weedays[date.weekday - 1]);
      }

      if (mounted) {
        setState(() {
          weeklyCalories = calList;
          weeklyDays = daysList;
          todayCalories = calList.isNotEmpty ? calList.last : 0;
          avgCalories = (total / 7).round();
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
    
    // Dynamic max: use the goal OR highest day value (whichever is bigger) + small buffer
    int highestDay = 0;
    for (int c in weeklyCalories) {
      if (c > highestDay) highestDay = c;
    }
    // maxCal is at least the goal + 20% buffer, or the highest day + 100
    double maxCal = (highestDay > goalCalories)  
        ? highestDay.toDouble() + 100
        : goalCalories * 1.2;

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
                          "Active Calorie Burn",
                          style: AppTypography.h1(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                        ),
                      ),

                      const SizedBox(height: 4),
                      FadeInDown(
                        delay: const Duration(milliseconds: 100),
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          "Fuel your body proper",
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
                            gradient: LinearGradient(
                              colors: [AppColors.warning, AppColors.warning.withValues(alpha: 0.8)],
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
                                      todayCalories.toString(),
                                      style: AppTypography.statLarge(color: Colors.white).copyWith(fontSize: 48),
                                    ),
                                    Text(
                                      "kcal burned today",
                                      style: AppTypography.body(color: Colors.white70),
                                    ),
                                    const SizedBox(height: 20),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: (todayCalories / goalCalories).clamp(0.0, 1.0),
                                        backgroundColor: Colors.white24,
                                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${((todayCalories / goalCalories) * 100).toStringAsFixed(0)}% of $goalCalories kcal goal",
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
                                child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 40),
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
                              "Avg $avgCalories kcal",
                              style: AppTypography.caption(color: AppColors.warning).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Chart — bars scale against the goal value (500 kcal)
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
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceEvenly,
                                maxY: maxCal,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: maxCal / 4 == 0 ? 1 : maxCal / 4,
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
                                // Goal line at 500 kcal
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: goalCalories.toDouble(),
                                      color: isDark ? Colors.white38 : Colors.black26,
                                      strokeWidth: 1.5,
                                      dashArray: [8, 4],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.topRight,
                                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                                        style: AppTypography.caption(
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                                        labelResolver: (_) => '$goalCalories goal',
                                      ),
                                    ),
                                  ],
                                ),
                                barGroups: [
                                  for (int i = 0; i < 7; i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: weeklyCalories[i].toDouble(),
                                          color: weeklyCalories[i] >= goalCalories 
                                              ? AppColors.success 
                                              : AppColors.warning,
                                          width: 14,
                                          borderRadius: BorderRadius.circular(4),
                                          backDrawRodData: BackgroundBarChartRodData(
                                            show: true,
                                            toY: maxCal,
                                            color: isDark ? AppColors.surfaceElevatedDk : AppColors.surfaceElevated,
                                          ),
                                        ),
                                      ],
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
