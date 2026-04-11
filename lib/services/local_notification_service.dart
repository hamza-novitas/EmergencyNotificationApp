import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _notificationId = 0;

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true, critical: true);

    _initialized = true;
  }

  static Future<void> showAlertNotification({required String title, required String body}) async {
    if (!_initialized) {
      await initialize();
    }

    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      android: AndroidNotificationDetails(
        'emergency_alerts_v2',
        'Emergency Alerts',
        channelDescription: 'Emergency notifications when app is backgrounded',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    _notificationId += 1;
    await _plugin.show(_notificationId, title, body, details);
  }
}
