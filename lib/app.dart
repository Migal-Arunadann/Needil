import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/services/auth_service.dart';
import 'features/dashboard/screens/main_layout.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/clinic_registration/clinic_step1_screen.dart';
import 'features/superadmin/screens/superadmin_shell.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'core/services/notification_service.dart';


/// Global navigator key so the timer service can push dialogs from anywhere.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class PmsApp extends ConsumerStatefulWidget {
  const PmsApp({super.key});

  @override
  ConsumerState<PmsApp> createState() => _PmsAppState();
}

class _PmsAppState extends ConsumerState<PmsApp> {
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

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Needil',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeProvider),
      // Route based on auth state
      home: authState.isInitializing
          ? _SplashScreen()
          : authState.isAuthenticated
              ? _getHomeForAuth(authState)
              : LoginScreen(),
      onGenerateRoute: generateRoute,
    );
  }
  Widget _getHomeForAuth(AuthState state) {
    if (state.role == UserRole.superadmin) return const SuperadminShell();
    if (state.role == UserRole.clinic) {
      if (state.clinic != null && state.clinic!.name.isEmpty) {
        return const ClinicStep1Screen();
      }
    }
    return MainLayout();
  }
}

/// A splash screen shown while checking auth state.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: context.colors.heroGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.local_hospital_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(context.colors.primary),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}