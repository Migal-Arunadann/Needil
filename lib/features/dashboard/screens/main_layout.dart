import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import 'clinic_dashboard_screen.dart';
import 'doctor_dashboard_screen.dart';
import '../../appointments/screens/appointment_list_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../core/widgets/expandable_fab.dart';
import '../../patients/screens/patient_list_screen.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0;

  Widget _getHomeTab(UserRole? role) {
    if (role == UserRole.clinic) return const ClinicDashboardScreen();
    if (role == UserRole.doctor) return const DoctorDashboardScreen();
    return const Center(child: Text('Unknown Role'));
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;

    final List<Widget> pages = [
      _getHomeTab(role),
      const AppointmentListScreen(),
      const Scaffold(body: Center(child: Text('Analytics (Coming Soon)'))),
      const PatientListScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          IndexedStack(
            index: _currentIndex,
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
                  onCallBy: () => Navigator.pushNamed(context, '/appointments/create',
                      arguments: {'isCallBy': true}),
                  onWalkIn: () => Navigator.pushNamed(context, '/appointments/create',
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
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.calendar_today_rounded, 'Appts'),
                _buildNavItem(2, Icons.analytics_rounded, 'Analytics'),
                _buildNavItem(3, Icons.people_rounded, 'Patients'),
                _buildNavItem(4, Icons.person_rounded, 'Profile'),
              ],
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
      onTap: () => setState(() => _currentIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
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
