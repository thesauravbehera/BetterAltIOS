import 'dart:io';

import 'package:health/health.dart';
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

  /// Request permissions
  Future<bool> requestAuthorization() async {
    await configure();
    return _health.requestAuthorization(_typesToRead, permissions: _permissions);
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
      print("FatBurner DEBUG ActiveData Length: ${activeData.length}");
      for (final point in activeData) {
        if (point.value is NumericHealthValue) {
          total += (point.value as NumericHealthValue).numericValue;
        }
      }
    } catch (e) {
      print("FatBurner DEBUG ActiveData Error: $e");
    }

    if (total == 0) {
      try {
        final totalData = await _health.getHealthDataFromTypes(
          types: const [HealthDataType.TOTAL_CALORIES_BURNED],
          startTime: midnight,
          endTime: now,
        );
        print("FatBurner DEBUG TotalData Length: ${totalData.length}");
        for (final point in totalData) {
          if (point.value is NumericHealthValue) {
            total += (point.value as NumericHealthValue).numericValue;
          }
        }
      } catch (e) {
        print("FatBurner DEBUG TotalData Error: $e");
      }
    }

    print("FatBurner DEBUG Final Total Calories: $total");
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
      print("FatBurner DEBUG Distance Error: $e");
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
      print("FatBurner DEBUG Sleep Error: $e");
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
      print("FatBurner DEBUG Water Error: $e");
    }

    print("FatBurner DEBUG Results - Steps: $steps, Calories: $calories, Dist: $distance, Sleep: $sleepMin, Water: $waterLiters");

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
}