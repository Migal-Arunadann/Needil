import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import 'clinic_dashboard_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'receptionist_dashboard_screen.dart';
import '../../appointments/screens/appointment_list_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../patients/screens/patient_list_screen.dart';
import '../../analytics/screens/analytics_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import '../../appointments/providers/appointment_provider.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

/// Global key to access MainLayout state from dashboard screens.
final mainLayoutKey = GlobalKey<MainLayoutState>();

class MainLayout extends ConsumerStatefulWidget {
  MainLayout({Key? key}) : super(key: key ?? mainLayoutKey);

  @override
  ConsumerState<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0;
  String? _highlightAppointmentId;

  @override
  void initState() {
    super.initState();
  }

  /// Switch to a tab programmatically (e.g., from dashboard "Upcoming Today" tap).
  /// Optionally pass an appointment ID to highlight in the appointments tab.
  void switchToTab(int index, {String? highlightAppointmentId}) {
    setState(() {
      _currentIndex = index;
      _highlightAppointmentId = highlightAppointmentId;
    });
  }

  /// Called by AppointmentListScreen after it consumes the highlight ID.
  void clearHighlight() {
    _highlightAppointmentId = null;
  }

  /// Get current highlight appointment ID (consumed by appointments tab).
  String? get highlightAppointmentId => _highlightAppointmentId;

  // ── Role-based tab configuration ──

  List<_TabConfig> _getTabsForRole(UserRole? role) {
    switch (role) {
      case UserRole.clinic:
        return [
          const _TabConfig(Icons.home_rounded, 'Home'),
          const _TabConfig(Icons.calendar_today_rounded, 'Appts'),
          const _TabConfig(Icons.analytics_rounded, 'Analytics'),
          const _TabConfig(Icons.people_rounded, 'Patients'),
          const _TabConfig(Icons.person_rounded, 'Profile'),
        ];
      case UserRole.doctor:
        return [
          const _TabConfig(Icons.home_rounded, 'Home'),
          const _TabConfig(Icons.calendar_today_rounded, 'Appts'),
          const _TabConfig(Icons.analytics_rounded, 'Analytics'),
          const _TabConfig(Icons.people_rounded, 'Patients'),
          const _TabConfig(Icons.person_rounded, 'Profile'),
        ];
      case UserRole.receptionist:
        return [
          const _TabConfig(Icons.home_rounded, 'Home'),
          const _TabConfig(Icons.calendar_today_rounded, 'Appts'),
          const _TabConfig(Icons.people_rounded, 'Patients'),
          const _TabConfig(Icons.person_rounded, 'Profile'),
        ];
      default:
        return [
          const _TabConfig(Icons.home_rounded, 'Home'),
          const _TabConfig(Icons.person_rounded, 'Profile'),
        ];
    }
  }

  List<Widget> _getPagesForRole(UserRole? role) {
    switch (role) {
      case UserRole.clinic:
        return [
          const ClinicDashboardScreen(),
          const AppointmentListScreen(),
          const AnalyticsScreen(),
          const PatientListScreen(),
          const SettingsScreen(),
        ];
      case UserRole.doctor:
        return [
          const DoctorDashboardScreen(),
          const AppointmentListScreen(),
          const AnalyticsScreen(),
          const PatientListScreen(),
          const SettingsScreen(),
        ];
      case UserRole.receptionist:
        return [
          const ReceptionistDashboardScreen(),
          const AppointmentListScreen(),
          const PatientListScreen(),
          const SettingsScreen(),
        ];
      default:
        return [
          const Center(child: Text('Unknown Role')),
          const SettingsScreen(),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    final tabs = _getTabsForRole(role);
    final pages = _getPagesForRole(role);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    if (isDesktop) {
      return Scaffold(
        body: Stack(
          children: [
            const AmbientBackground(),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24, top: 24, bottom: 24),
                  child: _buildSidebar(context, tabs),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 24, top: 24, bottom: 24),
                    child: IndexedStack(
                      index: _currentIndex,
                      children: pages,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
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
              children: List.generate(tabs.length, (index) {
                return _buildNavItem(index, tabs[index].icon, tabs[index].label);
              }),
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
      width: 232,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFAF6EE).withOpacity(0.24),
            const Color(0xFF141722).withOpacity(0.06),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Branding / Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 18, top: 36, bottom: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/neediliconforweb.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.add_rounded, color: Colors.white, size: 24);
                      },
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Needil',
                      style: context.textStyles.h2.copyWith(
                        color: const Color(0xFFFAF8F5),
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        letterSpacing: -0.8,
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
                    final isSelected = _currentIndex == index;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _SidebarNavItem(
                        icon: tab.icon,
                        label: tab.label == 'Appts' ? 'Appointments' : (tab.label == 'Profile' ? 'Profile' : tab.label),
                        isSelected: isSelected,
                        onTap: () {
                          if (_currentIndex == index) return;
                          HapticFeedback.selectionClick();
                          setState(() => _currentIndex = index);
                          final isApptsTab = tab.label == 'Appts';
                          if (isApptsTab) {
                            ref.read(appointmentListProvider.notifier).loadAppointments();
                          }
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
                    final profileIndex = tabs.indexWhere((t) => t.label == 'Profile');
                    if (profileIndex != -1) {
                      setState(() => _currentIndex = profileIndex);
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
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
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            image: photoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(ImageHelper.getSecureUrl(photoUrl)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: photoUrl == null
                              ? Icon(fallbackIcon, color: Colors.white70, size: 16)
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
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white70,
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
                        backgroundColor: const Color(0xFF1E1E2C),
                        title: const Text('Confirm Sign Out', style: TextStyle(color: Colors.white)),
                        content: const Text('Are you sure you want to sign out from your account?', style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
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
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sign Out',
                            style: context.textStyles.bodyMedium.copyWith(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? context.colors.primary : context.colors.textHint;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_currentIndex == index) return;
        HapticFeedback.selectionClick();
        setState(() => _currentIndex = index);
        // Refresh appointments when switching to the Appts tab
        final tabs = _getTabsForRole(ref.read(authProvider).role);
        final isApptsTab = index < tabs.length && tabs[index].label == 'Appts';
        if (isApptsTab) {
          ref.read(appointmentListProvider.notifier).loadAppointments();
        }
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
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
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
    final hoverBgColor = Colors.white.withOpacity(0.04);
    final activeBgColor = Colors.white.withOpacity(0.08);

    final color = widget.isSelected ? Colors.white : Colors.white.withOpacity(0.4);
    final bgColor = widget.isSelected 
        ? activeBgColor 
        : (_isHovered ? hoverBgColor : Colors.transparent);

    Widget itemContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(99),
        border: widget.isSelected 
            ? Border.all(color: Colors.white.withOpacity(0.14), width: 1.0)
            : Border.all(color: Colors.transparent, width: 1.0),
        boxShadow: widget.isSelected ? [
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 0,
          )
        ] : null,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );

    if (widget.isSelected) {
      itemContent = ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: itemContent,
        ),
      );
    }

    final translationY = _isHovered && !widget.isSelected ? -1.5 : 0.0;
    final scaleVal = _isHovered && !widget.isSelected ? 1.025 : 1.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.identity()
            ..translate(0.0, translationY)
            ..scale(scaleVal),
          child: itemContent,
        ),
      ),
    );
  }
}

class _TabConfig {
  final IconData icon;
  final String label;
  const _TabConfig(this.icon, this.label);
}

class AmbientBackground extends StatelessWidget {
  const AmbientBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base dark navy/black background
        Positioned.fill(
          child: Container(
            color: const Color(0xFF0C0E15),
          ),
        ),
        // Glow streak 1 - top left
        Positioned(
          left: -150,
          top: -150,
          width: 650,
          height: 650,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1D4ED8).withOpacity(0.25),
                  const Color(0xFF0C0E15).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Glow streak 2 - bottom right
        Positioned(
          right: -200,
          bottom: -200,
          width: 850,
          height: 850,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF2563EB).withOpacity(0.18),
                  const Color(0xFF0C0E15).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Glow streak 3 - top right secondary
        Positioned(
          right: 50,
          top: -100,
          width: 500,
          height: 500,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF1D4ED8).withOpacity(0.10),
                  const Color(0xFF0C0E15).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
        // Glow streak 4 - vertical ambient in middle
        Positioned(
          left: MediaQuery.of(context).size.width * 0.3,
          top: 0,
          bottom: 0,
          width: 450,
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.8,
                colors: [
                  const Color(0xFF3B82F6).withOpacity(0.12),
                  const Color(0xFF0C0E15).withOpacity(0.0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
