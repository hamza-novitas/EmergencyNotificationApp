import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/incoming_alert.dart';
import '../services/app_lifecycle_service.dart';
import '../services/audio_service.dart';
import '../services/local_notification_service.dart';

class AlertManager extends ChangeNotifier {
  final List<IncomingAlert> alerts = <IncomingAlert>[];
  IncomingAlert? activeAlert;

  Future<void> handle(IncomingAlert alert) async {
    try {
      alerts.insert(0, alert);
      activeAlert = alert;
      notifyListeners();

      if (AppLifecycleService.isForeground) {
        // App is visible → play sound immediately, overlay will show
        await AudioService.instance.playLoop();
        await SystemSound.play(SystemSoundType.alert);
      } else {
        // App is backgrounded → show notification banner;
        // audio starts when user opens the app and the overlay appears.
        await LocalNotificationService.showAlertNotification(
          title: 'Incoming Emergency Alert',
          body: 'Emergency System is calling you. Tap to respond.',
        );
      }
    } catch (e) {
      debugPrint('[AlertManager] handle failed: $e');
    }
  }

  void dismissActiveAlert() {
    activeAlert = null;
    notifyListeners();
  }

  /// Called by the overlay when it is done (user responded or auto-dismissed).
  Future<void> stopAndDismiss() async {
    await AudioService.instance.stop();
    dismissActiveAlert();
  }
}