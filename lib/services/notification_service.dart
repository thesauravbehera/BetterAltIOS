import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

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

  Future<void> scheduleDailyReminders() async {
    await initialize();

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('daily_reminders_scheduled') == true) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Reminders to take your daily capsules',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Schedule Dose 1 at 10:00 AM
    await _localNotificationsPlugin.zonedSchedule(
      id: 1,
      title: 'Time for Dose 1! 💊',
      body: 'Stay consistent with your fat burner journey. Grab your first capsule now!',
      scheduledDate: _nextInstanceOfTime(10, 0),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    // Schedule Dose 2 at 6:00 PM (18:00)
    await _localNotificationsPlugin.zonedSchedule(
      id: 2,
      title: 'Time for Dose 2! 💊',
      body: 'Finish your day strong. Don\'t forget your second capsule!',
      scheduledDate: _nextInstanceOfTime(18, 0),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await prefs.setBool('daily_reminders_scheduled', true);
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
      );

      await _localNotificationsPlugin.show(
        id: 8,
        title: 'Only 2 Days Left! ⚠️',
        body: 'You\'re crushing it! Remember, after 10 days, camera verification becomes strictly required to log capsules.',
        notificationDetails: const NotificationDetails(android: androidDetails),
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
    );
    await _localNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }
}
