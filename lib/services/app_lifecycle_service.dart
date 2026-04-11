import 'package:flutter/widgets.dart';

class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService._();

  static final AppLifecycleService instance = AppLifecycleService._();
  static bool isForeground = true;
  bool _attached = false;

  void attach() {
    if (_attached) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isForeground = state == AppLifecycleState.resumed;
  }
}
