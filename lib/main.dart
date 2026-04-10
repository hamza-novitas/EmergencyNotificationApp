import 'package:flutter/material.dart';
import 'package:flutter_apns_only/flutter_apns_only.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';

import 'managers/alert_manager.dart';
import 'managers/signalr_manager.dart';
import 'models/incoming_alert.dart';
import 'services/permission_service.dart';
import 'services/push_handler.dart';
import 'ui/content_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final alertManager = AlertManager();
  final signalRManager = SignalRManager();

  await PermissionService.requestPermissions();
  await initializeBackgroundService();
  PushHandler.initialize(alertManager);

  final apns = FlutterApnsOnly();
  await apns.requestNotificationPermissions(
    const IosNotificationSettings(
      sound: true,
      alert: true,
      badge: true,
      criticalAlert: true,
    ),
  );

  FlutterBackgroundService().on('onAlert').listen((data) {
    if (data is! Map) return;
    final type = (data['type'] as String?)?.toUpperCase();
    if (type == 'TEXT') {
      final message = data['data'] as String?;
      if (message != null) {
        alertManager.handle(IncomingAlert(type: TextAlert(message)));
      }
    } else if (type == 'AUDIO') {
      final base64 = data['data'] as String?;
      if (base64 != null) {
        alertManager.handle(
          IncomingAlert(type: AudioAlert('background_audio.wav', base64)),
        );
      }
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: alertManager),
        ChangeNotifierProvider.value(value: signalRManager),
      ],
      child: const EmergencyApp(),
    ),
  );
}

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onServiceStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'emergency_bg',
      initialNotificationTitle: 'Emergency Alert Service',
      initialNotificationContent: 'Listening for alerts',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onServiceStart,
    ),
  );
}

@pragma('vm:entry-point')
void onServiceStart(ServiceInstance service) async {
  final signalR = SignalRManager();
  signalR.onAlert = (alert) {
    service.invoke('onAlert', {
      'type': alert.type is TextAlert ? 'TEXT' : 'AUDIO',
      'data': alert.type is TextAlert
          ? (alert.type as TextAlert).message
          : (alert.type as AudioAlert).base64Data,
    });
  };
  await signalR.connect();
}

class EmergencyApp extends StatelessWidget {
  const EmergencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Alerts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const ContentView(),
    );
  }
}
