import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'device_auth_service.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _notificationId = 0;

  static final ValueNotifier<int> notificationTapCount = ValueNotifier<int>(0);

  static Future<void> initialize() async {
    if (_initialized) return;

    // Android: use the white novitas icon for the notification tray.
    // The icon file must exist at android/app/src/main/res/drawable/novitas_notif_icon.png
    // (white-on-transparent, 96 × 96 px recommended).
    const androidSettings =
        AndroidInitializationSettings('@drawable/novitas_notif_icon');

    // iOS: use the default app icon; no extra setup needed here.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // requested explicitly below
      requestBadgePermission: false,
      requestSoundPermission: false,
      requestCriticalPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
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

    // Request iOS permissions (alert + badge + sound + critical).
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );

    _initialized = true;
  }

  /// Shows the pixel-perfect notification that matches the design mockup:
  ///
  ///   [NOVITAS logo]  NOVITAS                    now
  ///   Incoming Emergency Alert
  ///   Emergency System is calling you. Tap to respond.
  static Future<void> showAlertNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    // ── iOS ─────────────────────────────────────────────────────────────────
    // On iOS the system always uses the app icon as the notification icon,
    // so the Novitas logo must be set as the app icon in Xcode to match the
    // screenshot exactly.  The subtitle field maps to the small grey line
    // shown beneath the app name in the banner.
    const iosDetails = DarwinNotificationDetails(
      // subtitle appears between the app name row and the title on iOS 15+
      subtitle: 'NOVITAS',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // timeSensitive keeps the banner visible longer & bypasses Focus modes
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    // ── Android ──────────────────────────────────────────────────────────────
    // Large icon = the full-colour Novitas logo shown on the left of the
    // notification card (mirrors what iOS shows automatically via app icon).
    final androidDetails = AndroidNotificationDetails(
      'emergency_alerts_v2',
      'Emergency Alerts',
      channelDescription:
          'Emergency notifications when app is backgrounded',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // The large icon renders the colour logo on the right of the notif card.
      largeIcon: const DrawableResourceAndroidBitmap('novitas_notif_icon'),
      // styleInformation makes body text bold/multi-line like the mockup.
      styleInformation: const BigTextStyleInformation(
        'Emergency System is calling you. Tap to respond.',
        contentTitle: '<b>Incoming Emergency Alert</b>',
        htmlFormatContentTitle: true,
        summaryText: 'NOVITAS',
      ),
      color: const Color(0xFF6B3CFF), // purple accent on Android
      colorized: false,
    );

    final details = NotificationDetails(
      iOS: iosDetails,
      android: androidDetails,
    );

    _notificationId += 1;
    await _plugin.show(_notificationId, title, body, details);
  }
}