import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Firebase Storage removed — will be re-enabled on Blaze plan
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_spacing.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/widgets/widgets.dart';
import 'package:fat_burner/widgets/weekly_chart.dart';

import 'package:fat_burner/constants/motivation_messages.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:fat_burner/providers/providers.dart';
import 'package:fat_burner/services/notification_service.dart';
import 'package:fat_burner/services/health_service.dart';
import 'package:fat_burner/services/shopify_purchase_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:fat_burner/screens/profile_screen.dart';
import 'package:fat_burner/screens/notifications_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool capsuleAM = false;
  bool capsulePM = false;
  Map<DateTime, int> streakData = {};
  Map<String, dynamic>? healthData;
  bool isLoadingHealth = true;
  bool _showPurchaseBanner = false;
  bool hasManualMetricsProof = false;
  String _userName = '';
  String? _profilePhotoUrl;
  bool _showFireAnimation = false;
  bool _healthPermissionsGranted = false;
  bool _apiDataEmpty = true;
  bool _apiHasRealData = false;
  int _currentStreak = 0;
  int _unreadNotifCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkHealthConnectPopup());
    _loadTodayStatus();
    _loadHealthData();
    _triggerDemoNotification();
    _listenForUnreadNotifications();
  }

  Future<void> _triggerDemoNotification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('welcome_notification_sent') == true) return;

      // Small delay so the home screen has time to render first
      await Future.delayed(const Duration(seconds: 3));

      await NotificationService.instance.showForegroundNotification(
        999,
        '🔥 Welcome to BetterAlt!',
        'Your Fat Burner journey starts now. Take your first capsule and verify it here!',
      );

      await prefs.setBool('welcome_notification_sent', true);
      debugPrint('FatBurner DEBUG: Welcome notification sent successfully');
    } catch (e) {
      debugPrint('FatBurner DEBUG: Welcome notification error: $e');
    }
  }

  /// Listens for unread notifications to show a badge on the bell icon.
  void _listenForUnreadNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() => _unreadNotifCount = snapshot.docs.length);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadHealthData();
      _loadTodayStatus();
    }
  }

  Future<void> _checkHealthConnectPopup() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('hasPromptedHealth') ?? false;
    
    try {
      final hasPerms = await HealthService.instance.hasPermissions();
      
      if (mounted) {
        setState(() => _healthPermissionsGranted = hasPerms);
      }
    } catch (e) {
      debugPrint('FatBurner DEBUG: _checkHealthConnectPopup error: $e');
    }
  }

  /// Manually retry health authorization (Health Connect on Android, HealthKit on iOS)
  Future<void> _retryHealthAuthorization() async {
    setState(() => isLoadingHealth = true);
    
    final granted = await HealthService.instance.requestAuthorization();
    final healthName = HealthService.healthServiceName;
    debugPrint('FatBurner DEBUG: Manual retry - Health permission granted: $granted');
    
    if (granted) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('hasPromptedHealth', true);
      if (mounted) {
        setState(() => _healthPermissionsGranted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$healthName access granted! Syncing your data...')),
        );
      }
    } else {
      await HealthService.instance.openHealthSettings();
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('hasPromptedHealth', true);
      if (mounted) {
        setState(() => _healthPermissionsGranted = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Opening $healthName... Please grant permissions.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
    
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    try {
      // 1. Fetch raw API data (Health Connect / HealthKit only — no Firestore fallback)
      final rawApiData = await HealthService.instance.fetchBasicHealthData();
      final int apiSteps = (rawApiData['steps'] ?? 0).toInt();
      final int apiCals = (rawApiData['calories'] ?? 0).toInt();
      final double apiSleep = (rawApiData['sleep'] ?? 0.0).toDouble();
      final double apiDist = (rawApiData['distance'] ?? 0.0).toDouble();
      final bool apiReturnedData = apiSteps > 0 || apiCals > 0 || apiSleep > 0 || apiDist > 0;

      // 2. Fetch data WITH Firestore manual fallback for display
      final data = await HealthService.instance.fetchBasicHealthDataWithFallback();
      
      if (mounted) {
        setState(() {
          healthData = data;
          isLoadingHealth = false;
          _apiHasRealData = apiReturnedData;
          
          final int s = (data['steps'] ?? 0).toInt();
          final int c = (data['calories'] ?? 0).toInt();
          final double sl = (data['sleep'] ?? 0.0).toDouble();
          final double d = (data['distance'] ?? 0.0).toDouble();
          
          if (apiReturnedData) {
            _healthPermissionsGranted = true;
            _apiDataEmpty = false;
          } else if (s > 0 || c > 0 || sl > 0 || d > 0) {
            // Has manual data but API returned nothing
            _apiDataEmpty = true;
          } else {
            _apiDataEmpty = true;
          }
        });
      }
    } catch (e) {
      debugPrint('FatBurner DEBUG: _loadHealthData error: $e');
      if (mounted) {
        setState(() {
          healthData = null;
          isLoadingHealth = false;
        });
      }
    }
  }

  String _getCurrentIstDateString() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return now.toIso8601String().substring(0, 10);
  }

  Future<void> _loadTodayStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check purchase status for banner
    try {
      await user.reload(); // Force refresh the Auth payload just in case the phone number was linked externally in Firebase Authentication
    } catch (e) {
      debugPrint("Could not reload user auth token: $e");
    }
    
    // Grab the freshest user instance after reload
    final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
    
    final userDocRecord = await FirebaseFirestore.instance.collection("users").doc(refreshedUser.uid).get();
    if (userDocRecord.exists) {
      final userDocData = userDocRecord.data();
      debugPrint("FatBurner DEBUG: User DB Document Loaded (UID: ${refreshedUser.uid})");

      bool hasPurchased = userDocData?["has_purchased"] ?? false;
      
      // ALWAYS check Shopify API on every load — real-time verification
      String? phoneToCheck = refreshedUser.phoneNumber 
          ?? userDocData?['phone_number'] 
          ?? userDocData?['phone'];
          
      String? actualEmail = refreshedUser.email ?? userDocData?['email'];
      
      if (actualEmail != null && actualEmail.endsWith('@betteralt.app')) {
        actualEmail = null;
      }

      if (phoneToCheck == null && refreshedUser.email != null && refreshedUser.email!.endsWith('@betteralt.app')) {
        phoneToCheck = refreshedUser.email!.split('@')[0];
      }
      
      debugPrint("FatBurner DEBUG: Firestore has_purchased=$hasPurchased, Checking Shopify with phone=$phoneToCheck email=$actualEmail");
      
      if (phoneToCheck != null || actualEmail != null) {
        try {
          final shopifyResult = await ShopifyPurchaseService.instance.hasPurchasedFatBurner(
            phone: phoneToCheck?.toString(),
            email: actualEmail?.toString(),
          );
          debugPrint("FatBurner DEBUG: Shopify API returned purchased=$shopifyResult");
          hasPurchased = shopifyResult;
          
          // Sync Firestore with latest Shopify result
          try {
            await FirebaseFirestore.instance.collection('users').doc(refreshedUser.uid).set({
              'has_purchased': shopifyResult,
            }, SetOptions(merge: true));
          } catch (_) {}
        } catch (e) {
          debugPrint("Failed to check Shopify: $e — using Firestore fallback: $hasPurchased");
        }
      }

      if (mounted) {
        setState(() {
          _userName = userDocData?['name'] ?? '';
          _showPurchaseBanner = !hasPurchased;
          if (userDocData?['profile_photo_url'] != null && userDocData!['profile_photo_url'].toString().isNotEmpty) {
            _profilePhotoUrl = userDocData['profile_photo_url'];
          } else if (userDocData?['profile_photo_base64'] != null && userDocData!['profile_photo_base64'].toString().isNotEmpty) {
            _profilePhotoUrl = 'base64:${userDocData['profile_photo_base64']}';
          } else {
            _profilePhotoUrl = null;
          }
        });
      }
    }

    final todayDoc = _getCurrentIstDateString();
    
    final docRef = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("daily_logs")
        .doc(todayDoc);
        
    final doc = await docRef.get();
    
    if (doc.exists) {
      if (mounted) {
        setState(() {
          capsuleAM = doc.data()?["capsuleDose1"] ?? false;
          capsulePM = doc.data()?["capsuleDose2"] ?? false;
        });
      }
    } else {
      await docRef.set({
        "capsuleDose1": false,
        "capsuleDose2": false,
        "steps": 0,
        "calories": 0,
        "lastUpdated": FieldValue.serverTimestamp(),
      });
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("daily_logs")
          .limit(100)
          .get();

      Map<DateTime, int> newStreak = {};
      for (var d in snapshot.docs) {
        try {
          final date = DateTime.parse(d.id);
          final bool am = d.data()["capsuleDose1"] ?? false;
          final bool pm = d.data()["capsuleDose2"] ?? false;
          final bool hasProof = d.data()["hasManualMetricsProof"] ?? false;
          final int steps = d.data()["steps"] ?? 0;
          final int calories = d.data()["calories"] ?? 0;
          
          if (am && pm) {
            newStreak[DateTime(date.year, date.month, date.day)] = 1;
          }
        } catch (_) {}
      }
      
      // Snapchat-style streak:
      // - Today taken → count from today backwards
      // - Today NOT taken yet → show yesterday's streak (grace: day not over)
      // - NEXT day after missing → yesterday also empty → streak = 0
      int consecutiveCount = 0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (newStreak.containsKey(today)) {
        // Today done — count backwards
        DateTime checkDate = today;
        while (newStreak.containsKey(checkDate)) {
          consecutiveCount++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      } else if (newStreak.containsKey(yesterday)) {
        // Today not done yet but yesterday was — show yesterday's count (grace period)
        DateTime checkDate = yesterday;
        while (newStreak.containsKey(checkDate)) {
          consecutiveCount++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        }
      }
      // If neither today nor yesterday: streak = 0 (already default)
      
      if (mounted) {
        setState(() {
          streakData = newStreak;
          _currentStreak = consecutiveCount;
        });
        NotificationService.instance.checkAndShowMilestoneReminders(consecutiveCount);
      }
    } catch (_) {}
  }
  Future<void> _updateStatus(String type, bool value) async {
    if (!value) return; 
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final bool isCapsule = (type == 'Dose1' || type == 'Dose2');
    // 10-day trust period: skip camera for the first 10 days
    final bool skipCamera = isCapsule && (streakData.length <= 10);

    XFile? photo;
    if (!skipCamera) {
      if (isCapsule) {
        // Show guidance before opening camera
        final bool? proceed = await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      // Capsule icon
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 36),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Capsule Verification",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accent.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Text("✋", style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Hold your capsules in your palm and take a clear photo",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "You can also show the BetterAlt Fat Burner bottle with the label visible",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(ctx, true),
                          icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                          label: const Text("Open Camera", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          "Cancel",
                          style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        
        if (proceed != true) return;
        
        final ImagePicker picker = ImagePicker();
        photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      } else {
        final String? choice = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Container(
              margin: const EdgeInsets.only(top: 60),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  )
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      
                      // Header
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_chart_rounded, color: AppColors.accent, size: 36),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Log Daily Metric", 
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.w800, 
                          color: isDark ? Colors.white : Colors.black87
                        )
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "How would you like to update your progress today?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15, 
                          height: 1.4, 
                          color: isDark ? Colors.white70 : Colors.black54
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Auto Screenshot Button
                      InkWell(
                        onTap: () => Navigator.pop(ctx, 'ocr'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                               BoxShadow(
                                 color: AppColors.accent.withOpacity(0.3), 
                                 blurRadius: 12, 
                                 offset: const Offset(0, 5)
                               ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Auto-Scan Screenshot", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text("Fastest • Upload smartwatch photo", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                                  ]
                                )
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white)
                            ]
                          )
                        )
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Manual Button
                      InkWell(
                        onTap: () => Navigator.pop(ctx, 'manual'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF7F7F7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.keyboard_alt_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Enter Manually", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 17, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text("Type your exact numbers", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 13)),
                                  ]
                                )
                              ),
                              Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white30 : Colors.black26)
                            ]
                          )
                        )
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Never mind", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 15, fontWeight: FontWeight.w600)),
                      )
                    ]
                  )
                )
              )
            );
          }
        );
        if (choice == null) return;

        if (choice == 'ocr') {
           final ImagePicker picker = ImagePicker();
           photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
           if (photo == null) return;
        } else if (choice == 'manual') {
           final manualResult = await _showManualMetricInputDialog(type);
           if (manualResult != null && manualResult > 0) {
              final todayDoc = _getCurrentIstDateString();
              
              int parsedSteps = (healthData?['steps'] ?? 0).toInt();
              int parsedCalories = (healthData?['calories'] ?? 0).toInt();
              double parsedSleep = (healthData?['sleep'] ?? 0.0).toDouble();
              double parsedDistance = (healthData?['distance'] ?? 0.0).toDouble();

              Map<String, dynamic> updateData = {
                "proof_$type": true,
                "hasManualMetricsProof": true,
                "lastUpdated": FieldValue.serverTimestamp(),
              };

              if (type == 'METRIC_STEPS') { parsedSteps = manualResult.toInt(); updateData['steps'] = parsedSteps; }
              else if (type == 'METRIC_CALS') { parsedCalories = manualResult.toInt(); updateData['calories'] = parsedCalories; }
              else if (type == 'METRIC_SLEEP') { parsedSleep = manualResult; updateData['sleep'] = parsedSleep; }
              else if (type == 'METRIC_DISTANCE') { parsedDistance = manualResult; updateData['distance'] = parsedDistance; }
              
              if (!mounted) return;
              await FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .collection("daily_logs")
                  .doc(todayDoc)
                  .set(updateData, SetOptions(merge: true));

              if (mounted) {
                 setState(() {
                    healthData ??= <String, dynamic>{};
                    if (parsedSteps > 0) healthData!['steps'] = parsedSteps;
                    if (parsedCalories > 0) healthData!['calories'] = parsedCalories;
                    if (parsedSleep > 0) healthData!['sleep'] = parsedSleep;
                    if (parsedDistance > 0) healthData!['distance'] = parsedDistance;
                    hasManualMetricsProof = true;
                 });
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Metrics manually uploaded successfully!")));
              }
           }
           return;
        }
      }
    }
    
    // If we're tracking a capsule and no photo was provided (either skipped or user canceled), proceed below
    if (photo == null && !skipCamera) return;

    if (isCapsule && photo != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.4));
        final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        
        final inputImage = InputImage.fromFilePath(photo.path);
        final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        bool isMedicine = false;
        
        // Collect all detected labels for multi-layer checks
        final Set<String> detectedLabels = {};
        for (var label in labels) {
          detectedLabels.add(label.label.toLowerCase());
        }
        debugPrint('FatBurner DEBUG: All ML labels: $detectedLabels');
        
        // ===== LAYER 1: Product-specific OCR text check =====
        // NOTE: 'betteralt' removed — multiple BetterAlt products exist.
        // These keywords are specific to the Fat Burner Pro Capsules label.
        final String extractedText = recognizedText.text.toLowerCase();
        int ocrScore = 0;
        const ocrKeywords = ['fat burner', 'pro capsules', 'thermogenic',
                             '7-in-1', 'l-carnitine', 'berberine', 'fenugreek',
                             'caffeine', 'apple cider', 'conjugated',
                             'linoleic', 'black pepper', 'nutraceutical',
                             'fat fighting'];
        for (final kw in ocrKeywords) {
          if (extractedText.contains(kw)) ocrScore++;
        }
        debugPrint('FatBurner DEBUG: Capsule OCR score: $ocrScore (text: ${extractedText.length > 100 ? extractedText.substring(0, 100) : extractedText})');
        // Require at least 1 keyword match to confirm Fat Burner label
        if (ocrScore >= 1) {
          isMedicine = true;
          debugPrint('FatBurner DEBUG: ✅ Passed via Layer 1 (Fat Burner label OCR)');
        }
        
        // ===== LAYER 2a: Object label check for bottle/supplement container =====
        if (!isMedicine) {
          const bottleLabels = {'bottle', 'pill', 'medicine', 'supplement', 'container',
                                'jar', 'product', 'plastic', 'capsule', 'tablet',
                                'pharmaceutical', 'drug', 'vitamin', 'health care'};
          for (final bl in bottleLabels) {
            if (detectedLabels.any((l) => l.contains(bl))) {
              isMedicine = true;
              debugPrint('FatBurner DEBUG: ✅ Passed via Layer 2a (Bottle/Supplement label: $bl)');
              break;
            }
          }
        }
        
        // ===== LAYER 2b: Capsule-in-hand detection =====
        // Hand + pill-like ML label = instant pass
        // Hand + no reject + capsule color detected = pass
        // Hand alone (no pill label, no capsule color) = FAIL
        if (!isMedicine) {
          const handLabels = {'hand', 'finger', 'thumb', 'nail', 'skin', 'gesture', 'wrist', 'palm'};
          const pillIndicators = {'pill', 'medicine', 'capsule', 'tablet',
                                  'pharmaceutical', 'drug', 'vitamin', 'supplement',
                                  'health care', 'medical'};
          const rejectLabels = {'pencil', 'pen', 'writing', 'stationery', 'office supplies',
                                'key', 'coin', 'lipstick', 'crayon', 'marker',
                                'cigarette', 'lighter', 'usb', 'cable', 'wire',
                                'toothbrush'};
          
          final bool hasHand = handLabels.any((h) => detectedLabels.any((l) => l.contains(h)));
          final bool hasPillLike = pillIndicators.any((p) => detectedLabels.any((l) => l.contains(p)));
          final bool hasRejectObject = rejectLabels.any((r) => detectedLabels.any((l) => l.contains(r)));
          
          if (hasRejectObject) {
            debugPrint('FatBurner DEBUG: ❌ Rejected via Layer 2b (Non-pill object detected)');
          } else if (hasHand && hasPillLike) {
            isMedicine = true;
            debugPrint('FatBurner DEBUG: ✅ Passed via Layer 2b (Hand + pill label)');
          } else if (hasHand) {
            // Hand but no pill label — check for capsule COLOR as additional evidence
            debugPrint('FatBurner DEBUG: 🔍 Hand detected, checking capsule color...');
            try {
              isMedicine = await _isCapsuleColorDetected(photo.path);
              if (isMedicine) {
                debugPrint('FatBurner DEBUG: ✅ Passed via Layer 2b+3 (Hand + capsule color)');
              } else {
                debugPrint('FatBurner DEBUG: ❌ Hand detected but NO capsule color → rejected');
              }
            } catch (e) {
              debugPrint('FatBurner DEBUG: Color detection error: $e');
            }
          } else {
            debugPrint('FatBurner DEBUG: ⏭ No hand detected, skipping Layer 2b');
          }
        }
        
        // ===== LAYER 3: Color-only fallback (no hand detected at all) =====
        if (!isMedicine) {
          try {
            isMedicine = await _isCapsuleColorDetected(photo.path);
            if (isMedicine) {
              debugPrint('FatBurner DEBUG: ✅ Passed via Layer 3 (Color-only fallback)');
            } else {
              debugPrint('FatBurner DEBUG: ❌ Failed all layers');
            }
          } catch (e) {
            debugPrint('FatBurner DEBUG: Color detection fallback error: $e');
          }
        }
        
        imageLabeler.close();
        textRecognizer.close();

        if (!isMedicine) {
          if (mounted) {
            Navigator.of(context).pop(); 
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.surfaceElevatedDk : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Text("Product Not Recognized", style: AppTypography.h3(color: AppColors.error)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "We couldn't verify your capsule. Please try one of these:\n\n"
                      "• Show the BetterAlt Fat Burner bottle with the label clearly visible\n"
                      "• Hold the capsules in your hand and take a photo",
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('images/fat_burner.jpeg', height: 120, fit: BoxFit.cover),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(), 
                    child: const Text("Try Again")
                  ),
                ],
              )
            );
          }
          return; // strictly enforce verification, no override allowed!
        }
        // Verification succeeded — pop the ML processing spinner
        if (mounted) Navigator.of(context).pop();
      } catch (_) {
        if (mounted) Navigator.of(context).pop(); 
      }
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final todayDoc = _getCurrentIstDateString();
    final int currentSteps = healthData?['steps'] ?? 0;
    final int currentCalories = (healthData?['calories'] ?? 0.0).round();
    final double currentSleep = (healthData?['sleep'] ?? 0.0).toDouble();
    final double currentDistance = (healthData?['distance'] ?? 0.0).toDouble();
    
    // Check if handling the manual metrics proof via OCR
    if (!isCapsule && photo != null) {
      try {
        // TODO: Re-enable Firebase Storage upload when on Blaze plan
        // final storageRef = FirebaseStorage.instance.ref().child('proofs/${user.uid}/${todayDoc}_$type.jpg');
        // await storageRef.putFile(File(photo.path));
        
        // OCR Metric Extraction logic
        int parsedSteps = currentSteps;
        int parsedCalories = currentCalories;
        double parsedSleep = currentSleep;
        double parsedDistance = currentDistance;

        try {
          final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
          final inputImage = InputImage.fromFilePath(photo.path);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          final String fullText = recognizedText.text.toLowerCase();
          debugPrint('FatBurner DEBUG: OCR raw text: $fullText');
          
          if (type == 'METRIC_SLEEP') {
             final lines = fullText.split('\n');
             for (int i = 0; i < lines.length; i++) {
               if (lines[i].contains('sleep')) {
                 for (int j = (i > 0 ? i - 1 : 0); j <= (i + 1 < lines.length ? i + 1 : i); j++) {
                   final m = RegExp(r'(\d+(?:\.\d+)?)\s*[hH]').firstMatch(lines[j]);
                   if (m != null) {
                     final s = double.tryParse(m.group(1)!) ?? 0.0;
                     if (s > 0 && s < 24) parsedSleep = s;
                     break;
                   }
                 }
               }
             }
             if (parsedSleep <= 0) { // Fallback
               final sleepMatch = RegExp(r'(\d+(?:\.\d+)?)\s*[hH]').firstMatch(fullText);
               if (sleepMatch != null) {
                  final s = double.tryParse(sleepMatch.group(1)!) ?? 0.0;
                  if (s > 0 && s < 24) parsedSleep = s;
               }
             }
          } else if (type == 'METRIC_DISTANCE') {
             final lines = fullText.split('\n');
             // Pass 1: Look for 'distance' keyword and check ±2 adjacent lines for number+unit
             for (int i = 0; i < lines.length && parsedDistance <= 0; i++) {
               if (lines[i].contains('distance')) {
                 final int scanStart = (i - 2).clamp(0, lines.length - 1);
                 final int scanEnd = (i + 2).clamp(0, lines.length - 1);
                 for (int j = scanStart; j <= scanEnd; j++) {
                   final m = RegExp(r'(\d+(?:\.\d+)?)\s*(km|k\s*m|m)\b').firstMatch(lines[j]);
                   if (m != null) {
                     final dist = double.tryParse(m.group(1)!) ?? 0.0;
                     final unitStr = (m.group(2) ?? 'km').replaceAll(' ', '');
                     // Always convert: if unit is 'm' (meters), divide by 1000 to get km
                     parsedDistance = unitStr == 'm' ? (dist / 1000.0) : dist;
                     debugPrint('FatBurner DEBUG: OCR distance=$dist $unitStr -> ${parsedDistance}km');
                     break;
                   }
                 }
                 // Pass 2: If unit was on a separate line, look for bare number near 'distance'
                 if (parsedDistance <= 0) {
                   bool hasMetersUnit = false;
                   bool hasKmUnit = false;
                   for (int j = scanStart; j <= scanEnd; j++) {
                     final unitLine = lines[j].trim();
                     if (unitLine == 'm' || unitLine == 'meter' || unitLine == 'meters') hasMetersUnit = true;
                     if (unitLine == 'km' || unitLine.contains('km')) hasKmUnit = true;
                   }
                   for (int j = scanStart; j <= scanEnd; j++) {
                     if (j == i) continue;
                     final numMatch = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(lines[j]);
                     if (numMatch != null) {
                       final dist = double.tryParse(numMatch.group(1)!) ?? 0.0;
                       if (dist > 0 && dist < 100000) {
                         if (hasKmUnit) {
                           parsedDistance = dist;
                         } else if (hasMetersUnit || dist > 10) {
                           parsedDistance = dist / 1000.0; // treat as meters, convert to km
                         } else {
                           parsedDistance = dist; // assume km
                         }
                         debugPrint('FatBurner DEBUG: OCR distance bare number=$dist -> ${parsedDistance}km');
                         break;
                       }
                     }
                   }
                 }
               }
             }
             // Pass 3: Global fallback — scan entire text for number+unit
             if (parsedDistance <= 0) {
               final distMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(km|k\s*m|m)\b').firstMatch(fullText);
               if (distMatch != null) {
                  final dist = double.tryParse(distMatch.group(1)!) ?? 0.0;
                  final unitStr = (distMatch.group(2) ?? 'km').replaceAll(' ', '');
                  parsedDistance = unitStr == 'm' ? (dist / 1000.0) : dist;
                  debugPrint('FatBurner DEBUG: OCR distance global fallback=$dist $unitStr -> ${parsedDistance}km');
               }
             }
            } else if (type == 'METRIC_CALS') {
               final lines = fullText.split('\n');
               // Pass 1: Look for cal/kcal/calorie keyword and check ±2 adjacent lines
               for (int i = 0; i < lines.length && parsedCalories <= 0; i++) {
                 if (lines[i].contains('cal') || lines[i].contains('kcal') || lines[i].contains('calorie')) {
                   final int scanStart = (i - 2).clamp(0, lines.length - 1);
                   final int scanEnd = (i + 2).clamp(0, lines.length - 1);
                   for (int j = scanStart; j <= scanEnd; j++) {
                     final m = RegExp(r'(\d+(?:,\d+)*)\s*(kcal|cal)').firstMatch(lines[j]);
                     if (m != null) {
                       final c = int.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
                       // Both 'cal' and 'kcal' from fitness apps mean kilocalories
                       if (c > 0) {
                         parsedCalories = c;
                         debugPrint('FatBurner DEBUG: OCR calories=$c (unit: ${m.group(2)}, treated as kcal)');
                       }
                       break;
                     }
                   }
                   // Pass 2: If 'Cal' was on a separate line, look for bare number near keyword
                   if (parsedCalories <= 0) {
                     for (int j = scanStart; j <= scanEnd; j++) {
                       if (j == i) continue;
                       final numMatch = RegExp(r'\b(\d+(?:,\d+)*)\b').firstMatch(lines[j]);
                       if (numMatch != null) {
                         final c = int.tryParse(numMatch.group(1)!.replaceAll(',', '')) ?? 0;
                         if (c > 0 && c < 50000) {
                           parsedCalories = c;
                           debugPrint('FatBurner DEBUG: OCR calories bare number=$c near calorie keyword (treated as kcal)');
                           break;
                         }
                       }
                     }
                   }
                 }
               }
               // Pass 3: Global fallback
               if (parsedCalories <= 0) {
                 final calsMatch = RegExp(r'(\d+(?:,\d+)*)\s*(kcal|cal)').firstMatch(fullText);
                 if (calsMatch != null) {
                    final c = int.tryParse(calsMatch.group(1)!.replaceAll(',', '')) ?? 0;
                    if (c > 0) {
                      parsedCalories = c;
                      debugPrint('FatBurner DEBUG: OCR calories global fallback=$c (treated as kcal)');
                    }
                 }
               }
            } else if (type == 'METRIC_STEPS') {
               final lines = fullText.split('\n');
               for (int i = 0; i < lines.length; i++) {
                 if (lines[i].contains('step')) {
                   final m = RegExp(r'(\d+(?:,\d+)*)').firstMatch(lines[i]);
                   if (m != null) {
                      final stk = int.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0;
                      if (stk > 0) parsedSteps = stk;
                   }
                 }
               }
               if (parsedSteps <= 0) { // Fallback
                  final stepsMatch = RegExp(r'(\d{1,3}(?:,\d{3})+|\d+)\s*steps').firstMatch(fullText);
                  if (stepsMatch != null) {
                    final stk = int.tryParse(stepsMatch.group(1)!.replaceAll(',', '')) ?? 0;
                    if (stk > 0) parsedSteps = stk;
                  }
               }
            }

          // ── Calories extraction (try multiple patterns) ──
          if (type == 'METRICS' || type == 'METRIC_CALS') {
            final calPatterns = [
              RegExp(r'([\d,]+)\s*(?:kcal|k\s*cal)'),                              // "350 kcal"
              RegExp(r'([\d,]+)\s*(?:cal)(?:\s|$|\b)'),                            // "350 Cal" (Google Fit)
              RegExp(r'([\d,]+)\s*(?:calories?|cals?)(?:\s|$|\b)'),                // "350 calories"
              RegExp(r'(?:kcal|calories?|cals?|cal|active\s*energy)\s*[:=\-]?\s*([\d,]+)'), // "calories: 350"
              RegExp(r'(?:calories?\s*burn(?:ed|t)?|burn(?:ed|t)?)\s*[:=\-]?\s*([\d,]+)'),  // "calories burned: 350"
            ];

          for (final pattern in calPatterns) {
            final match = pattern.firstMatch(fullText);
            if (match != null) {
              final raw = (match.group(1) ?? match.group(2) ?? '').replaceAll(',', '');
              final val = int.tryParse(raw);
              if (val != null && val > 0 && val < 50000) {
                parsedCalories = val;
                debugPrint('FatBurner DEBUG: OCR parsed calories=$parsedCalories');
                break;
              }
            }
          }

          // Calorie line-by-line scan fallback
          if (parsedCalories == currentCalories) {
            final lines = fullText.split('\n');
            for (int li = 0; li < lines.length; li++) {
              if (lines[li].contains('cal') || lines[li].contains('energy') || lines[li].contains('burn')) {
                for (int offset = 0; offset <= 1; offset++) {
                  for (int dir in [0, -1, 1]) {
                    final idx = li + dir + (dir == 0 ? 0 : offset);
                    if (idx >= 0 && idx < lines.length) {
                      final numMatch = RegExp(r'\b([\d,]+)\b').firstMatch(lines[idx]);
                      if (numMatch != null) {
                        final val = int.tryParse(numMatch.group(1)!.replaceAll(',', ''));
                        if (val != null && val > 0 && val < 50000) {
                          parsedCalories = val;
                          debugPrint('FatBurner DEBUG: OCR line-scan calories=$parsedCalories from line: ${lines[idx]}');
                          break;
                        }
                      }
                    }
                  }
                  if (parsedCalories != currentCalories) break;
                }
              }
              if (parsedCalories != currentCalories) break;
            }
          }
          } // End of Calories block

          await textRecognizer.close();
          debugPrint('FatBurner DEBUG: OCR final → Steps: $parsedSteps, Calories: $parsedCalories');
        } catch(e) {
          debugPrint("Failed to OCR metrics: $e");
        }

        // ── Manual input fallback ──
        // If OCR couldn't extract the values (still 0), let the user type them manually
        if (mounted && (
            (type == 'METRIC_STEPS' && parsedSteps <= 0) ||
            (type == 'METRIC_CALS' && parsedCalories <= 0) ||
            (type == 'METRIC_SLEEP' && parsedSleep <= 0) ||
            (type == 'METRIC_DISTANCE' && parsedDistance <= 0) ||
            ((type == 'METRICS' || type == 'METRIC_CALS' || type == 'METRIC_STEPS') && parsedSteps <= 0 && parsedCalories <= 0)
        )) {
          Navigator.of(context).pop(); // dismiss loading spinner
          final manualResult = await _showManualMetricInputDialog(type);
          if (manualResult != null) {
            if (type == 'METRIC_STEPS' && manualResult > 0) parsedSteps = manualResult.toInt();
            if (type == 'METRIC_CALS' && manualResult > 0) parsedCalories = manualResult.toInt();
            if (type == 'METRIC_SLEEP' && manualResult > 0) parsedSleep = manualResult; 
            if (type == 'METRIC_DISTANCE' && manualResult > 0) parsedDistance = manualResult; 
          } else {
            // User cancelled → don't save anything
            return;
          }
          // Re-show loading for the save
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => const Center(child: CircularProgressIndicator()),
            );
          }
        }
        // If only one metric was parsed and the other is still 0, show input for the missing one
        else if (mounted && type.startsWith('METRIC_')) {
          final bool stepsMissing = type == 'METRIC_STEPS' && parsedSteps <= 0;
          final bool calsMissing = type == 'METRIC_CALS' && parsedCalories <= 0;
          final bool sleepMissing = type == 'METRIC_SLEEP' && parsedSleep <= 0;
          final bool distMissing = type == 'METRIC_DISTANCE' && parsedDistance <= 0;
          
          if (stepsMissing || calsMissing || sleepMissing || distMissing) {
            Navigator.of(context, rootNavigator: true).pop(); // dismiss loading safely from anywhere
            final manualResult = await _showManualMetricInputDialog(type);
            if (manualResult != null && manualResult > 0) {
              if (stepsMissing) parsedSteps = manualResult.toInt();
              if (calsMissing) parsedCalories = manualResult.toInt();
              if (sleepMissing) parsedSleep = manualResult;
              if (distMissing) parsedDistance = manualResult;
            }
            // Re-show loading for the save
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                useRootNavigator: true,
                builder: (ctx) => const Center(child: CircularProgressIndicator()),
              );
            }
          }
        }

        Map<String, dynamic> updateData = {
          "proof_$type": true,
          "hasManualMetricsProof": true,
          "lastUpdated": FieldValue.serverTimestamp(),
        };

        if (type == 'METRIC_STEPS' || type == 'METRICS') updateData['steps'] = parsedSteps;
        if (type == 'METRIC_CALS' || type == 'METRICS') updateData['calories'] = parsedCalories;
        if (type == 'METRIC_SLEEP' || type == 'METRICS') updateData['sleep'] = parsedSleep;
        if (type == 'METRIC_DISTANCE' || type == 'METRICS') updateData['distance'] = parsedDistance;

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("daily_logs")
            .doc(todayDoc)
            .set(updateData, SetOptions(merge: true));

        // Update local state so UI reflects it immediately
        if (mounted) {
           setState(() {
              healthData ??= <String, dynamic>{};
              if (parsedSteps > 0) healthData!['steps'] = parsedSteps;
              if (parsedCalories > 0) healthData!['calories'] = parsedCalories;
              if (parsedSleep > 0) healthData!['sleep'] = parsedSleep;
              if (parsedDistance > 0) healthData!['distance'] = parsedDistance;
              hasManualMetricsProof = true;
           });
           Navigator.of(context, rootNavigator: true).pop(); 
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Metrics screenshot uploaded successfully!")));
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop(); 
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
        }
      }
      return;
    }
    
    try {
      // TODO: Re-enable Firebase Storage proof upload when on Blaze plan
      // Capsule verification is handled on-device via ML Kit (OCR + labels + color detection)
      
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .collection("daily_logs")
          .doc(todayDoc)
          .set({
        "capsule$type": true,
        "steps": currentSteps,
        "calories": currentCalories,
        "lastUpdated": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          if (type == 'Dose1') capsuleAM = true;
          if (type == 'Dose2') capsulePM = true;
          if (capsuleAM && capsulePM) {
            final now = DateTime.now();
            final todayKey = DateTime(now.year, now.month, now.day);
            streakData[todayKey] = 1;
            _showFireAnimation = true;
            
            // Immediately recalculate consecutive streak so UI updates instantly
            int newStreak = 0;
            DateTime checkDate = todayKey;
            while (streakData.containsKey(checkDate)) {
              newStreak++;
              checkDate = checkDate.subtract(const Duration(days: 1));
            }
            _currentStreak = newStreak;
          }
        });

        // Both capsules done → cancel the day-end streak loss notification (outside setState)
        if (capsuleAM && capsulePM) {
          try {
            NotificationService.instance.cancelDayEndNotification();
          } catch (_) {}
        }

        if (_showFireAnimation) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showFireAnimation = false;
              });
            }
          });
        }

        Navigator.of(context, rootNavigator: true).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully logged!")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to log: $e")));
      }
    }
  }

  /// Shows a manual input dialog when OCR fails to extract metric values.
  /// Returns the entered value, or null if canceled.
  Future<double?> _showManualMetricInputDialog(String type) async {
    final controller = TextEditingController();
    String title;
    String hint;
    String unit;
    
    switch (type) {
      case 'METRIC_STEPS':
        title = 'Enter Steps';
        hint = 'e.g. 8500';
        unit = 'steps';
        break;
      case 'METRIC_CALS':
        title = 'Enter Calories';
        hint = 'e.g. 350';
        unit = 'kcal';
        break;
      case 'METRIC_SLEEP':
        title = 'Enter Sleep (hours)';
        hint = 'e.g. 6.5';
        unit = 'h';
        break;
      case 'METRIC_DISTANCE':
        title = 'Enter Distance (km)';
        hint = 'e.g. 5.5';
        unit = 'km';
        break;
      default:
        title = 'Enter Value';
        hint = 'e.g. 100';
        unit = '';
    }

    final result = await showDialog<double?>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return ZoomIn(
          duration: const Duration(milliseconds: 300),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E).withOpacity(0.9) : Colors.white.withOpacity(0.9),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
              ),
              titlePadding: const EdgeInsets.only(top: 24, left: 24, right: 24),
              contentPadding: const EdgeInsets.all(24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_note_rounded, color: AppColors.accent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Simply enter your reading below. We'll instantly update your dashboard.",
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                        suffixText: unit,
                        suffixStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF9F9F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: AppColors.accent, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      ),
                    ),
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: Text("Never mind", style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.accent.withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      onPressed: () {
                        final val = double.tryParse(controller.text.trim().replaceAll(',', ''));
                        Navigator.of(ctx).pop(val);
                      },
                      child: const Text("Save Log", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final int steps = healthData?['steps'] ?? 0;
    final int calories = (healthData?['calories'] ?? 0.0).round();
    final double sleep = healthData?['sleep'] ?? 0.0;
    final double distance = healthData?['distance'] ?? 0.0;
    

    return Stack(
      children: [
        Scaffold(
      backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            /// App Bar Area
            SliverAppBar(
              backgroundColor: isDark ? AppColors.canvasDark : AppColors.canvasLight,
              surfaceTintColor: Colors.transparent,
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.15),
              forceElevated: true,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                side: BorderSide(
                  color: isDark ? AppColors.borderDark : const Color(0xFFDCD6D0), 
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              pinned: true,
              toolbarHeight: 60,
              title: Container(
                child: Image.asset(
                  'images/Betteralt_main_logo.jpeg',
                  height: 65, // Enlarged by a bit as requested
                  fit: BoxFit.contain,
                ),
              ),
              centerTitle: false,
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 24, top: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceElevatedDk : AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_none_rounded, color: isDark ? AppColors.textOnDark : AppColors.textPrimary, size: 24),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(8),
                        onPressed: () async {
                          // Mark all as read when user opens notifications
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final unread = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('notifications')
                                .where('read', isEqualTo: false)
                                .get();
                            final batch = FirebaseFirestore.instance.batch();
                            for (final doc in unread.docs) {
                              batch.update(doc.reference, {'read': true});
                            }
                            await batch.commit();
                          }
                          if (context.mounted) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                          }
                        },
                      ),
                      // Unread badge
                      if (_unreadNotifCount > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              _unreadNotifCount > 9 ? '9+' : _unreadNotifCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Purchase Notice Banner (If Any)
                    if (_showPurchaseBanner) ...[
                      _buildPurchaseNote(isDark),
                      const SizedBox(height: 20),
                    ],

                    /// Truecaller-style Greeting & Avatar Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Welcome,",
                                style: AppTypography.label(color: isDark ? Colors.white54 : Colors.black54),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      (_userName.isEmpty && (user?.displayName == null || user!.displayName!.isEmpty)) 
                                          ? 'Champion' 
                                          : _userName.isNotEmpty ? _userName : user!.displayName!,
                                      style: GoogleFonts.inter(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : Colors.black87,
                                        letterSpacing: -0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.surfaceElevatedDk.withOpacity(0.5) : AppColors.surfaceElevated.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text("🔥", style: TextStyle(fontSize: 14)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _currentStreak.toString(),
                                          style: AppTypography.label(color: isDark ? AppColors.textOnDark : AppColors.textPrimary).copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Profile Avatar
                        GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
                            );
                            // Refresh user data (including profile photo) when returning
                            _loadTodayStatus();
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceElevatedDk : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF40485D) : Colors.black,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Builder(
                                builder: (context) {
                                  try {
                                    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
                                      if (_profilePhotoUrl!.startsWith('base64:')) {
                                        return Image.memory(
                                          base64Decode(_profilePhotoUrl!.substring(7)),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: isDark ? Colors.white54 : Colors.grey, size: 28),
                                        );
                                      }
                                      return Image.network(
                                        _profilePhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: isDark ? Colors.white54 : Colors.grey, size: 28),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint("Error loading profile image: $e");
                                  }
                                  return (user?.photoURL != null
                                      ? Image.network(user!.photoURL!, fit: BoxFit.cover)
                                      : Icon(Icons.person_rounded, color: isDark ? Colors.white54 : Colors.grey, size: 28));
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    /// Fat Burner Toggle Card
                    _fatBurnerCard(isDark),

                    const SizedBox(height: 16),

                    /// Daily Motivational Streak Card
                    _buildMotivationCard(isDark),

                    const SizedBox(height: 16),

                    /// What Can You Expect Forward Banner
                    _buildExpectationBanner(isDark),

                    const SizedBox(height: 35),

                    // Spacer maintained from previous block

                    /// Stats Grid section
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      child: Text(
                        "RECOMMENDED METRICS",
                        style: AppTypography.label(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    /// Show health sync banner when API hasn't returned real data
                    /// (manual/screenshot inputs do NOT suppress this banner)
                    if (!_apiHasRealData && !isLoadingHealth) ...[
                      _buildHealthSyncBanner(isDark),
                      const SizedBox(height: 16),
                    ],

                    Row(
                      children: [
                        Expanded(child: StatCard(title: "Steps", value: steps.toString(), subtitle: "Recommended Goal: 10k", icon: Icons.directions_walk_rounded, colorOverride: AppColors.accent, index: 1, actionText: (steps == 0) ? "Upload" : null, onTapAction: (steps == 0) ? () => _updateStatus('METRIC_STEPS', true) : null)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: StatCard(title: "Calories", value: calories.toString(), subtitle: "Recommended Goal: 500 kcal", icon: Icons.local_fire_department_rounded, colorOverride: AppColors.warning, index: 2, actionText: (calories == 0) ? "Upload" : null, onTapAction: (calories == 0) ? () => _updateStatus('METRIC_CALS', true) : null)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(child: StatCard(title: "Sleep", value: "${sleep.toStringAsFixed(1)}h", subtitle: "Recommended Goal: 7h", icon: Icons.bedtime_rounded, colorOverride: AppColors.chartPurple, index: 3, actionText: (sleep == 0) ? "Upload" : null, onTapAction: (sleep == 0) ? () => _updateStatus('METRIC_SLEEP', true) : null)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: StatCard(title: "Distance", value: "${distance.toStringAsFixed(1)}km", subtitle: "Recommended Goal: 5km", icon: Icons.route_rounded, colorOverride: AppColors.chartBlue, index: 4, actionText: (distance == 0) ? "Upload" : null, onTapAction: (distance == 0) ? () => _updateStatus('METRIC_DISTANCE', true) : null)),
                      ],
                    ),

                    const SizedBox(height: 35),

                    /// 90-Day Streak Heatmap
                    FadeInUp(
                      duration: const Duration(milliseconds: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "90-DAY PROGRESS",
                            style: AppTypography.label(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 0.5),
                            ),
                            child: _build90DayProgress(isDark),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 35),

                    /// Know Your Product Section
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "KNOW YOUR PRODUCT",
                            style: AppTypography.label(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (final img in ['images/1.jpeg', 'images/2.jpeg', 'images/3.jpeg', 'images/4.jpeg', 'images/5.jpeg', 'images/6.jpeg'])
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        backgroundColor: Colors.transparent,
                                        insetPadding: const EdgeInsets.all(16),
                                        child: GestureDetector(
                                          onTap: () => Navigator.of(context).pop(),
                                          child: InteractiveViewer(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(16),
                                              child: Image.asset(img, fit: BoxFit.contain),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(img, fit: BoxFit.cover),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100), // spacing for bottom nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    if (_showFireAnimation)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: ZoomIn(
                  duration: const Duration(milliseconds: 300),
                  child: Pulse(
                    infinite: true,
                    child: const Icon(Icons.local_fire_department_rounded, color: Colors.deepOrangeAccent, size: 180),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _fatBurnerCard(bool isDark) {
    bool allTaken = capsuleAM && capsulePM;
    final bool skipCamera = streakData.length <= 10;

    return FadeInUp(
      duration: const Duration(milliseconds: 700),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: allTaken
                ? [AppColors.success, AppColors.success.withValues(alpha: 0.8)]
                : [isDark ? AppColors.surfaceDark : AppColors.surfaceLight, isDark ? AppColors.surfaceElevatedDk : AppColors.surfaceElevated],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: allTaken ? AppColors.success.withValues(alpha: 0.5) : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: allTaken ? 1.5 : 1,
          ),
          boxShadow: allTaken
              ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))]
              : [],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                "images/fat_burner.jpeg",
                height: 50,
                width: 50,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stk) => Container(
                  height: 50,
                  width: 50,
                  color: isDark ? Colors.white12 : Colors.black12,
                  child: Icon(Icons.medication_liquid_rounded, color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Fat Burner Pro Capsules",
                    style: AppTypography.h3(color: allTaken ? Colors.white : (isDark ? AppColors.textOnDark : AppColors.textPrimary)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    allTaken ? "Taken today. Great job!" : "Don't forget your capsules today",
                    style: AppTypography.body(color: allTaken ? Colors.white70 : (isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)).copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCapsuleButton(isDark, "Capsule 1", capsuleAM, (val) => _updateStatus('Dose1', val), allTaken, skipCamera),
                const SizedBox(height: 8),
                _buildCapsuleButton(isDark, "Capsule 2", capsulePM, (val) => _updateStatus('Dose2', val), allTaken, skipCamera),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleButton(bool isDark, String label, bool isTaken, Function(bool) onChanged, bool allTaken, bool skipCamera) {
    return GestureDetector(
      onTap: isTaken ? null : () => onChanged(true),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isTaken ? AppColors.success : (isDark ? AppColors.canvasDark : AppColors.surfaceElevated),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTaken ? AppColors.success : (isDark ? AppColors.borderDark : AppColors.borderLight),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isTaken 
                  ? Icons.check_circle_rounded 
                  : (skipCamera ? Icons.radio_button_unchecked_rounded : Icons.photo_camera_rounded),
              size: 16,
              color: isTaken ? Colors.white : (allTaken ? Colors.white70 : (isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption(
                color: isTaken ? Colors.white : (allTaken ? Colors.white70 : (isDark ? AppColors.textOnDark : AppColors.textPrimary)),
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseNote(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  "images/fat_burner.jpeg",
                  height: 60,
                  width: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stk) => Container(
                    height: 60,
                    width: 60,
                    color: Colors.grey.withValues(alpha: 0.2),
                    child: const Icon(Icons.fitness_center),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Purchase Required",
                      style: AppTypography.h3(color: AppColors.error),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "We found that you have not purchased the fat burner. Click on Buy Now to purchase the fat burner.",
                      style: AppTypography.body(
                        color: isDark ? AppColors.textOnDark : AppColors.textPrimary,
                      ).copyWith(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53238),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        try {
                          await FirebaseAnalytics.instance.logEvent(
                            name: 'clicked_buy_fatburner',
                            parameters: {'source': 'home_banner_red'},
                          );
                        } catch (e) {
                          debugPrint('Analytics error: $e');
                        }
                        
                        final Uri url = Uri.parse('https://betteralt.in/products/fat-burner-capsules?utm_source=betteralt_app&utm_medium=android_app&utm_campaign=red_banner');
                        if (!await launchUrl(url)) {
                          debugPrint('Could not launch $url');
                        }
                      },
                      child: const Text("Buy Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24), // Space for close button
            ],
          ),
          Positioned(
            top: -10,
            right: -10,
            child: IconButton(
              icon: const Icon(Icons.close, color: AppColors.textTertiary, size: 20),
              onPressed: () {
                setState(() {
                  _showPurchaseBanner = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard(bool isDark) {
    final int streakCount = _currentStreak;
    final bool isComeback = streakData.isNotEmpty && streakData.length > _currentStreak;
    final String message;
    
    if (streakCount == 0) {
      // Streak is broken right now
      if (streakData.isNotEmpty) {
        message = "Ready to restart your streak? Take your capsules today and begin again! 💪";
      } else {
        message = "Ready to start? Take your first capsule and begin the 90-Day Challenge! 🚀";
      }
    } else if (isComeback) {
      // User is on a comeback — use comeback messages
      if (streakCount <= comebackMotivationMessages.length) {
        message = comebackMotivationMessages[streakCount - 1];
      } else {
        message = beyondNinetyComebackMessage;
      }
    } else if (streakCount <= motivationMessages.length) {
      message = motivationMessages[streakCount - 1];
    } else {
      message = beyondNinetyMessage;
    }

    return FadeInUp(
      duration: const Duration(milliseconds: 750),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                : [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(
            color: Colors.orange.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Text("💪", style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "DAILY MOTIVATION",
                    style: AppTypography.label(
                      color: Colors.orange.shade700,
                    ).copyWith(fontSize: 11, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
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

  /// Premium "What to Expect" banner — Stitch Design System (Glassmorphic Timeline)
  Widget _buildExpectationBanner(bool isDark) {
    final int totalDaysLogged = streakData.length;
    
    final List<Map<String, dynamic>> milestones = [
      {
        'days': 1,
        'phase': 'Phase 1 (Day 1)',
        'title': 'Initial Surge',
        'desc': 'Experience an immediate boost in energy as your metabolism primes for the journey ahead.',
        'icon': '⚡',
      },
      {
        'days': 14,
        'phase': 'Phase 2 (2 Weeks)',
        'title': 'Appetite Mastery',
        'desc': 'Natural suppression of cravings sets in. Pair with light activity for accelerated results.',
        'icon': '🎯',
      },
      {
        'days': 28,
        'phase': 'Phase 3 (4 Weeks)',
        'title': 'Metabolic Equilibrium',
        'desc': 'Blood sugar levels stabilize, creating a consistent foundation for fat oxidation.',
        'icon': '⚖️',
      },
      {
        'days': 42,
        'phase': 'Phase 4 (6 Weeks)',
        'title': 'Cellular Ignition',
        'desc': 'Thermogenesis triggers and your body begins utilizing stored fat as its primary fuel.',
        'icon': '🔥',
      },
      {
        'days': 56,
        'phase': 'Phase 5 (8 Weeks)',
        'title': 'The Lightness Effect',
        'desc': 'Noticeable reduction in bloating and water retention. Movement feels effortless.',
        'icon': '🪶',
      },
      {
        'days': 70,
        'phase': 'Phase 6 (10 Weeks)',
        'title': 'Visual Evolution',
        'desc': 'Aesthetic changes become undeniable as definition surfaces in target areas.',
        'icon': '✨',
      },
      {
        'days': 84,
        'phase': 'Phase 7 (12 Weeks)',
        'title': 'Peak Performance',
        'desc': 'Your metabolism is now a high-efficiency machine. Maintain the habit for lasting results.',
        'icon': '🏆',
      },
    ];

    // Calculate progress percentage
    final double progress = (totalDaysLogged / 84).clamp(0.0, 1.0);

    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF0D1B0D).withOpacity(0.85),
                        const Color(0xFF0A1A12).withOpacity(0.92),
                      ]
                    : [
                        const Color(0xFFFAF8F5).withOpacity(0.9),
                        const Color(0xFFF5F0E8).withOpacity(0.95),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? AppColors.accent.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? AppColors.accent.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Section ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.accent.withOpacity(0.2),
                                  AppColors.accent.withOpacity(0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Text("🧬", style: TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "YOUR TRANSFORMATION",
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: isDark ? AppColors.accent : AppColors.accent,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  "90-Day Science-Backed Journey",
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // ── Progress Bar ──
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.accent, AppColors.accentGlow],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Day $totalDaysLogged of 90",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          Text(
                            "${(progress * 100).toInt()}% Complete",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // ── Subtle divider via tonal shift ──
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                ),
                const SizedBox(height: 16),
                // ── Timeline ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                  child: Column(
                    children: milestones.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final milestone = entry.value;
                      final bool isCompleted = totalDaysLogged >= (milestone['days'] as int);
                      final bool isNext = !isCompleted &&
                          (index == 0 || totalDaysLogged >= (milestones[index - 1]['days'] as int));
                      final bool isLast = index == milestones.length - 1;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Timeline column: icon + connector ──
                          Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 500),
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted
                                      ? AppColors.accent
                                      : isNext
                                          ? AppColors.accent.withOpacity(0.15)
                                          : isDark
                                              ? Colors.white.withOpacity(0.05)
                                              : Colors.black.withOpacity(0.04),
                                  border: isNext
                                      ? Border.all(color: AppColors.accent, width: 2)
                                      : isCompleted
                                          ? null
                                          : Border.all(
                                              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                                              width: 1,
                                            ),
                                  boxShadow: isCompleted
                                      ? [
                                          BoxShadow(
                                            color: AppColors.accent.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : isNext
                                          ? [
                                              BoxShadow(
                                                color: AppColors.accent.withOpacity(0.15),
                                                blurRadius: 12,
                                                offset: const Offset(0, 0),
                                              ),
                                            ]
                                          : [],
                                ),
                                child: isCompleted
                                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                    : isNext
                                        ? Icon(Icons.arrow_forward_rounded, color: AppColors.accent, size: 15)
                                        : Center(
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.1),
                                              ),
                                            ),
                                          ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: isCompleted
                                          ? [AppColors.accent.withOpacity(0.5), AppColors.accent.withOpacity(0.2)]
                                          : [
                                              isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                                              isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                                            ],
                                    ),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // ── Content column ──
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isNext
                                      ? (isDark
                                          ? AppColors.accent.withOpacity(0.06)
                                          : AppColors.accent.withOpacity(0.04))
                                      : isCompleted
                                          ? (isDark
                                              ? Colors.white.withOpacity(0.03)
                                              : Colors.black.withOpacity(0.015))
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: isNext
                                      ? Border.all(
                                          color: AppColors.accent.withOpacity(0.15),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          milestone['icon'] as String,
                                          style: TextStyle(fontSize: isNext ? 16 : 14),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          milestone['phase'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.0,
                                            color: isCompleted
                                                ? AppColors.accent.withOpacity(0.7)
                                                : isNext
                                                    ? AppColors.accent
                                                    : isDark
                                                        ? Colors.white.withOpacity(0.2)
                                                        : Colors.black.withOpacity(0.2),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (isCompleted)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.accent.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "DONE",
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: AppColors.accent,
                                              ),
                                            ),
                                          ),
                                        if (isNext)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [AppColors.accent, AppColors.accentGlow],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              "CURRENT",
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      milestone['title'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: isCompleted || isNext ? FontWeight.w700 : FontWeight.w600,
                                        color: isCompleted
                                            ? (isDark ? Colors.white.withOpacity(0.9) : Colors.black87)
                                            : isNext
                                                ? (isDark ? Colors.white : Colors.black87)
                                                : (isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      milestone['desc'] as String,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                        height: 1.5,
                                        color: isCompleted
                                            ? (isDark ? Colors.white.withOpacity(0.55) : Colors.black.withOpacity(0.5))
                                            : isNext
                                                ? (isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.45))
                                                : (isDark ? Colors.white.withOpacity(0.18) : Colors.black.withOpacity(0.2)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Banner shown when health permissions haven't been granted yet
  Widget _buildHealthSyncBanner(bool isDark) {
    final healthName = HealthService.healthServiceName;
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.info.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.info.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sync_rounded, color: AppColors.info, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sync Health Data",
                    style: AppTypography.bodyMedium(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Grant $healthName access to auto-track your steps, calories, and more.",
                    style: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              onPressed: _retryHealthAuthorization,
              child: const Text("Enable", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner shown when health service has permissions but no data — no tracker connected
  Widget _buildNoTrackerBanner(bool isDark) {
    final healthName = HealthService.healthServiceName;
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.warning.withOpacity(0.3), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.watch_off_rounded, color: AppColors.warning, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "No Fitness Tracker Detected",
                    style: AppTypography.bodyMedium(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "$healthName is enabled, but no fitness app is syncing data. Connect a fitness tracker or health app to $healthName to auto-track your steps and calories.",
              style: AppTypography.caption(
                color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary,
              ).copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(color: AppColors.warning.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text("Open $healthName", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () => HealthService.instance.openHealthSettings(),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _loadHealthData,
                  child: Text("Refresh", style: AppTypography.caption(color: AppColors.info).copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "\u{1F4A1} Tip: You can also manually upload your data using the \"Upload\" buttons on each metric card below.",
              style: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textTertiary).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build90DayProgress(bool isDark) {
    final now = DateTime.now();
    return TableCalendar(
      firstDay: DateTime.utc(now.year, now.month - 12, 1),
      lastDay: DateTime.utc(now.year, now.month + 1, 31),
      focusedDay: now,
      availableCalendarFormats: const { CalendarFormat.month : 'Month' },
      headerStyle: HeaderStyle(
        titleTextStyle: AppTypography.h3(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
        leftChevronIcon: Icon(Icons.chevron_left, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
        rightChevronIcon: Icon(Icons.chevron_right, color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
        weekendStyle: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
      ),
      calendarStyle: CalendarStyle(
        defaultTextStyle: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
        weekendTextStyle: AppTypography.body(color: isDark ? AppColors.textOnDark : AppColors.textPrimary),
        outsideTextStyle: AppTypography.caption(color: isDark ? AppColors.textOnDarkMuted : AppColors.textTertiary),
        todayDecoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          final normalizedDate = DateTime(date.year, date.month, date.day);
          final hasCompleted = streakData.containsKey(normalizedDate);
          if (hasCompleted) {
            return Positioned(
              bottom: 4,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const Icon(Icons.local_fire_department, size: 10, color: Colors.white),
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }

  /// Capsule color detection — analyzes the center of the image for the specific
  /// golden-amber/turmeric color of the BetterAlt Fat Burner capsule.
  /// This intentionally uses a narrow HSL range to reject other capsule colors.
  Future<bool> _isCapsuleColorDetected(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(format: ImageByteFormat.rawRgba);
    if (byteData == null) return false;

    final pixels = byteData.buffer.asUint8List();
    final int w = image.width;
    final int h = image.height;

    // Sample center 40% of the image (where capsule sits in hand)
    final int startX = (w * 0.3).toInt();
    final int endX = (w * 0.7).toInt();
    final int startY = (h * 0.3).toInt();
    final int endY = (h * 0.7).toInt();

    int matchingPixels = 0;
    int totalSampled = 0;

    // Sample every 3rd pixel for performance
    for (int y = startY; y < endY; y += 3) {
      for (int x = startX; x < endX; x += 3) {
        final int offset = (y * w + x) * 4;
        if (offset + 2 >= pixels.length) continue;

        final int r = pixels[offset];
        final int g = pixels[offset + 1];
        final int b = pixels[offset + 2];

        // Convert to HSL
        final hsl = _rgbToHsl(r, g, b);
        
        // Fat Burner capsule is golden-amber, translucent, with visible granules.
        // Key color signature: distinctly YELLOW (hue 38-65) and SATURATED (0.35+)
        // 
        // Why this works:
        //   - Skin tone: Hue 10-35, Saturation 0.15-0.40 → EXCLUDED (too orange, too muted)
        //   - Wood table: Hue 20-40, Saturation 0.10-0.35 → EXCLUDED (too muted)
        //   - Capsule:    Hue 38-65, Saturation 0.35+     → MATCHED (more yellow, more vivid)
        //
        // The capsule's color is MORE YELLOW and MORE SATURATED than skin or wood,
        // so we don't need to explicitly exclude those — just match the capsule's range.
        final bool isCapsuleColor = 
            (hsl[0] >= 38 && hsl[0] <= 65 &&       // Hue: golden-yellow to amber
             hsl[1] >= 0.35 &&                      // Saturation: vivid (NOT muted like skin/wood)
             hsl[2] >= 0.25 && hsl[2] <= 0.75);    // Lightness: medium range

        if (isCapsuleColor) {
          matchingPixels++;
        }
        totalSampled++;
      }
    }

    final double matchPercentage = totalSampled > 0 ? matchingPixels / totalSampled : 0;
    debugPrint('FatBurner DEBUG: Capsule color match: ${(matchPercentage * 100).toStringAsFixed(1)}% ($matchingPixels/$totalSampled pixels)');

    // At least 1% of center pixels must match the capsule's golden-amber
    // Empty palm → ~0% (skin is too orange/muted to match)
    // Capsule in hand → 1-8% (golden capsule pixels are vivid enough)
    return matchPercentage >= 0.01;
  }

  /// Convert RGB to HSL color space.
  /// Returns [hue (0-360), saturation (0-1), lightness (0-1)].
  List<double> _rgbToHsl(int r, int g, int b) {
    final double rd = r / 255, gd = g / 255, bd = b / 255;
    final double maxC = math.max(rd, math.max(gd, bd));
    final double minC = math.min(rd, math.min(gd, bd));
    double h = 0, s = 0;
    final double l = (maxC + minC) / 2;

    if (maxC != minC) {
      final double d = maxC - minC;
      s = l > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC);
      if (maxC == rd) {
        h = (gd - bd) / d + (gd < bd ? 6 : 0);
      } else if (maxC == gd) {
        h = (bd - rd) / d + 2;
      } else {
        h = (rd - gd) / d + 4;
      }
      h *= 60;
    }
    return [h, s, l];
  }
}

class _HorizontalCalendarRow extends StatefulWidget {
  const _HorizontalCalendarRow();

  @override
  State<_HorizontalCalendarRow> createState() => _HorizontalCalendarRowState();
}

class _HorizontalCalendarRowState extends State<_HorizontalCalendarRow> {
  int _selectedDay = DateTime.now().day;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14, // 2 weeks
        itemBuilder: (context, index) {
          // Generate a moving date window (7 days back, 7 days forward)
          final date = now.subtract(const Duration(days: 6)).add(Duration(days: index));
          final isSelected = date.day == _selectedDay;
          final isToday = date.day == now.day && date.month == now.month;

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDay = date.day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.accent : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.accent : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getWeekdayShort(date.weekday),
                    style: AppTypography.caption(
                      color: isSelected ? AppColors.textOnAccent : (isDark ? AppColors.textOnDarkMuted : AppColors.textTertiary),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    date.day.toString(),
                    style: AppTypography.h3(
                      color: isSelected ? AppColors.textOnAccent : (isDark ? AppColors.textOnDark : AppColors.textPrimary),
                    ).copyWith(fontSize: 20),
                  ),
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(top: 4.0),
                      height: 4,
                      width: 4,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.textOnAccent : AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getWeekdayShort(int weekday) {
    switch (weekday) {
      case 1: return 'MON';
      case 2: return 'TUE';
      case 3: return 'WED';
      case 4: return 'THU';
      case 5: return 'FRI';
      case 6: return 'SAT';
      case 7: return 'SUN';
      default: return '';
    }
  }
}
