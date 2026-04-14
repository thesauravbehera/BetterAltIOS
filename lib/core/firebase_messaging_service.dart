import 'dart:io';

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
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'fcmToken': token,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
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
