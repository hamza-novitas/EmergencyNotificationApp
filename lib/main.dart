import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'managers/alert_manager.dart';
import 'managers/signalr_manager.dart';
import 'services/permission_service.dart';
import 'ui/content_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('[FlutterError] ${details.exceptionAsString()}');
  };

  await runZonedGuarded(() async {
    await PermissionService.requestPermissions();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AlertManager()),
          ChangeNotifierProvider(create: (_) => SignalRManager()),
        ],
        child: const EmergencyApp(),
      ),
    );
  }, (error, stackTrace) {
    // ignore: avoid_print
    print('[Zone] Unhandled exception: $error');
    // ignore: avoid_print
    print(stackTrace);
  });
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
