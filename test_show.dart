import 'package:flutter_local_notifications/flutter_local_notifications.dart';
void main() {
  final p = FlutterLocalNotificationsPlugin();
  p.show(id: 1, title: 'a', body: 'b', notificationDetails: null);
}
