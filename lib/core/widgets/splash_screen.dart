import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NeedilSplashScreen
//
//  Premium startup animation for Needil.
//
//  The logo PNG (white rounded-square with dark-teal wordmark + needle) is
//  displayed on the dark #111216 background, matching the Needil design system.
//
//  Animation sequence (total ≈ 2.2 s):
//
//   Phase 1 — Enter (0 → 600ms)
//     • Logo scales from 0.72 → 1.0  (Curves.easeOutCubic)
//     • Logo fades  from 0.0  → 1.0  (Curves.easeOut)
//     • Tagline fades from 0 → 1 with 120ms delay
//
//   Phase 2 — Hold (600ms → 1 600ms)
//     • Everything stays at full opacity
//
//   Phase 3 — Exit (1 600ms → 2 000ms)
//     • Whole screen fades to black (Curves.easeIn)
//     • onComplete() fires → app transitions to login/home
//
//  Minimum total visible time is always ≥ 2 000ms regardless of how fast
//  the auth session restore completes.
// ─────────────────────────────────────────────────────────────────────────────

class NeedilSplashScreen extends StatefulWidget {
  /// Called when the exit animation finishes — transition to app.
  final VoidCallback onComplete;

  const NeedilSplashScreen({super.key, required this.onComplete});

  @override
  State<NeedilSplashScreen> createState() => _NeedilSplashScreenState();
}

class _NeedilSplashScreenState extends State<NeedilSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Logo enter — scale + fade
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // Tagline (sub-label) — fades in slightly after logo
  late final Animation<double> _taglineFade;

  // Exit — whole screen alpha
  late final Animation<double> _screenFade;

  // Total controller duration covers phases 1 + 2 + 3
  static const _enterMs   = 600;
  static const _holdMs    = 1000;
  static const _exitMs    = 400;
  static const _totalMs   = _enterMs + _holdMs + _exitMs; // 2000

  // Normalised interval boundaries
  static const double _enterEnd  = _enterMs / _totalMs;          // 0.30
  static const double _exitStart = (_enterMs + _holdMs) / _totalMs; // 0.80

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );

    // ── Logo enter ─────────────────────────────────────────────────
    _logoScale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(0.0, _enterEnd, curve: Curves.easeOutCubic),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(0.0, _enterEnd, curve: Curves.easeOut),
      ),
    );

    // ── Tagline — slightly delayed ──────────────────────────────────
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(0.12, _enterEnd + 0.04, curve: Curves.easeOut),
      ),
    );

    // ── Exit fade — screen goes dark ───────────────────────────────
    _screenFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(_exitStart, 1.0, curve: Curves.easeIn),
      ),
    );

    // Start and fire onComplete when fully done
    _ctrl.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _screenFade.value,
          child: Scaffold(
            backgroundColor: const Color(0xFF111216),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo ───────────────────────────────────────────
                  Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: SizedBox(
                        width: 180,
                        height: 180,
                        child: Image.asset(
                          'assets/images/needil_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Tagline ────────────────────────────────────────
                  Opacity(
                    opacity: _taglineFade.value,
                    child: const Text(
                      'Smart Clinic Management',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6E7682),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
