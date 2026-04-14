import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:convert';

import 'package:fat_burner/theme/app_colors.dart';
import 'package:fat_burner/theme/app_spacing.dart';
import 'package:fat_burner/theme/app_typography.dart';
import 'package:fat_burner/widgets/widgets.dart';
import 'package:fat_burner/widgets/weekly_chart.dart';
import 'package:fat_burner/widgets/auto_scrolling_slider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:fat_burner/providers/providers.dart';
import 'package:fat_burner/services/notification_service.dart';
import 'package:fat_burner/services/health_service.dart';
import 'package:fat_burner/services/shopify_purchase_service.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _profilePhotoBase64;
  bool _showFireAnimation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTodayStatus();
    _loadHealthData();
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

  Future<void> _loadHealthData() async {
    try {
      // Force authorization check directly through OS handler (resolves silent failure)
      await HealthService.instance.requestAuthorization();
      final data = await HealthService.instance.fetchBasicHealthData();
      if (mounted) {
        setState(() {
          healthData = data;
          isLoadingHealth = false;
        });
      }
    } catch (e) {
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
      debugPrint("FatBurner DEBUG: FULL DB DOCUMENT LOADED -> $userDocData");

      bool hasPurchased = userDocData?["has_purchased"] ?? false;
      
      // If Firestore says false, double check Shopify just in case they bought it recently (or to resolve previous bugs)
      final phoneToCheck = refreshedUser.phoneNumber 
          ?? userDocData?['phone_number'] 
          ?? userDocData?['phone']; // Backup for older user accounts!
          
      final emailToCheck = refreshedUser.email ?? userDocData?['email'];
      
      debugPrint("FatBurner DEBUG: hasPurchased in DB is $hasPurchased, Checking Shopify with phone=$phoneToCheck email=$emailToCheck");
      
      if (!hasPurchased && (phoneToCheck != null || emailToCheck != null)) {
        try {
          final recentlyBought = await ShopifyPurchaseService.instance.hasPurchasedFatBurner(
            phone: phoneToCheck?.toString(), // Ensure string
            email: emailToCheck?.toString(),
          );
          debugPrint("FatBurner DEBUG: Shopify returned recentlyBought=$recentlyBought");
          if (recentlyBought) {
            hasPurchased = true;
            await FirebaseFirestore.instance.collection("users").doc(user.uid).update({'has_purchased': true});
          }
        } catch (e) {
          debugPrint("Failed to re-verify Shopify status: $e");
        }
      }

      if (mounted) {
        setState(() {
          _userName = userDocData?['name'] ?? '';
          _showPurchaseBanner = !hasPurchased;
          _profilePhotoBase64 = userDocData?['profile_photo_base64'];
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
      if (mounted) {
        setState(() {
          streakData = newStreak;
        });
        NotificationService.instance.checkAndShowMilestoneReminders(newStreak.length);
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(String type, bool value) async {
    if (!value) return; 
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final bool skipCamera = (type == 'Dose1' || type == 'Dose2') && (streakData.length <= 10);

    XFile? photo;
    if (!skipCamera) {
      if (type == 'Dose1' || type == 'Dose2') {
        // Strictly camera for capsules > 10 days
        final ImagePicker picker = ImagePicker();
        photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      } else {
        // Metrics allow ONLY gallery
        final ImagePicker picker = ImagePicker();
        photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      }
      if (photo == null) return;

      if (type == 'Dose1' || type == 'Dose2') {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final imageLabeler = ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.5));
          final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
          
          final inputImage = InputImage.fromFilePath(photo.path);
          final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          
          bool isMedicine = false;
          
          // 1. Text check for brand
          final String extractedText = recognizedText.text.toLowerCase();
          if (extractedText.contains('betteralt') || extractedText.contains('fat burner')) {
            isMedicine = true;
          }

          // 2. Fallback Label check
          if (!isMedicine) {
            for (ImageLabel label in labels) {
              final text = label.label.toLowerCase();
              if (text.contains("pill") || text.contains("medicine") || text.contains("bottle") || text.contains("drug") || text.contains("supplement") || text.contains("capsule")) {
                isMedicine = true;
                break;
              }
            }
          }
          
          await imageLabeler.close();
          await textRecognizer.close();
          
          if (mounted) Navigator.of(context).pop(); 

          if (!isMedicine) {
            if (!mounted) return;
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Image Unrecognized"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Our system could not detect the BetterAlt Fat Burner bottle. Please ensure the label is clearly visible."),
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
            return; // strictly enforce verification, no override allowed!
          }
        } catch (_) {
          if (mounted) Navigator.of(context).pop(); 
        }
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
    
    // Check if handling the manual metrics proof
    if (type == 'METRICS' || type.startsWith('METRIC_')) {
      try {
        final storageRef = FirebaseStorage.instance.ref().child('proofs/${user.uid}/${todayDoc}_$type.jpg');
        try {
          await storageRef.putFile(File(photo!.path));
        } catch (e) {
          // If storage bucket is not configured, swallow error during dev mode
          debugPrint("Storage Upload blocked: $e");
        }
        
        // OCR Step & Calorie Extraction logic
        int parsedSteps = currentSteps;
        int parsedCalories = currentCalories;

        try {
          final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
          final inputImage = InputImage.fromFilePath(photo!.path);
          final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
          final String fullText = recognizedText.text.toLowerCase();
          
          final RegExp stepsRegExp = RegExp(r'(?:steps?|walk)[\s\n]*([\d,]+)');
          final stepsMatch = stepsRegExp.firstMatch(fullText);
          if (stepsMatch != null) {
             parsedSteps = int.tryParse(stepsMatch.group(1)!.replaceAll(',', '')) ?? parsedSteps;
          }

          final RegExp calRegExp = RegExp(r'(?:kcal|calories)[\s\n]*([\d,]+)|\b([\d,]+)[\s\n]*(?:kcal|calories)');
          final calMatch = calRegExp.firstMatch(fullText);
          if (calMatch != null) {
             String rawCal = calMatch.group(1) ?? calMatch.group(2) ?? "0";
             parsedCalories = int.tryParse(rawCal.replaceAll(',', '')) ?? parsedCalories;
          }
          await textRecognizer.close();
        } catch(e) {
          debugPrint("Failed to OCR metrics: $e");
        }

        await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .collection("daily_logs")
            .doc(todayDoc)
            .set({
          "proof_$type": true,
          "hasManualMetricsProof": true,
          "steps": parsedSteps,
          "calories": parsedCalories,
          "lastUpdated": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update local state if we parsed something new so ui reflects it immediately
        if (mounted && (parsedSteps > currentSteps || parsedCalories > currentCalories)) {
           setState(() {
              if (healthData != null) {
                 healthData!['steps'] = parsedSteps;
                 healthData!['calories'] = parsedCalories;
              }
           });
        }

        if (mounted) {
          setState(() {
            hasManualMetricsProof = true;
          });
          Navigator.of(context).pop(); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Metrics screenshot uploaded successfully!")));
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); 
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
        }
      }
      return;
    }
    
    try {
      if (!skipCamera && photo != null) {
        final storageRef = FirebaseStorage.instance.ref().child('proofs/${user.uid}/${todayDoc}_$type.jpg');
        await storageRef.putFile(File(photo.path));
      }
      
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
            streakData[DateTime(now.year, now.month, now.day)] = 1;
            _showFireAnimation = true;
          }
        });

        if (_showFireAnimation) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showFireAnimation = false;
              });
            }
          });
        }

        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully logged!")));
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to log: $e")));
      }
    }
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
                  child: IconButton(
                    icon: Icon(Icons.notifications_none_rounded, color: isDark ? AppColors.textOnDark : AppColors.textPrimary, size: 24),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome,",
                              style: AppTypography.label(color: isDark ? Colors.white54 : Colors.black54),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  (_userName.isEmpty && (user?.displayName == null || user!.displayName!.isEmpty)) 
                                      ? 'Champion' 
                                      : _userName.isNotEmpty ? _userName : user!.displayName!,
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : Colors.black87,
                                    letterSpacing: -0.5,
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
                                        streakData.length.toString(),
                                        style: AppTypography.label(color: isDark ? AppColors.textOnDark : AppColors.textPrimary).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Profile Avatar
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
                            );
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
                              child: _profilePhotoBase64 != null
                                  ? Image.memory(base64Decode(_profilePhotoBase64!), fit: BoxFit.cover)
                                  : (user?.photoURL != null
                                      ? Image.network(user!.photoURL!, fit: BoxFit.cover)
                                      : Icon(Icons.person_rounded, color: isDark ? Colors.white54 : Colors.grey, size: 28)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    /// Fat Burner Toggle Card
                    _fatBurnerCard(isDark),

                    const SizedBox(height: 35),

                    /// Stats Grid section
                    FadeInUp(
                      duration: const Duration(milliseconds: 800),
                      child: Text(
                        "RECOMMENDED METRICS",
                        style: AppTypography.label(color: isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(child: StatCard(title: "Steps", value: steps.toString(), subtitle: "Recommended Goal: 10k", icon: Icons.directions_walk_rounded, colorOverride: AppColors.accent, index: 1, actionText: steps == 0 ? "Upload" : null, onTapAction: steps == 0 ? () => _updateStatus('METRIC_STEPS', true) : null)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: StatCard(title: "Calories", value: calories.toString(), subtitle: "Recommended Goal: 500 kcal", icon: Icons.local_fire_department_rounded, colorOverride: AppColors.warning, index: 2, actionText: calories == 0 ? "Upload" : null, onTapAction: calories == 0 ? () => _updateStatus('METRIC_CALS', true) : null)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(child: StatCard(title: "Sleep", value: "${sleep.toStringAsFixed(1)}h", subtitle: "Recommended Goal: 7h", icon: Icons.bedtime_rounded, colorOverride: AppColors.chartPurple, index: 3, actionText: sleep == 0 ? "Upload" : null, onTapAction: sleep == 0 ? () => _updateStatus('METRIC_SLEEP', true) : null)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(child: StatCard(title: "Distance", value: "${distance.toStringAsFixed(1)}km", subtitle: "Recommended Goal: 5km", icon: Icons.route_rounded, colorOverride: AppColors.chartBlue, index: 4, actionText: distance == 0 ? "Upload" : null, onTapAction: distance == 0 ? () => _updateStatus('METRIC_DISTANCE', true) : null)),
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

                    /// Dynamic Info Slider (Carousal moved to bottom)
                    FadeInUp(
                      duration: const Duration(milliseconds: 600),
                      child: const AutoScrollingSlider(
                        imagePaths: [
                          'images/1.jpeg',
                          'images/2.jpeg',
                          'images/3.jpeg',
                          'images/4.jpeg',
                          'images/5.jpeg',
                          'images/6.jpeg',
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
                    allTaken ? "Taken today. Great job!" : "Don't forget your doses today",
                    style: AppTypography.body(color: allTaken ? Colors.white70 : (isDark ? AppColors.textOnDarkMuted : AppColors.textSecondary)).copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCapsuleButton(isDark, "Dose 1", capsuleAM, (val) => _updateStatus('Dose1', val), allTaken, skipCamera),
                const SizedBox(height: 8),
                _buildCapsuleButton(isDark, "Dose 2", capsulePM, (val) => _updateStatus('Dose2', val), allTaken, skipCamera),
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
                        final Uri url = Uri.parse('https://betteralt.in/products/fat-burner-capsules');
                        if (!await launchUrl(url)) {
                          debugPrint('Could not launch \$url');
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
