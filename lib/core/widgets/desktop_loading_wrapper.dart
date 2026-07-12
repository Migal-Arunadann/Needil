import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';

class DesktopLoadingWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback onComplete;

  const DesktopLoadingWrapper({
    super.key,
    required this.child,
    required this.onComplete,
  });

  @override
  ConsumerState<DesktopLoadingWrapper> createState() => _DesktopLoadingWrapperState();
}

class _DesktopLoadingWrapperState extends ConsumerState<DesktopLoadingWrapper> {
  bool _showingChild = false;
  double _progress = 0.0;
  String _statusText = 'Preparing clinical workspace...';
  Timer? _progressTimer;
  Timer? _statusTimer;
  bool _backendLoaded = false;

  final List<String> _statusSequence = [
    'Preparing clinical workspace...',
    'Establishing secure medical connection...',
    'Syncing appointment schedule...',
    'Loading clinical dashboard...',
    'Optimizing health records...',
    'Ready.',
  ];
  int _statusIndex = 0;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    // Smooth status text transitions
    _statusTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) return;
      if (_statusIndex < _statusSequence.length - 1) {
        setState(() {
          _statusIndex++;
          _statusText = _statusSequence[_statusIndex];
        });
      } else {
        _statusTimer?.cancel();
      }
    });

    // Smooth progress bar update
    _progressTimer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) return;
      setState(() {
        if (!_backendLoaded) {
          // Slowly fill up to 85% while query runs
          if (_progress < 0.85) {
            _progress += 0.008;
          }
        } else {
          // Once loaded, surge to 100%
          if (_progress < 1.0) {
            _progress += 0.04;
          } else {
            _progress = 1.0;
            _progressTimer?.cancel();
            _completeLoading();
          }
        }
      });
    });
  }

  void _completeLoading() {
    if (mounted) {
      setState(() {
        _statusText = _statusSequence.last; // 'Ready.'
      });
    }

    // Small delay to let the user see the complete state before fading in
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _showingChild = true;
        });
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showingChild) {
      return widget.child;
    }

    final role = ref.watch(authProvider).role;
    if (role == UserRole.superadmin) {
      _backendLoaded = true;
    } else {
      final stats = ref.watch(dashboardStatsProvider);
      if (!stats.isLoading) {
        _backendLoaded = true;
      }
    }

    final primary = const Color(0xFF0F5D4F); // Needil brand primary teal
    final bgWarm = const Color(0xFFFAF8F5);  // Warm cream page bg
    final textSecondary = const Color(0xFF6F6F6F); // Subtle text

    return Scaffold(
      backgroundColor: bgWarm,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEFECE4)), // Soft warm border
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F5D4F).withOpacity(0.03),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Needil Brand Logo ──
              Image.asset(
                'assets/images/needil_logo_cropped.png',
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Text(
                    'needil',
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: primary,
                      letterSpacing: -0.5,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'CLINIC MANAGEMENT SYSTEM',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 40),

              // ── Simple & Elegant Loading Bar ──
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 4,
                  width: 280,
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: const Color(0xFFEFECE4),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Status Text ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _statusText,
                  key: ValueKey<String>(_statusText),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
