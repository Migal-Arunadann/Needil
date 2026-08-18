import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';

import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/features/settings/widgets/pending_deletion_banner.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/features/patients/providers/patient_provider.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';

/// Global key to access MainLayout state from dashboard screens.
final mainLayoutKey = GlobalKey<MainLayoutState>();

class MainLayout extends ConsumerStatefulWidget {
  final StatefulNavigationShell? navigationShell;

  MainLayout({Key? key, this.navigationShell}) : super(key: key ?? mainLayoutKey);

  @override
  ConsumerState<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends ConsumerState<MainLayout> {
  String? _highlightAppointmentId;
  static final ValueNotifier<String?> pendingHighlightAppointmentId = ValueNotifier<String?>(null);
  static final ValueNotifier<int> apptsTabActivated = ValueNotifier<int>(0);

  /// Switch to a tab programmatically (e.g., from dashboard "Upcoming Today" tap).
  /// Optionally pass an appointment ID to highlight in the appointments tab.
  void switchToTab(int index, {String? highlightAppointmentId}) {
    if (widget.navigationShell != null) {
      widget.navigationShell!.goBranch(
        index,
        initialLocation: index == widget.navigationShell!.currentIndex,
      );
    }
    if (index == 1) {
      apptsTabActivated.value++;
    }
    if (highlightAppointmentId != null) {
      _highlightAppointmentId = highlightAppointmentId;
      pendingHighlightAppointmentId.value = highlightAppointmentId;
    }
  }

  /// Called by AppointmentListScreen after it consumes the highlight ID.
  void clearHighlight() {
    _highlightAppointmentId = null;
    pendingHighlightAppointmentId.value = null;
  }

  /// Get current highlight appointment ID (consumed by appointments tab).
  String? get highlightAppointmentId => _highlightAppointmentId;

  // ── Role-based tab configuration ──

  List<_TabConfig> _getTabsForRole(UserRole? role) {
    switch (role) {
      case UserRole.clinic:
      case UserRole.doctor:
        return const [
          _TabConfig(Icons.home_rounded, 'Home', 0),
          _TabConfig(Icons.calendar_today_rounded, 'Appts', 1),
          _TabConfig(Icons.analytics_rounded, 'Analytics', 2),
          _TabConfig(Icons.people_rounded, 'Patients', 3),
          _TabConfig(Icons.person_rounded, 'Profile', 4),
        ];
      case UserRole.receptionist:
        return const [
          _TabConfig(Icons.home_rounded, 'Home', 0),
          _TabConfig(Icons.calendar_today_rounded, 'Appts', 1),
          _TabConfig(Icons.people_rounded, 'Patients', 3),
          _TabConfig(Icons.person_rounded, 'Profile', 4),
        ];
      default:
        return const [
          _TabConfig(Icons.home_rounded, 'Home', 0),
          _TabConfig(Icons.person_rounded, 'Profile', 4),
        ];
    }
  }

  void _onTabSelected(int branchIndex, String label) {
    HapticFeedback.selectionClick();
    if (widget.navigationShell != null) {
      widget.navigationShell!.goBranch(
        branchIndex,
        initialLocation: branchIndex == widget.navigationShell!.currentIndex,
      );
    }
    if (label == 'Appts' || branchIndex == 1) {
      apptsTabActivated.value++;
      ref.read(appointmentListProvider.notifier).loadAppointments();
    } else if (label == 'Patients') {
      ref.read(patientListProvider.notifier).loadPatients();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    final tabs = _getTabsForRole(role);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    // Desktop layout
    if (isDesktop) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F5D4F), // Match sidebar color behind the rounded cream card
        body: Stack(
          children: [
            const AmbientBackground(),
            LayoutBuilder(
              builder: (context, constraints) {
                final double minWidth = 1320.0;
                final double targetWidth = max(constraints.maxWidth, minWidth);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: targetWidth,
                    height: constraints.maxHeight,
                    child: Row(
                      children: [
                        _buildSidebar(context, tabs),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.colors.background,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(32),
                                bottomLeft: Radius.circular(32),
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                const PendingDeletionBanner(),
                                Expanded(
                                  child: widget.navigationShell ?? const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    // Mobile layout
    return Scaffold(
      body: Column(
        children: [
          const PendingDeletionBanner(),
          Expanded(
            child: widget.navigationShell ?? const SizedBox.shrink(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          boxShadow: [
            BoxShadow(
              color: context.colors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabs.map((tab) => _buildNavItem(tab)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, List<_TabConfig> tabs) {
    final auth = ref.watch(authProvider);
    final clinic = auth.clinic;
    final doctor = auth.doctor;
    final receptionist = auth.receptionist;

    String name = 'PMS Clinic';
    String roleStr = 'Administrator';
    String? photoUrl;
    IconData fallbackIcon = Icons.local_hospital_rounded;

    if (auth.role == UserRole.clinic) {
      name = clinic?.name ?? 'Clinic Admin';
      roleStr = 'Clinic Owner';
      photoUrl = clinic?.logoUrl;
      fallbackIcon = Icons.business_rounded;
    } else if (auth.role == UserRole.doctor) {
      name = doctor?.name ?? 'Doctor';
      roleStr = doctor?.isPrimary == true ? 'Senior Doctor' : 'Consultant Doctor';
      photoUrl = doctor?.photoUrl;
      fallbackIcon = Icons.person_rounded;
    } else if (auth.role == UserRole.receptionist) {
      name = receptionist?.name ?? 'Receptionist';
      roleStr = 'Reception Desk';
      photoUrl = receptionist?.photoUrl;
      fallbackIcon = Icons.support_agent_rounded;
    }

    return Container(
      width: 240, // Simple and trendy docked width
      clipBehavior: Clip.antiAlias, // Clean clipping for custom watermark
      decoration: const BoxDecoration(
        color: Color(0xFF0F5D4F), // Same color as new appointment button
      ),
      child: Stack(
        children: [
          // ── Transparent Custom Vector Leaves Background ──
          Positioned.fill(
            child: CustomPaint(
              painter: GenericLeavesBackgroundPainter(),
            ),
          ),
          // ── Sidebar Content ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Branding / Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 36, bottom: 20, left: 16, right: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/needil_whitebg_logo.png',
                      height: 38,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/images/needil-whitebg logo.png',
                          height: 38,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              'needil',
                              style: context.textStyles.h2.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '— CLINIC MANAGEMENT —',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),

          // ── Navigation Tabs ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isSelected = (widget.navigationShell?.currentIndex ?? 0) == tab.branchIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _SidebarNavItem(
                    icon: tab.icon,
                    label: tab.label == 'Appts' ? 'Appointments' : (tab.label == 'Profile' ? 'Profile' : tab.label),
                    isSelected: isSelected,
                    onTap: () {
                      if (isSelected) return;
                      _onTabSelected(tab.branchIndex, tab.label);
                    },
                  ),
                );
              },
            ),
          ),

          // ── User Profile Footer Card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () {
                _onTabSelected(4, 'Profile');
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        image: photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(ImageHelper.getSecureUrl(photoUrl)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: photoUrl == null
                          ? Icon(fallbackIcon, color: Colors.white, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: context.textStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            roleStr,
                            style: context.textStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Logout ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: InkWell(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: context.colors.surface,
                    title: Text('Confirm Sign Out', style: TextStyle(color: context.colors.textPrimary)),
                    content: Text('Are you sure you want to sign out from your account?', style: TextStyle(color: context.colors.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel', style: TextStyle(color: context.colors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(authProvider.notifier).logout();
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Sign Out',
                        style: context.textStyles.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(_TabConfig tab) {
    final isSelected = (widget.navigationShell?.currentIndex ?? 0) == tab.branchIndex;
    final color = isSelected ? context.colors.primary : context.colors.textHint;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isSelected) return;
        _onTabSelected(tab.branchIndex, tab.label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              tab.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hoverBgColor = Colors.white.withValues(alpha: 0.06);
    final activeBgColor = Colors.white; // Solid white active pill

    final color = widget.isSelected 
        ? const Color(0xFF0F5D4F) // Deep brand teal when selected
        : (_isHovered ? Colors.white : Colors.white.withValues(alpha: 0.65));
        
    final bgColor = widget.isSelected 
        ? activeBgColor 
        : (_isHovered ? hoverBgColor : Colors.transparent);

    Widget itemContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: widget.isSelected 
            ? Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0)
            : Border.all(color: Colors.transparent, width: 1.0),
      ),
      child: Row(
        children: [
          Icon(
            widget.icon, 
            color: color, 
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              widget.label,
              style: context.textStyles.bodyMedium.copyWith(
                color: color,
                fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          if (widget.isSelected)
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: const Color(0xFF0F5D4F), // Brand teal indicator
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );

    final translationY = _isHovered && !widget.isSelected ? -1.0 : 0.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0.0, translationY, 0.0),
          child: itemContent,
        ),
      ),
    );
  }
}

class _TabConfig {
  final IconData icon;
  final String label;
  final int branchIndex;
  const _TabConfig(this.icon, this.label, this.branchIndex);
}

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Light mode: brand green-teal, barely-visible cool orbs ──
    // ── Dark mode: deep navy with vivid blue glow orbs ──
    final baseColor = isDark
        ? const Color(0xFF0C0E15)
        : const Color(0xFF0F5D4F); // brand green-teal

    return Stack(
      children: [
        Positioned.fill(child: Container(color: baseColor)),

        // Orb 1 — top left
        Positioned(
          left: -150, top: -150, width: 650, height: 650,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  isDark
                      ? const Color(0xFF1D4ED8).withValues(alpha: 0.25)
                      : context.colors.primary.withValues(alpha: 0.04), // very subtle in light
                  baseColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Orb 2 — bottom right
        Positioned(
          right: -200, bottom: -200, width: 850, height: 850,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  isDark
                      ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                      : context.colors.accent.withValues(alpha: 0.03),
                  baseColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Orb 3 — top right
        Positioned(
          right: 50, top: -100, width: 500, height: 500,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  isDark
                      ? const Color(0xFF1D4ED8).withValues(alpha: 0.10)
                      : context.colors.primary.withValues(alpha: 0.03),
                  baseColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),

        // Orb 4 — centre ambient
        Positioned(
          left: MediaQuery.of(context).size.width * 0.3,
          top: 0, bottom: 0, width: 450,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.8,
                colors: [
                  isDark
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                      : context.colors.primary.withValues(alpha: 0.025),
                  baseColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class GenericLeavesBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04) // Very transparent white shade
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.018) // Even more subtle outline/stem
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw pinnate branch from the bottom-left edge (larger and framing)
    _drawPinnateBranch(
      canvas,
      base: Offset(-20, size.height * 1.02),
      length: size.width * 1.25,
      baseAngle: -pi / 2.7, // Sweep up along the left edge
      fillPaint: fillPaint,
      strokePaint: strokePaint,
      seed: 1.23,
    );

    // Draw pinnate branch from the right edge (larger and framing)
    _drawPinnateBranch(
      canvas,
      base: Offset(size.width + 20, size.height * 0.88),
      length: size.width * 1.15,
      baseAngle: -pi * 0.65, // Sweep up along the right edge
      fillPaint: fillPaint,
      strokePaint: strokePaint,
      seed: 4.56,
    );
  }

  void _drawPinnateBranch(
    Canvas canvas, {
    required Offset base,
    required double length,
    required double baseAngle,
    required Paint fillPaint,
    required Paint strokePaint,
    required double seed,
  }) {
    // 1. Draw central stem (rachis) using a bezier curve for a natural bend
    final stemPath = Path();
    stemPath.moveTo(base.dx, base.dy);
    
    // Calculate control point and tip point
    final tipX = base.dx + cos(baseAngle) * length;
    final bendAngle = baseAngle - 0.28 * sin(seed);
    final ctrlX = base.dx + cos(bendAngle) * length * 0.55;
    final ctrlY = base.dy + sin(bendAngle) * length * 0.55;
    final tipY = base.dy + sin(baseAngle) * length;
    final tip = Offset(tipX, tipY);

    stemPath.quadraticBezierTo(ctrlX, ctrlY, tip.dx, tip.dy);
    canvas.drawPath(stemPath, strokePaint);

    // 2. Draw leaflets with alternating offsets (sub-opposite) and angle variations
    const int leafletsCount = 9; // Spaced out for clear zigzag
    const double startRatio = 0.15;
    const double endRatio = 0.88;
    
    // Evaluate points along the quadratic bezier curve using De Casteljau's algorithm
    Offset getPointOnStem(double t) {
      final double mt = 1.0 - t;
      final double x = mt * mt * base.dx + 2.0 * mt * t * ctrlX + t * t * tip.dx;
      final double y = mt * mt * base.dy + 2.0 * mt * t * ctrlY + t * t * tip.dy;
      return Offset(x, y);
    }

    // Evaluate tangent angle along the curve to orient leaflets correctly
    double getAngleOnStem(double t) {
      final double mt = 1.0 - t;
      final double dx = 2.0 * mt * (ctrlX - base.dx) + 2.0 * t * (tip.dx - ctrlX);
      final double dy = 2.0 * mt * (ctrlY - base.dy) + 2.0 * t * (tip.dy - ctrlY);
      return atan2(dy, dx);
    }

    for (int i = 0; i < leafletsCount; i++) {
      final double t = startRatio + (endRatio - startRatio) * (i / (leafletsCount - 1));
      
      // Alternate left and right side leaflets along the stem
      final bool isLeft = i % 2 == 0;
      
      // Let's position them in a true zigzag
      final origin = getPointOnStem(t);
      final stemAngle = getAngleOnStem(t);

      // Organic leaflet size: starts large, shrinks towards the tip
      final double organicNoise = 0.95 + 0.1 * sin(i * 2.0 + seed);
      final double sizeFactor = (1.0 - t * 0.55) * (length * 0.18) * organicNoise;

      // Organic angle deviation: leaflets point slightly upwards along the stem
      final double angleNoise = 0.05 * cos(i * 1.5 + seed);
      final double leafAngle = isLeft 
          ? stemAngle - pi / 3.5 + angleNoise 
          : stemAngle + pi / 3.5 + angleNoise;

      _drawLeaflet(canvas, origin, leafAngle, sizeFactor, fillPaint, strokePaint, isLeft);
    }

    // Terminal single leaf at the absolute tip
    final terminalAngle = getAngleOnStem(endRatio);
    final terminalOrigin = getPointOnStem(endRatio);
    _drawLeaflet(canvas, terminalOrigin, terminalAngle, length * 0.08, fillPaint, strokePaint, true);
  }

  void _drawLeaflet(
    Canvas canvas,
    Offset origin,
    double angle,
    double length,
    Paint fillPaint,
    Paint strokePaint,
    bool curveLeft,
  ) {
    final path = Path();
    final tip = Offset(
      origin.dx + cos(angle) * length,
      origin.dy + sin(angle) * length,
    );

    // Bending control points with organic asymmetry
    final double leftCurvature = curveLeft ? 0.42 : 0.35;
    final double rightCurvature = curveLeft ? 0.35 : 0.42;

    final ctrlLeft = Offset(
      origin.dx + cos(angle - leftCurvature) * length * 0.55,
      origin.dy + sin(angle - leftCurvature) * length * 0.55,
    );
    final ctrlRight = Offset(
      origin.dx + cos(angle + rightCurvature) * length * 0.55,
      origin.dy + sin(angle + rightCurvature) * length * 0.55,
    );

    path.moveTo(origin.dx, origin.dy);
    path.quadraticBezierTo(ctrlLeft.dx, ctrlLeft.dy, tip.dx, tip.dy);
    path.quadraticBezierTo(ctrlRight.dx, ctrlRight.dy, origin.dx, origin.dy);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Draw slightly curved central vein
    final veinPath = Path();
    veinPath.moveTo(origin.dx, origin.dy);
    final midVein = Offset(
      origin.dx + cos(angle + (curveLeft ? -0.05 : 0.05)) * length * 0.5,
      origin.dy + sin(angle + (curveLeft ? -0.05 : 0.05)) * length * 0.5,
    );
    veinPath.quadraticBezierTo(midVein.dx, midVein.dy, tip.dx, tip.dy);
    canvas.drawPath(veinPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


