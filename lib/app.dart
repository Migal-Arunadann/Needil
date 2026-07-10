import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/router/app_router.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/features/dashboard/screens/main_layout.dart';
import 'package:pms_app/features/auth/screens/login_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_deletion_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step1_screen.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_shell.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:pms_app/core/widgets/splash_screen.dart';

/// Global navigator key so the timer service can push dialogs from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class PmsApp extends ConsumerStatefulWidget {
  const PmsApp({super.key});

  @override
  ConsumerState<PmsApp> createState() => _PmsAppState();
}

class _PmsAppState extends ConsumerState<PmsApp> {
  /// True once the startup animation has finished playing. Skips on web.
  bool _splashDone = kIsWeb;

  @override
  void initState() {
    super.initState();
    // Try to restore a previous session
    Future.microtask(
        () => ref.read(authProvider.notifier).restoreSession());
  }

  void _onSplashComplete() {
    if (mounted) setState(() => _splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    // Keep notification service alive across the entire app session
    ref.watch(notificationServiceProvider);

    final authState = ref.watch(authProvider);

    // Show splash until BOTH conditions are met:
    //  • auth has finished initializing (restoreSession complete)
    //  • the splash animation has played through
    final showSplash = authState.isInitializing || !_splashDone;

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Needil',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      // Lock UI scale to ~85% so the app always looks like Android "Small"
      // display size, regardless of the user's system Display Size setting.
      // Layout still adapts to different screen sizes / aspect ratios.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final isMobile = mediaQuery.size.width < 900.0;
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: isMobile
                ? const TextScaler.linear(0.85)
                : mediaQuery.textScaler,
          ),
          child: child!,
        );
      },
      home: showSplash
          ? NeedilSplashScreen(onComplete: _onSplashComplete)
          : authState.isAuthenticated
              ? _getHomeForAuth(authState)
              : LoginScreen(),
      onGenerateRoute: generateRoute,
    );
  }

  Widget _getHomeForAuth(AuthState state) {
    if (state.role == UserRole.superadmin) return const SuperadminShell();
    if (state.role == UserRole.clinic) {
      // Clinic pending self-deletion — full-page lockout, no sidebar/nav
      if (state.isPendingDeletion) return const ClinicDeletionScreen();
      // New clinic registration not yet complete
      if (state.clinic != null && state.clinic!.name.isEmpty) {
        return const AuthWebShell(child: ClinicStep1Screen());
      }
    }
    return MainLayout();
  }
}
