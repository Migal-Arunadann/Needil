import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:pms_app/app.dart';
import 'package:pms_app/core/services/session_timer_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // Disable runtime fetching to force Google Fonts to use bundled assets
  GoogleFonts.config.allowRuntimeFetching = false;
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

