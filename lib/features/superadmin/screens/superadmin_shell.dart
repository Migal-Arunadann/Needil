import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_dashboard_screen.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_clinics_screen.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_settings_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';


// Shared colour palette for all superadmin screens
class SAColors {
  static const bg = Color(0xFF0A0A1A);
  static const surface = Color(0xFF13132B);
  static const card = Color(0xFF1C1C3A);
  static const accent = Color(0xFF7C6FFF);
  static const accentLight = Color(0xFFAB9FFF);
  static const accentGlow = Color(0xFF4F46E5);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textHint = Color(0xFF475569);
  static const border = Color(0xFF2D2D5E);

  static const gradient = LinearGradient(
    colors: [Color(0xFF0A0A1A), Color(0xFF13132B), Color(0xFF0F0F28)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const accentGradient = LinearGradient(
    colors: [Color(0xFF7C6FFF), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SuperadminShell extends ConsumerStatefulWidget {
  const SuperadminShell({super.key});

  @override
  ConsumerState<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends ConsumerState<SuperadminShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    SuperadminDashboardScreen(),
    SuperadminClinicsScreen(),
    SuperadminSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: SAColors.bg,
        body: Container(
          decoration: const BoxDecoration(gradient: SAColors.gradient),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 24, bottom: 24),
                child: _buildSidebar(context),
              ),
              Expanded(
                child: IndexedStack(index: _currentIndex, children: _pages),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SAColors.bg,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: SAColors.surface,
          border: const Border(top: BorderSide(color: SAColors.border, width: 0.8)),
          boxShadow: [
            BoxShadow(
              color: context.colors.shadowColor.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _navItem(0, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
                _navItem(1, Icons.business_rounded, Icons.business_outlined, 'Clinics'),
                _navItem(2, Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? SAColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? SAColors.accent : SAColors.textHint,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: isActive ? SAColors.accent : SAColors.textHint,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? SAColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? SAColors.accent.withValues(alpha: 0.3) : Colors.transparent,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: isActive ? SAColors.accent : SAColors.textSecondary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: context.textStyles.bodyMedium.copyWith(
                color: isActive ? SAColors.accent : SAColors.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: SAColors.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: SAColors.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branding Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: SAColors.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.admin_panel_settings_rounded, color: context.colors.textPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Needil',
                        style: context.textStyles.h3.copyWith(
                          color: SAColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Superadmin',
                        style: context.textStyles.caption.copyWith(
                          color: SAColors.accentLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Nav Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _sidebarNavItem(0, Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
                  const SizedBox(height: 8),
                  _sidebarNavItem(1, Icons.business_rounded, Icons.business_outlined, 'Clinics'),
                  const SizedBox(height: 8),
                  _sidebarNavItem(2, Icons.settings_rounded, Icons.settings_outlined, 'Settings'),
                ],
              ),
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(20),
            child: InkWell(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: SAColors.card,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Logout', style: context.textStyles.h4.copyWith(color: SAColors.textPrimary)),
                    content: Text('End your superadmin session?',
                      style: context.textStyles.bodyMedium.copyWith(color: SAColors.textSecondary)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false),
                        child: Text('Cancel', style: TextStyle(color: SAColors.textHint))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(backgroundColor: SAColors.error, foregroundColor: Colors.white),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/superadmin/login', (_) => false);
                    ref.read(authProvider.notifier).logout();
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: SAColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SAColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: SAColors.error, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: SAColors.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
