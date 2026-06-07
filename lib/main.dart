import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';
import 'core/services/session_timer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Restrict app orientation to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize flutter_local_notifications
  const initAndroid = AndroidInitializationSettings('@mipmap/launcher_icon');
  const initSettings = InitializationSettings(android: initAndroid);
  await SessionTimerService.instance.initNotifications(initSettings);

  runApp(
    const ProviderScope(
      child: PmsApp(),
    ),
  );
}

