import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'device_auth_service.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _notificationId = 0;

  static final ValueNotifier<int> notificationTapCount = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (_) async {
        final authenticated = await DeviceAuthService.authenticateIfAvailable(
          reason: 'Use Face ID or passcode to open this emergency alert.',
        );

        if (authenticated) {
          notificationTapCount.value += 1;
        }
      },
    );

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
        subtitle: 'NOVITAS',
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
