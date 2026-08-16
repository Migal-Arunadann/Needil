import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pms_app/app.dart';
import 'package:pms_app/core/services/session_timer_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // Clean web URLs: /appointments instead of /#/appointments
  tz.initializeTimeZones();

  // Allow runtime fetching fallback for unbundled font variants
  GoogleFonts.config.allowRuntimeFetching = true;
  await GoogleFonts.pendingFonts();

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

