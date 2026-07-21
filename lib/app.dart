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
import 'package:pms_app/core/widgets/desktop_loading_wrapper.dart';
import 'package:pms_app/core/widgets/app_splash_screen.dart';

/// Global navigator key so the timer service can push dialogs from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class PmsApp extends ConsumerStatefulWidget {
  const PmsApp({super.key});

  @override
  ConsumerState<PmsApp> createState() => _PmsAppState();
}

class _PmsAppState extends ConsumerState<PmsApp> {
  bool _manuallyLoggedIn = false;

  @override
  void initState() {
    super.initState();
    // Try to restore a previous session
    Future.microtask(
        () => ref.read(authProvider.notifier).restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    // Keep notification service alive across the entire app session
    ref.watch(notificationServiceProvider);

    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev != null && !prev.isAuthenticated && next.isAuthenticated && !prev.isInitializing) {
        setState(() {
          _manuallyLoggedIn = true;
        });
      }
    });

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
      home: AppSplashScreen(
        child: authState.isAuthenticated
            ? Builder(
                builder: (context) {
                  final isDesktop = MediaQuery.of(context).size.width >= 900.0;
                  if (isDesktop && _manuallyLoggedIn) {
                    return DesktopLoadingWrapper(
                      child: _getHomeForAuth(authState),
                      onComplete: () {
                        setState(() {
                          _manuallyLoggedIn = false;
                        });
                      },
                    );
                  }
                  return _getHomeForAuth(authState);
                },
              )
            : LoginScreen(),
      ),
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
