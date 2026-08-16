import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/router/app_router.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/services/notification_service.dart';
import 'package:pms_app/core/widgets/desktop_loading_wrapper.dart';
import 'package:pms_app/core/widgets/app_splash_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Global navigator key alias pointing to rootNavigatorKey
GlobalKey<NavigatorState> get appNavigatorKey => rootNavigatorKey;

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
    final router = ref.watch(routerProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev != null && !prev.isAuthenticated && next.isAuthenticated && !prev.isInitializing) {
        setState(() {
          _manuallyLoggedIn = true;
        });
      }
    });

    return MaterialApp.router(
      routerConfig: router,
      title: 'Needil',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'GB'),
        Locale('en', 'IN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('en', 'GB'),
      // Lock UI scale to ~85% so the app always looks like Android "Small"
      // display size, regardless of the user's system Display Size setting.
      // Layout still adapts to different screen sizes / aspect ratios.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final isMobile = mediaQuery.size.width < 900.0;
        final isDesktop = !isMobile;

        Widget content = child ?? const SizedBox.shrink();

        if (authState.isInitializing) {
          content = const AppSplashScreen(child: SizedBox.shrink());
        } else if (isDesktop && _manuallyLoggedIn) {
          content = DesktopLoadingWrapper(
            onComplete: () {
              setState(() {
                _manuallyLoggedIn = false;
              });
            },
            child: content,
          );
        }

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: isMobile
                ? const TextScaler.linear(0.85)
                : mediaQuery.textScaler,
          ),
          child: content,
        );
      },
    );
  }
}
