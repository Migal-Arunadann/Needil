import 'package:flutter/material.dart';

import 'package:pms_app/features/auth/theme/needil_auth_theme.dart';

/// Responsive authentication shell.
///
/// On **desktop** (≥1000 px) it renders a two-column [Row] with 55 % brand
/// panel and 45 % form card. On **tablet** (600–999 px) only the form card is
/// shown, centred. On **mobile** (<600 px) the form card is wrapped in a
/// [SingleChildScrollView].
class AuthLayout extends StatefulWidget {
  /// The branding panel shown on the left at desktop widths.
  final Widget? brandPanel;

  /// The primary form content (right side on desktop, full screen otherwise).
  final Widget child;

  const AuthLayout({
    super.key,
    this.brandPanel,
    required this.child,
  });

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1000;
    final isTablet = width >= 600 && width < 1000;

    return Scaffold(
      backgroundColor: NeedilAuthTheme.bg(context),
      body: isDesktop
          ? _buildDesktop(context)
          : isTablet
              ? _buildTablet(context)
              : _buildMobile(context),
    );
  }

  // ── Desktop: 55 / 45 split ──────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Row(
      children: [
        // Brand panel — 55 %
        if (widget.brandPanel != null)
          Expanded(
            flex: 55,
            child: widget.brandPanel!,
          ),

        // Form card — 45 %
        Expanded(
          flex: 45,
          child: Container(
            color: NeedilAuthTheme.card(context),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 48,
                  vertical: 48,
                ),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tablet: centred card ────────────────────────────────────────────────

  Widget _buildTablet(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: NeedilAuthTheme.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: NeedilAuthTheme.border(context),
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile: scroll view ─────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
