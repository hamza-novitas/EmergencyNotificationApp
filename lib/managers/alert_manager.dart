import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/incoming_alert.dart';
import '../services/app_lifecycle_service.dart';
import '../services/local_notification_service.dart';

class AlertManager extends ChangeNotifier {
  final List<IncomingAlert> alerts = <IncomingAlert>[];
  IncomingAlert? activeAlert;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<String> _tempFilePaths = <String>[];

  Future<void> handle(IncomingAlert alert) async {
    try {
      alerts.insert(0, alert);
      activeAlert = alert;
      notifyListeners();
      await _playBundledSound();

      if (!AppLifecycleService.isForeground) {
        await LocalNotificationService.showAlertNotification(
          title: 'Emergency Alert',
          body: alert.displayTitle,
        );
      }

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
    } catch (e) {
      // ignore: avoid_print
      print('[AlertManager] Failed to process alert: $e');
    }
  }

  Future<void> _playBundledSound() async {
    try {
      final assetPath =
          Platform.isIOS ? 'assets/audio/emergency_voice.caf' : 'assets/audio/emergency_voice.mp3';
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
