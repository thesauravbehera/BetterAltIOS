import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

  /// 🔥 Register background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  /// 🔥 Initialize FCM and Notification Services
  try {
    await FirebaseMessagingService.instance.initialize();
    await NotificationService.instance.scheduleDailyReminders();
  } catch (e) {
    debugPrint("Notification init error: $e");
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

/// 🔐 AUTH GATE (Auto-login logic)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        /// 🔄 Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        /// ✅ Logged in
        if (snapshot.hasData) {
          return const MainScreen();
        }

        /// ❌ Not logged in
        return const LoginScreen();
      },
    );
  }
}