import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_colors.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/services/auth_service.dart';
import 'features/dashboard/screens/main_layout.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/clinic_registration/clinic_step1_screen.dart';
import 'features/superadmin/screens/superadmin_shell.dart';

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
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Needil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
      ),
      // Route based on auth state
      home: authState.isInitializing
          ? const _SplashScreen()
          : authState.isAuthenticated
              ? _getHomeForAuth(authState)
              : const LoginScreen(),
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
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
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
            const CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
