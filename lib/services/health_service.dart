import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fat_burner/models/health_data_model.dart';

class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final Health _health = Health();

  static const List<HealthDataType> _typesToRead = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.WEIGHT,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.WATER,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool _configured = false;

  /// Configure plugin
  Future<void> configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Request permissions — returns true only if all permissions were actually granted.
  Future<bool> requestAuthorization() async {
    await configure();
    
    if (Platform.isAndroid) {
      // 1. Android requires Physical Activity permission before Health Connect allows reading steps
      debugPrint('FatBurner DEBUG: Requesting ACTIVITY_RECOGNITION permission...');
      final activityStatus = await Permission.activityRecognition.status;
      debugPrint('FatBurner DEBUG: ACTIVITY_RECOGNITION status: $activityStatus');
      if (!activityStatus.isGranted) {
        final result = await Permission.activityRecognition.request();
        debugPrint('FatBurner DEBUG: ACTIVITY_RECOGNITION request result: $result');
        if (!result.isGranted) {
          debugPrint('FatBurner DEBUG: ACTIVITY_RECOGNITION DENIED — steps may not work');
        }
      }

      // 2. Check if Health Connect is installed
      debugPrint('FatBurner DEBUG: Checking Health Connect SDK status...');
      try {
        final status = await _health.getHealthConnectSdkStatus();
        debugPrint('FatBurner DEBUG: Health Connect SDK status: $status');
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint('FatBurner DEBUG: Health Connect NOT available — prompting install...');
          await _health.installHealthConnect();
          // DO NOT return false here. The SDK check is buggy on Android 14. Try anyway!
        }
      } catch (e) {
        debugPrint('FatBurner DEBUG: getHealthConnectSdkStatus() error: $e');
        // On some devices this throws — treat as unavailable and try anyway
      }
    }
    
    try {
      debugPrint('FatBurner DEBUG: Requesting Health authorization for ${_typesToRead.length} types...');
      final authorized = await _health.requestAuthorization(_typesToRead, permissions: _permissions);
      debugPrint('FatBurner DEBUG: requestAuthorization() returned: $authorized');
      
      // If the intent succeeded (meaning they interacted with the screen), return true.
      // We do NOT strictly check hasPermissions() here, because if they granted
      // only STEPS but denied SLEEP, hasPermissions() returns false!
      return authorized;
    } catch (e) {
      debugPrint('FatBurner DEBUG: RequestAuth Error: $e');
      return false;
    }
  }

  /// Check permissions
  Future<bool> hasPermissions() async {
    await configure();
    final result =
        await _health.hasPermissions(_typesToRead, permissions: _permissions);
    return result ?? false;
  }

  /// Get today's steps
  Future<int> getTodaySteps() async {
    await configure();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final steps = await _health.getTotalStepsInInterval(midnight, now);
    return steps ?? 0;
  }

  /// Get today's calories
  Future<int> getTodayCaloriesBurned() async {
    await configure();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    double total = 0;

    try {
      final activeData = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: now,
      );
      debugPrint("FatBurner DEBUG ActiveData Length: ${activeData.length}");
      for (final point in activeData) {
        if (point.value is NumericHealthValue) {
          total += (point.value as NumericHealthValue).numericValue;
        }
      }
    } catch (e) {
      debugPrint("FatBurner DEBUG ActiveData Error: $e");
    }

    if (total == 0) {
      try {
        final totalData = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.TOTAL_CALORIES_BURNED],
          startTime: midnight,
          endTime: now,
        );
        debugPrint("FatBurner DEBUG TotalData Length: ${totalData.length}");
        for (final point in totalData) {
          if (point.value is NumericHealthValue) {
            total += (point.value as NumericHealthValue).numericValue;
          }
        }
      } catch (e) {
        debugPrint("FatBurner DEBUG TotalData Error: $e");
      }
    }

    debugPrint("FatBurner DEBUG Final Total Calories: $total");
    return total.round();
  }

  /// Get latest weight
  Future<double?> getLatestWeight() async {
    await configure();
    final now = DateTime.now();
    final past = now.subtract(const Duration(days: 365));

    final data = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.WEIGHT],
      startTime: past,
      endTime: now,
    );

    if (data.isEmpty) return null;

    data.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

    final latest = data.first;

    if (latest.value is NumericHealthValue) {
      return (latest.value as NumericHealthValue).numericValue.toDouble();
    }

    return null;
  }

  /// Combined model (optional)
  Future<HealthDataModel?> getTodayHealthData(String userId) async {
    await configure();

    final steps = await getTodaySteps();
    final caloriesBurned = await getTodayCaloriesBurned();
    final weight = await getLatestWeight();

    return HealthDataModel(
      id: 'today-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      date: DateTime.now(),
      steps: steps,
      weight: weight,
      caloriesBurned: caloriesBurned,
      caloriesConsumed: null,
    );
  }

  /// ⭐ Normalize health data
  Map<String, dynamic> normalizeHealthData(Map<String, dynamic> rawData) {
    int steps = (rawData['steps'] ?? 0) as int;
    double calories = (rawData['calories'] ?? 0).toDouble();
    double distance = (rawData['distance'] ?? 0).toDouble();

    // Prevent negative values
    if (steps < 0) steps = 0;
    if (calories < 0) calories = 0;
    if (distance < 0) distance = 0;

    // Convert meters → km (if needed)
    double distanceKm = distance;
    if (distance > 1000) {
      distanceKm = distance / 1000;
    }

    return {
      'steps': steps,
      'calories': calories,
      'distance': distanceKm,
    };
  }

  /// ⭐ MAIN FUNCTION (USE THIS IN DASHBOARD)
  Future<Map<String, dynamic>> fetchBasicHealthData() async {
    await configure();

    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    int steps = await getTodaySteps();
    double calories = (await getTodayCaloriesBurned()).toDouble();
    double distance = 0;
    double sleepMin = 0;
    double waterLiters = 0;

    // Fetch Distance safely
    try {
      final distData = await _health.getHealthDataFromTypes(
        startTime: midnight, endTime: now, types: [HealthDataType.DISTANCE_WALKING_RUNNING, HealthDataType.DISTANCE_DELTA]
      );
      for (final p in distData) {
        if (p.value is NumericHealthValue) distance += (p.value as NumericHealthValue).numericValue;
      }
    } catch (e) {
      debugPrint("FatBurner DEBUG Distance Error: $e");
    }
    
    // Fallback: If Health Connect doesn't explicitly sync distance, calculate it from steps (average human stride ~ 0.762m)
    if (distance == 0 && steps > 0) {
      distance = steps * 0.762;
    }

    // Fetch Sleep safely
    try {
      final sleepData = await _health.getHealthDataFromTypes(
        startTime: midnight.subtract(const Duration(hours: 18)), endTime: now, types: [HealthDataType.SLEEP_ASLEEP, HealthDataType.SLEEP_SESSION]
      );
      for (final p in sleepData) {
        // Sleep on Android/iOS can be SleepHealthValue or other variants. Safest is to use the duration interval.
        sleepMin += p.dateTo.difference(p.dateFrom).inMinutes.toDouble();
      }
    } catch (e) {
      debugPrint("FatBurner DEBUG Sleep Error: $e");
    }

    // Fetch Water safely
    try {
      final waterData = await _health.getHealthDataFromTypes(
        startTime: midnight, endTime: now, types: [HealthDataType.WATER]
      );
      for (final p in waterData) {
        if (p.value is NumericHealthValue) waterLiters += (p.value as NumericHealthValue).numericValue;
      }
    } catch (e) {
      debugPrint("FatBurner DEBUG Water Error: $e");
    }

    debugPrint("FatBurner DEBUG Results - Steps: $steps, Calories: $calories, Dist: $distance, Sleep: $sleepMin, Water: $waterLiters");

    final rawData = {
      'steps': steps,
      'calories': calories,
      'distance': distance / 1000.0, // convert meters to kilometers
      'sleep': sleepMin / 60.0, // convert to hours
      'water': waterLiters,
    };

    return rawData;
  }

  Future<bool> isAvailable() async {
    if (Platform.isAndroid) {
      return _health.isHealthConnectAvailable();
    }
    return true;
  }

  /// Returns the platform-specific name for the health service.
  static String get healthServiceName {
    if (Platform.isAndroid) return 'Health Connect';
    if (Platform.isIOS) return 'Apple Health';
    return 'Health';
  }

  /// Opens health platform settings — Health Connect on Android, Apple Health/Settings on iOS.
  Future<void> openHealthSettings() async {
    if (Platform.isAndroid) {
      await _openHealthConnectSettings();
    } else if (Platform.isIOS) {
      await _openHealthKitSettings();
    }
  }

  /// Opens Health Connect settings on Android so the user can connect fitness apps.
  Future<void> _openHealthConnectSettings() async {
    // Try opening Health Connect directly via Play Store
    try {
      final uri = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('FatBurner DEBUG: Could not open Health Connect: $e');
    }
    
    // Fallback: open Android Settings
    try {
      await openAppSettings();
    } catch (e) {
      debugPrint('FatBurner DEBUG: Could not open settings: $e');
    }
  }

  /// Opens Apple Health / iOS Settings for HealthKit permissions.
  Future<void> _openHealthKitSettings() async {
    try {
      // On iOS, opening the Health app directly isn't possible via URL scheme,
      // but we can open the app's own Settings page where Health permissions live.
      await openAppSettings();
    } catch (e) {
      debugPrint('FatBurner DEBUG: Could not open iOS settings: $e');
    }
  }

  /// Legacy method for backward compatibility
  Future<void> openHealthConnectSettings() async {
    await openHealthSettings();
  }

  /// Check if all health data are zero — indicates no fitness tracker connected.
  bool isHealthDataEmpty(Map<String, dynamic>? data) {
    if (data == null) return true;
    final steps = data['steps'] ?? 0;
    final calories = (data['calories'] ?? 0.0);
    final distance = (data['distance'] ?? 0.0);
    final sleep = (data['sleep'] ?? 0.0);
    final water = (data['water'] ?? 0.0);
    return steps == 0 && calories == 0 && distance == 0 && sleep == 0 && water == 0;
  }

  /// Live 7-Day Steps Polling
  Future<List<int>> fetch7DaysSteps() async {
    await configure();
    List<int> stepsList = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final midnight = DateTime(date.year, date.month, date.day);
      
      // For today, fetch up to 'now', for previous days fetch up to 23:59:59
      final endTime = (i == 0) ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      final steps = await _health.getTotalStepsInInterval(midnight, endTime);
      stepsList.add(steps ?? 0);
    }
    return stepsList;
  }

  /// Live 7-Day Calories Polling
  Future<List<int>> fetch7DaysCalories() async {
    await configure();
    List<int> calList = [];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final midnight = DateTime(date.year, date.month, date.day);
      final endTime = (i == 0) ? now : DateTime(date.year, date.month, date.day, 23, 59, 59);

      final data = await _health.getHealthDataFromTypes(
        types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: midnight,
        endTime: endTime,
      );

      double total = 0;
      for (final point in data) {
        if (point.value is NumericHealthValue) {
          total += (point.value as NumericHealthValue).numericValue.toDouble();
        }
      }

      if (total == 0) {
        try {
          final totalData = await _health.getHealthDataFromTypes(
            types: const [HealthDataType.TOTAL_CALORIES_BURNED],
            startTime: midnight,
            endTime: endTime,
          );
          for (final point in totalData) {
            if (point.value is NumericHealthValue) {
              total += (point.value as NumericHealthValue).numericValue.toDouble();
            }
          }
        } catch (_) {}
      }

      calList.add(total.round());
    }
    return calList;
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Fallback methods: Health Connect → Firestore manual upload data
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// IST date string helper (matches home_screen format for daily_logs doc IDs)
  String _getIstDateString(DateTime date) {
    final ist = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('yyyy-MM-dd').format(ist);
  }

  /// Fetch 7 days of steps with Firestore fallback.
  /// For each day: if Health Connect returns 0, check Firestore daily_logs for
  /// manually uploaded steps (from the OCR upload on home page).
  Future<List<int>> fetch7DaysStepsWithFallback() async {
    final user = FirebaseAuth.instance.currentUser;

    // Get Health Connect data first
    final hcSteps = await fetch7DaysSteps();

    if (user == null) return hcSteps;

    final now = DateTime.now();
    List<int> result = List.from(hcSteps);

    for (int i = 0; i < 7; i++) {
      // Only check Firestore if Health Connect returned 0 for this day
      if (result[i] == 0) {
        final date = now.subtract(Duration(days: 6 - i));
        final dateStr = _getIstDateString(date);

        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('daily_logs')
              .doc(dateStr)
              .get();

          if (doc.exists) {
            final manualSteps = doc.data()?['steps'] ?? 0;
            if (manualSteps is int && manualSteps > 0) {
              result[i] = manualSteps;
              debugPrint('FatBurner DEBUG: Day $dateStr - HC steps=0, using Firestore steps=$manualSteps');
            }
          }
        } catch (e) {
          debugPrint('FatBurner DEBUG: Firestore fallback error for $dateStr: $e');
        }
      }
    }

    return result;
  }

  /// Fetch 7 days of calories with Firestore fallback.
  /// For each day: if Health Connect returns 0, check Firestore daily_logs for
  /// manually uploaded calories (from the OCR upload on home page).
  Future<List<int>> fetch7DaysCaloriesWithFallback() async {
    final user = FirebaseAuth.instance.currentUser;

    // Get Health Connect data first
    final hcCalories = await fetch7DaysCalories();

    if (user == null) return hcCalories;

    final now = DateTime.now();
    List<int> result = List.from(hcCalories);

    for (int i = 0; i < 7; i++) {
      // Only check Firestore if Health Connect returned 0 for this day
      if (result[i] == 0) {
        final date = now.subtract(Duration(days: 6 - i));
        final dateStr = _getIstDateString(date);

        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('daily_logs')
              .doc(dateStr)
              .get();

          if (doc.exists) {
            final manualCalories = doc.data()?['calories'] ?? 0;
            final calValue = (manualCalories is double) ? manualCalories.round() : (manualCalories is int ? manualCalories : 0);
            if (calValue > 0) {
              result[i] = calValue;
              debugPrint('FatBurner DEBUG: Day $dateStr - HC calories=0, using Firestore calories=$calValue');
            }
          }
        } catch (e) {
          debugPrint('FatBurner DEBUG: Firestore fallback error for $dateStr: $e');
        }
      }
    }

    return result;
  }

  /// Fetch today's basic health data with Firestore fallback for steps & calories.
  /// If Health Connect returns 0, check Firestore daily_logs for today's manual upload.
  Future<Map<String, dynamic>> fetchBasicHealthDataWithFallback() async {
    final user = FirebaseAuth.instance.currentUser;
    final data = await fetchBasicHealthData();

    if (user == null) return data;

    final todaySteps = data['steps'] ?? 0;
    final todayCalories = data['calories'] ?? 0;
    final todaySleep = data['sleep'] ?? 0.0;
    final todayDistance = data['distance'] ?? 0.0;

    // Only fall back to Firestore if HC returned 0 for any metric
    if (todaySteps == 0 || todayCalories == 0 || todaySleep == 0 || todayDistance == 0) {
      final todayDoc = _getIstDateString(DateTime.now());

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('daily_logs')
            .doc(todayDoc)
            .get();

        if (doc.exists) {
          final d = doc.data()!;
          if (todaySteps == 0) {
            final manualSteps = d['steps'] ?? 0;
            if (manualSteps is int && manualSteps > 0) data['steps'] = manualSteps;
          }
          if (todayCalories == 0) {
            final manualCal = d['calories'] ?? 0;
            final calValue = (manualCal is double) ? manualCal.round() : (manualCal is int ? manualCal : 0);
            if (calValue > 0) data['calories'] = calValue;
          }
          if (todaySleep == 0) {
            final manualSleep = d['sleep'] ?? 0.0;
            final slpVal = manualSleep is int ? manualSleep.toDouble() : manualSleep;
            if (slpVal > 0) data['sleep'] = slpVal;
          }
          if (todayDistance == 0) {
            final manualDist = d['distance'] ?? 0.0;
            final distVal = manualDist is int ? manualDist.toDouble() : manualDist;
            if (distVal > 0) data['distance'] = distVal;
          }
        }
      } catch (e) {
        debugPrint('FatBurner DEBUG: Today Firestore fallback error: $e');
      }
    }

    return data;
  }
}