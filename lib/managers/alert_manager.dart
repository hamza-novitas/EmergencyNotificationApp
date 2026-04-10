import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/incoming_alert.dart';

class AlertManager extends ChangeNotifier {
  AlertManager() {
    _initializeNotifications();
  }

  final List<IncomingAlert> alerts = <IncomingAlert>[];
  IncomingAlert? activeAlert;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _tempFilePaths = <String>[];

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> _initializeNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> handle(IncomingAlert alert) async {
    alerts.insert(0, alert);
    activeAlert = alert;
    notifyListeners();

    await _scheduleLocalNotification(alert);
    await _playBundledSound();

    if (alert.type is AudioAlert) {
      final audioAlert = alert.type as AudioAlert;
      final bytes = base64Decode(audioAlert.base64Data);
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_${audioAlert.fileName}';

      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);
      _tempFilePaths.add(filePath);
    }
  }

  Future<void> _scheduleLocalNotification(IncomingAlert alert) async {
    final title = alert.displayTitle;
    final body = alert.type is TextAlert
        ? (alert.type as TextAlert).message
        : 'Emergency audio alert received';

    const iOSDetails = DarwinNotificationDetails(
      sound: 'emergency_voice.caf',
      presentSound: true,
      presentAlert: true,
      presentBanner: true,
      interruptionLevel: InterruptionLevel.critical,
    );

    const androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      sound: RawResourceAndroidNotificationSound('emergency_voice'),
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(iOS: iOSDetails, android: androidDetails),
    );
  }

  Future<void> _playBundledSound() async {
    try {
      final assetPath = Platform.isIOS
          ? 'assets/audio/emergency_voice.caf'
          : 'assets/audio/emergency_voice.mp3';
      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (e) {
      // ignore: avoid_print
      print('[AlertManager] Audio playback failed: $e');
    }
  }

  void dismissActiveAlert() {
    activeAlert = null;
    notifyListeners();
  }

  void stopAudio() {
    _audioPlayer.stop();
    for (final path in _tempFilePaths) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    _tempFilePaths.clear();
  }
}
