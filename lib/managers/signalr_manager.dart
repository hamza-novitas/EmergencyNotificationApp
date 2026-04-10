import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';

import '../models/incoming_alert.dart';
import 'alert_manager.dart';

const String kServerUrl = 'http://209.209.42.126:8019';
const String kHubUrl = '$kServerUrl/alertHub';

class SignalRManager extends ChangeNotifier {
  HubConnection? _connection;
  AlertManager? _alertManager;

  bool isConnected = false;
  String statusText = 'Disconnected';

  void Function(IncomingAlert alert)? onAlert;

  void configure({required AlertManager alertManager}) {
    _alertManager = alertManager;
  }

  Future<void> connect() async {
    _connection = HubConnectionBuilder()
        .withUrl(kHubUrl)
        .withAutomaticReconnect()
        .build();

    _registerHandlers();

    statusText = 'Connecting…';
    notifyListeners();

    try {
      await _connection!.start();
      isConnected = true;
      statusText = 'Connected';
      // ignore: avoid_print
      print('[SignalR] Connected');
    } catch (e) {
      isConnected = false;
      statusText = 'Disconnected';
      // ignore: avoid_print
      print('[SignalR] Connection failed: $e');
    }
    notifyListeners();
  }

  void _registerHandlers() {
    _connection!.on('ReceiveAlert', (arguments) {
      final payload = arguments![0] as Map<String, dynamic>;
      final message = payload['message'] as String;
      final alert = IncomingAlert(type: TextAlert(message));
      _alertManager?.handle(alert);
      onAlert?.call(alert);
    });

    _connection!.on('ReceiveAudio', (arguments) {
      final payload = arguments![0] as Map<String, dynamic>;
      final fileName = payload['fileName'] as String;
      final base64 = payload['data'] as String;
      final alert = IncomingAlert(type: AudioAlert(fileName, base64));
      _alertManager?.handle(alert);
      onAlert?.call(alert);
    });
  }

  void disconnect() {
    _connection?.stop();
    isConnected = false;
    statusText = 'Disconnected';
    notifyListeners();
  }
}
