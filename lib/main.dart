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
  apns.onTokenRefresh.listen((token) {
    // ignore: avoid_print
    print('[APNs] Device token: $token');
    // TODO: send token to your backend
  });

  apns.onMessage.listen((message) {
    final dynamic payload = (message as dynamic).payload ?? message;
    if (payload is Map<String, dynamic>) {
      PushHandler.handle(payload, alertManager);
    } else if (payload is Map) {
      PushHandler.handle(payload.cast<String, dynamic>(), alertManager);
    }
  });

  await apns.requestNotificationPermissions(
    const IosNotificationSettings(
      sound: true,
      alert: true,
      badge: true,
      criticalAlert: true,
    ),
  );

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
