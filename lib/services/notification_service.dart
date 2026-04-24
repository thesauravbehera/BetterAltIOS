import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // ── 3 rotating notification templates ──────────────────────────────
  static const List<Map<String, String>> _dose1Templates = [
    {
      'title': 'Capsule 1 Awaits! 🔥',
      'body': 'Your body is primed for fat burning. Grab your first capsule now!',
    },
    {
      'title': 'Keep the Streak Alive! 💪',
      'body': 'Champions don\'t skip. Time for your morning capsule — stay consistent!',
    },
    {
      'title': 'Consistency is Key! 🎯',
      'body': 'Every capsule counts toward your goal. Take Capsule 1 now!',
    },
  ];

  static const List<Map<String, String>> _dose2Templates = [
    {
      'title': 'Round Two — Let\'s Go! 🔥',
      'body': 'Double down on your progress. Time for your second capsule!',
    },
    {
      'title': 'Don\'t Break the Chain! 💪',
      'body': 'You\'re halfway through today. Take Capsule 2 to stay on track!',
    },
    {
      'title': 'Almost There! 🎯',
      'body': 'One more capsule and today is complete. Don\'t let it slip!',
    },
  ];

  static const List<Map<String, String>> _streakWarningTemplates = [
    {
      'title': '⚠️ Streak in Danger!',
      'body': 'Your time slot is ending soon! Take your capsule NOW to keep your streak alive!',
    },
    {
      'title': '🚨 Don\'t Lose Your Progress!',
      'body': 'Time is running out for today. Log your capsule before the window closes!',
    },
    {
      'title': '⏰ Last Call for Today!',
      'body': 'Your capsule window is about to close. Take action now — your streak depends on it!',
    },
  ];

  static const List<Map<String, String>> _dayEndStreakTemplates = [
    {
      'title': '🌙 Streak Loss Imminent!',
      'body': 'The day is almost over and your capsule goal isn\'t met. Log them now to save your progress!',
    },
    {
      'title': '📊 Final Streak Check',
      'body': 'Did you take both capsules today? Don\'t let a missed day break your momentum!',
    },
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    // Set timezone to IST
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotificationsPlugin.initialize(settings: initSettings);
    
    // Request permission explicitly for newer Android versions
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _isInitialized = true;
  }

  /// Returns the template index (0, 1, or 2) based on current day of year
  int _getDayRotationIndex() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return dayOfYear % 3;
  }

  /// Schedules daily dose reminders based on the user's dose_preference
  /// stored in Firestore. Called on every app launch.
  /// 
  /// dose_preference values and their notification times:
  ///   "8-12"  → Dose 1 at 8:00 AM,  Dose 2 at 12:00 PM
  ///   "12-4"  → Dose 1 at 12:00 PM, Dose 2 at 4:00 PM
  ///   "4-8"   → Dose 1 at 4:00 PM,  Dose 2 at 8:00 PM
  Future<void> scheduleDailyReminders() async {
    await initialize();

    // Cancel any previously scheduled reminders and re-schedule fresh.
    await _localNotificationsPlugin.cancel(id: 1);
    await _localNotificationsPlugin.cancel(id: 2);
    await _localNotificationsPlugin.cancel(id: 3); // streak warning at slot end
    await _localNotificationsPlugin.cancel(id: 4); // day-end streak check

    // Fetch user's dose preference from Firestore
    int dose1Hour = 9; // default fallback
    int dose1Min = 45;
    int dose2Hour = 17; // default fallback
    int dose2Min = 45;
    int slotEndHour = 20; // default fallback (8 PM)
    String preference = '';

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data() != null) {
          preference = doc.data()!['dose_preference'] ?? '';
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to fetch dose_preference: $e');
    }

    // Map dose_preference to notification hours (15 min BEFORE slot START and 15 min BEFORE slot END)
    switch (preference) {
      case '8-12':
        // Start: 8 AM -> 7:45 AM
        dose1Hour = 7; dose1Min = 45;
        // End: 12 PM -> 11:45 AM
        dose2Hour = 11; dose2Min = 45;
        slotEndHour = 12; 
        break;
      case '12-4':
        // Start: 12 PM -> 11:45 AM
        dose1Hour = 11; dose1Min = 45;
        // End: 4 PM (16:00) -> 3:45 PM (15:45)
        dose2Hour = 15; dose2Min = 45;
        slotEndHour = 16; 
        break;
      case '4-8':
        // Start: 4 PM -> 3:45 PM
        dose1Hour = 15; dose1Min = 45;
        // End: 8 PM (20:00) -> 7:45 PM (19:45)
        dose2Hour = 19; dose2Min = 45;
        slotEndHour = 20;
        break;
      default:
        dose1Hour = 7; dose1Min = 45;
        dose2Hour = 11; dose2Min = 45;
        slotEndHour = 12;
        break;
    }

    final rotationIndex = _getDayRotationIndex();
    final dose1Template = _dose1Templates[rotationIndex];
    final dose2Template = _dose2Templates[rotationIndex];
    final streakTemplate = _streakWarningTemplates[rotationIndex];
    final dayEndTemplate = _dayEndStreakTemplates[rotationIndex % 2];

    debugPrint('NotificationService: Scheduling Capsule 1 at $dose1Hour:${dose1Min.toString().padLeft(2, '0')}, Capsule 2 at $dose2Hour:${dose2Min.toString().padLeft(2, '0')}, Streak warning at $slotEndHour:00, Day-end Streak Check at 22:30 (preference: $preference)');

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Reminders to take your daily capsules',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Schedule Capsule 1 (15 min before slot start)
    await _localNotificationsPlugin.zonedSchedule(
      id: 1,
      title: dose1Template['title']!,
      body: dose1Template['body']!,
      scheduledDate: _nextInstanceOfTime(dose1Hour, dose1Min),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule Capsule 2 (15 min before slot end)
    await _localNotificationsPlugin.zonedSchedule(
      id: 2,
      title: dose2Template['title']!,
      body: dose2Template['body']!,
      scheduledDate: _nextInstanceOfTime(dose2Hour, dose2Min),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule Day-end streak loss catch-all at 10:30 PM (22:30)
    await _localNotificationsPlugin.zonedSchedule(
      id: 4,
      title: dayEndTemplate['title']!,
      body: dayEndTemplate['body']!,
      scheduledDate: _nextInstanceOfTime(22, 30),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Also store a Firestore notification record so the Notifications screen shows it
    _storeNotificationRecord(dose1Hour, dose2Hour);
  }

  /// Cancels the day-end streak loss notification (id 4).
  /// Called when the user completes both capsules for the day.
  Future<void> cancelDayEndNotification() async {
    await _localNotificationsPlugin.cancel(id: 4);
    debugPrint('NotificationService: Cancelled day-end streak notification — both capsules taken ✅');
  }



  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Stores a notification record in Firestore so it appears in the
  /// Notifications screen history.
  Future<void> _storeNotificationRecord(int dose1Hour, int dose2Hour) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final notifCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications');

      // Check if we already wrote today's scheduled notification record
      final existing = await notifCollection
          .where('type', isEqualTo: 'dose_scheduled')
          .where('dateKey', isEqualTo: todayStr)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await notifCollection.add({
          'title': 'Daily Reminders Scheduled ✅',
          'body': 'Capsule 1 at ${_formatHour(dose1Hour)} and Capsule 2 at ${_formatHour(dose2Hour)}.',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'dose_scheduled',
          'dateKey': todayStr,
        });
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to store notification record: $e');
    }
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    if (hour == 12) return '12:00 PM';
    return '${hour - 12}:00 PM';
  }

  /// Writes a notification record to Firestore so it appears in the
  /// in-app Notifications screen. De-dupes by type + dateKey.
  Future<void> _storeToFirestore({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final notifCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications');

      // De-dupe: don't write the same type twice on the same day
      final existing = await notifCollection
          .where('type', isEqualTo: type)
          .where('dateKey', isEqualTo: todayStr)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        await notifCollection.add({
          'title': title,
          'body': body,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'type': type,
          'dateKey': todayStr,
        });
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to store $type to Firestore: $e');
    }
  }

  Future<void> checkAndShowMilestoneReminders(int streakLength) async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    
    // The grace period is 10 days. 
    // If the user has 8 days of logs, they only have 2 days left.
    if (streakLength == 8) {
      if (prefs.getBool('shown_day8_reminder') == true) return;

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'milestones',
        'Milestones & Alerts',
        channelDescription: 'Important account milestone alerts',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_notification',
      );

      await _localNotificationsPlugin.show(
        id: 8,
        title: 'Only 2 Days Left! ⚠️',
        body: 'You\'re crushing it! Remember, after 10 days, camera verification becomes strictly required to log capsules.',
        notificationDetails: const NotificationDetails(android: androidDetails),
      );

      // Also store to Firestore so it appears in the in-app Notifications box
      _storeToFirestore(
        title: 'Only 2 Days Left! ⚠️',
        body: 'You\'re crushing it! Remember, after 10 days, camera verification becomes strictly required to log capsules.',
        type: 'milestone_day8',
      );

      await prefs.setBool('shown_day8_reminder', true);
    }
  }

  /// Exposed so FCM foreground messages can trigger a heads-up UI
  Future<void> showForegroundNotification(int id, String title, String body) async {
    await initialize();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'push_messages',
      'Push Messages',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    await _localNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }

  /// Sends an immediate welcome-back local notification and logs it in the in-app notifications
  Future<void> sendLoginNotification() async {
    await initialize();

    const title = 'Welcome! 👋';
    const body = 'Let\'s crush your fat burning goals today.';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'instant_alerts',
      'Alerts',
      channelDescription: 'Important immediate alerts',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'ic_notification',
    );

    // 1. Show instant phone push notification
    await _localNotificationsPlugin.show(
      id: 100, // ID 100 to avoid conflicts
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );

    // 2. Add to in-app notifications (Firestore)
    await _storeToFirestore(
      title: title,
      body: body,
      type: 'login_welcome', // De-dupes automatically by day
    );
  }
}
