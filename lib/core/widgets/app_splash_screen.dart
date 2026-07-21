import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';

class AppSplashScreen extends ConsumerStatefulWidget {
  final Widget child;
  const AppSplashScreen({super.key, required this.child});

  @override
  ConsumerState<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends ConsumerState<AppSplashScreen> {
  bool _assetsLoaded = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _preloadAssets();
  }

  Future<void> _preloadAssets() async {
    try {
      // Precache the heavy login mockup image safely after the frame
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await precacheImage(const AssetImage('assets/images/needil-loginbg.png'), context);
        } catch (e) {
          debugPrint('Error precaching image: $e');
        }
      });
      
      // Wait longer for fonts to decode into memory (1.5 seconds)
      await Future.delayed(const Duration(milliseconds: 1500));
    } catch (e) {
      debugPrint('Error precaching assets: $e');
    }
    
    if (mounted) {
      setState(() {
        _assetsLoaded = true;
      });
      // Start fade out animation
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          setState(() {
            _visible = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isReady = _assetsLoaded && !authState.isInitializing;

    return Stack(
      children: [
        // The actual app underneath
        if (isReady) widget.child,
        
        // Font warm-up (visually imperceptible) to force decoding
        if (!isReady)
          Opacity(
            opacity: 0.01,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Warmup', style: GoogleFonts.inter()),
                Text('Warmup', style: GoogleFonts.plusJakartaSans()),
                Text('Warmup', style: GoogleFonts.cormorantGaramond()),
              ],
            ),
          ),

        // Splash screen overlay
        IgnorePointer(
          ignoring: !isReady ? false : true,
          child: AnimatedOpacity(
            opacity: (!isReady || _visible) ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              color: const Color(0xFFFAF8F5), // Background color of the app
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0F5D4F), // Primary brand color
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
