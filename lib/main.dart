import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:fat_burner/core/core.dart';
import 'package:fat_burner/core/firebase_messaging_service.dart';
import 'package:fat_burner/providers/providers.dart';

// Screens
import 'package:fat_burner/screens/login_screen.dart';
import 'package:fat_burner/screens/main_screen.dart';
import 'package:fat_burner/theme/app_theme.dart';
import 'package:fat_burner/services/notification_service.dart';

import 'firebase_options.dart';

/// 🔥 REQUIRED: Background handler
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint("Background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// ✅ FIXED: Proper Firebase initialization (NO silent fail)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  /// ✅ Set custom auth domain for branded authentication
  /// This replaces fatburner---app.firebaseapp.com with auth.betteralt.in
  /// in all Firebase Auth flows (OAuth redirects, phone auth domain references)
  FirebaseAuth.instance.customAuthDomain = 'auth.betteralt.in';

  /// ✅ Firebase App Check: Debug provider for testing, Play Integrity for production
  /// Wrapped in try-catch so app doesn't hang on splash screen without internet
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    ).timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint("App Check init skipped (offline?): $e");
  }

  /// 🔥 Register background handler
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Background message handler error (non-fatal): $e");
  }

  /// 🔥 Initialize FCM and Notification Services
  try {
    await FirebaseMessagingService.instance.initialize()
        .timeout(const Duration(seconds: 5));
    await NotificationService.instance.scheduleDailyReminders()
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint("Notification init error (non-fatal): $e");
  }

  /// ✅ Disable APNs verification in debug mode so Firebase test phone numbers work on iOS
  try {
    await FirebaseAuth.instance.setSettings(
      appVerificationDisabledForTesting: kDebugMode,
    );
  } catch (e) {
    debugPrint("Auth settings error (non-fatal): $e");
  }

  runApp(const FatBurnerApp());
}

class FatBurnerApp extends StatelessWidget {
  const FatBurnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: PurchaseStatusProvider.instance,
        ),
      ],
      child: MaterialApp.router(
        title: 'BetterAlt',
        debugShowCheckedModeBanner: false,

        /// 🎨 Theme (Light + Dark supported)
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),

        /// ✅ FIXED: Uses system theme (auto switch)
        themeMode: ThemeMode.system,

        /// 🔐 Routing
        routerConfig: AppRouter.router,
      ),
    );
  }
}
