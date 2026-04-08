import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import 'clinic_dashboard_screen.dart';
import 'doctor_dashboard_screen.dart';
import 'receptionist_dashboard_screen.dart';
import '../../appointments/screens/appointment_list_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../core/widgets/expandable_fab.dart';
import '../../patients/screens/patient_list_screen.dart';
import '../../analytics/screens/analytics_screen.dart';

/// Global key to access MainLayout state from dashboard screens.
final mainLayoutKey = GlobalKey<MainLayoutState>();

class MainLayout extends ConsumerStatefulWidget {
  MainLayout({Key? key}) : super(key: key ?? mainLayoutKey);

  @override
  ConsumerState<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0;
  late PageController _pageController;
  String? _highlightAppointmentId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Switch to a tab programmatically (e.g., from dashboard "Upcoming Today" tap).
  /// Optionally pass an appointment ID to highlight in the appointments tab.
  void switchToTab(int index, {String? highlightAppointmentId}) {
    setState(() {
      _currentIndex = index;
      _highlightAppointmentId = highlightAppointmentId;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
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
          _TabConfig(Icons.home_rounded, 'Home'),
          _TabConfig(Icons.calendar_today_rounded, 'Appts'),
          _TabConfig(Icons.analytics_rounded, 'Analytics'),
          _TabConfig(Icons.people_rounded, 'Patients'),
          _TabConfig(Icons.person_rounded, 'Profile'),
        ];
      case UserRole.doctor:
        return [
          _TabConfig(Icons.home_rounded, 'Home'),
          _TabConfig(Icons.calendar_today_rounded, 'Appts'),
          _TabConfig(Icons.analytics_rounded, 'Analytics'),
          _TabConfig(Icons.people_rounded, 'Patients'),
          _TabConfig(Icons.person_rounded, 'Profile'),
        ];
      case UserRole.receptionist:
        return [
          _TabConfig(Icons.home_rounded, 'Home'),
          _TabConfig(Icons.calendar_today_rounded, 'Appts'),
          _TabConfig(Icons.people_rounded, 'Patients'),
          _TabConfig(Icons.person_rounded, 'Profile'),
        ];
      default:
        return [
          _TabConfig(Icons.home_rounded, 'Home'),
          _TabConfig(Icons.person_rounded, 'Profile'),
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

    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            children: pages,
          ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Align(
              alignment: _currentIndex == 0
                  ? Alignment.bottomCenter
                  : Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(right: _currentIndex == 0 ? 0 : 16),
                child: ExpandableFab(
                  isExtended: _currentIndex == 0,
                  onCallBy: () => Navigator.pushNamed(
                      context, '/appointments/create',
                      arguments: {'isCallBy': true}),
                  onWalkIn: () => Navigator.pushNamed(
                      context, '/appointments/create',
                      arguments: {'isCallBy': false}),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
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

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textHint;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _currentIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
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

class _TabConfig {
  final IconData icon;
  final String label;
  const _TabConfig(this.icon, this.label);
}
