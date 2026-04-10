import 'package:flutter_apns_only/flutter_apns_only.dart';

import '../managers/alert_manager.dart';
import '../models/incoming_alert.dart';

class PushHandler {
  static void initialize(AlertManager alertManager) {
    final apns = FlutterApnsOnly();

    apns.onTokenRefresh.listen((token) {
      // ignore: avoid_print
      print('[APNs] Device token: $token');
      // TODO: send token to your backend
    });

    apns.onMessage.listen((message) {
      handle(message.payload, alertManager);
    });
  }

  static void handle(Map<String, dynamic> payload, AlertManager alertManager) {
    final type = (payload['type'] as String?)?.toUpperCase();

    if (type == 'TEXT') {
      final message = payload['message'] as String;
      alertManager.handle(IncomingAlert(type: TextAlert(message)));
    } else if (type == 'AUDIO') {
      final fileName = payload['fileName'] as String;
      final base64 = payload['base64Data'] as String;
      alertManager.handle(IncomingAlert(type: AudioAlert(fileName, base64)));
    }
  }
}
