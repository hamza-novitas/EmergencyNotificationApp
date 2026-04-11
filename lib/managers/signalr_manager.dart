import 'dart:async';

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
  Timer? _reconnectTimer;
  bool _isConnecting = false;

  bool isConnected = false;
  String statusText = 'Disconnected';

  void Function(IncomingAlert alert)? onAlert;

  void configure({required AlertManager alertManager}) {
    _alertManager = alertManager;
  }

  Future<void> connect() async {
    if (_isConnecting || isConnected) {
      return;
    }
    _isConnecting = true;
    _reconnectTimer?.cancel();

    _connection = HubConnectionBuilder().withUrl(kHubUrl).withAutomaticReconnect().build();

    _registerHandlers();

    statusText = 'Connecting…';
    notifyListeners();

    try {
      await _connection!.start();
      isConnected = true;
      statusText = 'Connected';
      // ignore: avoid_print
      print('[SignalR] Connected');
    } catch (e, st) {
      isConnected = false;
      statusText = 'Disconnected';
      // ignore: avoid_print
      print('[SignalR] Connection failed: $e');
      // ignore: avoid_print
      print(st);
      _scheduleReconnect();
    }
    _isConnecting = false;
    notifyListeners();
  }

  void _registerHandlers() {
    _connection!.on('ReceiveAlert', (arguments) {
      try {
        final payload = _parsePayload(arguments);
        if (payload == null) {
          return;
        }

        final message = payload['message']?.toString();
        if (message == null || message.trim().isEmpty) {
          return;
        }

        final alert = IncomingAlert(type: TextAlert(message));
        _alertManager?.handle(alert);
        onAlert?.call(alert);
      } catch (e, st) {
        // ignore: avoid_print
        print('[SignalR] ReceiveAlert parsing failed: $e');
        // ignore: avoid_print
        print(st);
      }
    });

    _connection!.on('ReceiveAudio', (arguments) {
      try {
        final payload = _parsePayload(arguments);
        if (payload == null) {
          return;
        }

        final fileName = payload['fileName']?.toString();
        final base64 = payload['data']?.toString();

        if (fileName == null || fileName.trim().isEmpty || base64 == null || base64.trim().isEmpty) {
          return;
        }

        final alert = IncomingAlert(type: AudioAlert(fileName, base64));
        _alertManager?.handle(alert);
        onAlert?.call(alert);
      } catch (e, st) {
        // ignore: avoid_print
        print('[SignalR] ReceiveAudio parsing failed: $e');
        // ignore: avoid_print
        print(st);
      }
    });
  }

  Map<String, dynamic>? _parsePayload(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty || arguments.first == null) {
      return null;
    }

    final raw = arguments.first;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      await _connection?.stop();
    } catch (e) {
      // ignore: avoid_print
      print('[SignalR] Disconnect failed: $e');
    }
    isConnected = false;
    statusText = 'Disconnected';
    notifyListeners();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      connect();
    });
  }
}
