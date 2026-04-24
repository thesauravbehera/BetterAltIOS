import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fat_burner/firebase_options.dart';
import 'package:fat_burner/services/notification_service.dart';

/// Handles FCM setup: permissions, token, foreground/background message handlers.
/// Call [initialize] from main.dart after Firebase.initializeApp().
class FirebaseMessagingService {
  FirebaseMessagingService._();
  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize FCM: request permissions, set handlers, get token.
  Future<void> initialize() async {
    await _requestPermission();

    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // User taps notification when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Get FCM token (e.g. to store on your backend)
    await _updateFcmToken();
    _messaging.onTokenRefresh.listen((_) => _updateFcmToken());

    // Also re-save token whenever the user logs in (fixes cold-start issue
    // where the user isn't authenticated yet when the app first launches)
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _updateFcmToken();
      }
    });
  }

  Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    // settings: authorized, denied, notDetermined, provisional
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.notification != null) {
      NotificationService.instance.showForegroundNotification(
        message.hashCode,
        message.notification!.title ?? 'New Message',
        message.notification!.body ?? '',
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Navigate based on message.data, e.g. message.data['route']
  }

  Future<void> _updateFcmToken() async {
    String? token;
    if (Platform.isIOS) {
      // On iOS, APNs token must be available first
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken != null) {
        token = await _messaging.getToken();
      }
    } else {
      token = await _messaging.getToken();
    }
    if (token != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('FCM: Saving token for user ${user.uid}');
        try {
          final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
          await userRef.set({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // Write a welcome notification if this is the first time
          await _writeWelcomeNotificationIfNeeded(user.uid);
        } catch (e) {
          debugPrint('FCM: Failed to save token: $e');
        }
      }
    }
  }

  /// Writes a one-time welcome notification to Firestore so the
  /// Notifications screen is never empty on first login.
  /// Skips for returning users (who already have daily_logs).
  Future<void> _writeWelcomeNotificationIfNeeded(String uid) async {
    try {
      final notifCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

      // Check if a welcome notification already exists to prevent spamming on every app load
      final existing = await notifCollection.where('type', isEqualTo: 'welcome').limit(1).get();
      if (existing.docs.isNotEmpty) {
        return; // We already sent a welcome notification to this user
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final isReturningUser = userDoc.exists && 
          userDoc.data()?['onboardingCompleted'] == true &&
          userDoc.data()?['created_at'] != null;

      if (isReturningUser) {
        debugPrint('FCM: Returning user detected, sending welcome back notification');
        const title = 'Welcome Back! 💪';
        const body = 'Great to see you again! Continue your fat-burning journey right where you left off.';
        
        await notifCollection.add({
          'title': title,
          'body': body,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'welcome',
        });

        NotificationService.instance.showForegroundNotification(uid.hashCode, title, body);
        return;
      }

      const title = 'Welcome to BetterAlt! 🎉';
      const body = 'Your Fat Burner journey starts now. Take your first capsule to begin your streak!';

      await notifCollection.add({
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'type': 'welcome',
      });
      
      NotificationService.instance.showForegroundNotification(uid.hashCode, title, body);
      debugPrint('FCM: Welcome notification written and pushed');
    } catch (e) {
      debugPrint('FCM: Failed to write welcome notification: $e');
    }
  }
}

/// Background message handler - must be top-level function.
/// Called when a message is received while app is terminated or in background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Handle background/terminated message (e.g. update local DB)
}
