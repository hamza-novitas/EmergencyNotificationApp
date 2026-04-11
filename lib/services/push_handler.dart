import '../managers/alert_manager.dart';
import '../models/incoming_alert.dart';

class PushHandler {
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