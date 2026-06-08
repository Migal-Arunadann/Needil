import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_widgets.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import '../../../core/widgets/responsive_wrapper.dart';
import 'main_layout.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';

class ReceptionistDashboardScreen extends ConsumerWidget {
  const ReceptionistDashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showNewAppointmentTypeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'New Appointment',
                      style: context.textStyles.h3.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSelectorTile(
                  context: context,
                  icon: Icons.event_note_rounded,
                  color: context.colors.info,
                  title: 'Call-By Appointment',
                  subtitle: 'Schedule a pre-booked time slot via phone call',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/appointments/create',
                      arguments: {'isCallBy': true},
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildSelectorTile(
                  context: context,
                  icon: Icons.directions_walk_rounded,
                  color: context.colors.accent,
                  title: 'Walk-In Appointment',
                  subtitle: 'Register a patient waiting at the clinic',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/appointments/create',
                      arguments: {'isCallBy': false},
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectorTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.textStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.textStyles.bodySmall.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final receptionist = authState.receptionist;
    final stats = ref.watch(dashboardStatsProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    return Scaffold(
      backgroundColor: isDesktop ? Colors.transparent : const Color(0xFF0E121D), // Dark Dashboard Background
      floatingActionButton: !isDesktop
          ? FloatingActionButton.extended(
              onPressed: () => _showNewAppointmentTypeSelector(context),
              label: const Text('New Appointment',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            )
          : null,
      floatingActionButtonLocation: !isDesktop ? FloatingActionButtonLocation.centerFloat : null,
      body: SafeArea(
        child: ResponsiveWrapper(
          child: RefreshIndicator(
            color: const Color(0xFF3B82F6),
            onRefresh: () => ref.read(dashboardStatsProvider.notifier).load(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(isDesktop ? 36 : 24, 20, isDesktop ? 36 : 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Header ──
                  if (isDesktop)
                    Row(
                      children: [
                        // Left Profile Avatar
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                            image: receptionist?.photoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(ImageHelper.getSecureUrl(receptionist!.photoUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: receptionist?.photoUrl == null
                              ? const Icon(Icons.support_agent_rounded, color: Colors.white70, size: 22)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting()}, 👋',
                                style: context.textStyles.caption.copyWith(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                receptionist?.name ?? 'Receptionist',
                                style: context.textStyles.h1.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                style: context.textStyles.caption.copyWith(
                                  color: Colors.white24,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right Side Header: Search, Notifications, + New Appointment button
                        _buildHeaderActions(context, isDesktop),
                      ],
                    )
                  else ...[
                    // Mobile Header layout
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                            image: receptionist?.photoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(ImageHelper.getSecureUrl(receptionist!.photoUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: receptionist?.photoUrl == null
                              ? const Icon(Icons.support_agent_rounded, color: Colors.white70, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting()} 👋',
                                style: context.textStyles.caption.copyWith(color: Colors.white38, fontSize: 14),
                              ),
                              Text(
                                receptionist?.name ?? 'Receptionist',
                                style: context.textStyles.h3.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                      style: context.textStyles.caption.copyWith(
                        color: Colors.white30,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 28),

                  if (stats.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                      ),
                    )
                  else if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Main Pane (flex 7)
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's Overview",
                                style: context.textStyles.h2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 18),
                              DashboardOverviewSection(stats: stats),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        // Right Side Pane (flex 3)
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Practice Overview',
                                style: context.textStyles.h2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 18),
                              QuickStatRow(
                                icon: Icons.people_rounded,
                                label: 'Total Patients',
                                value: '${stats.totalPatients}',
                                color: const Color(0xFF3B82F6),
                              ),
                              const SizedBox(height: 16),
                              QuickStatRow(
                                icon: Icons.medical_services_rounded,
                                label: 'Patients under active sessions',
                                value: '${stats.patientsWithActiveSessions}',
                                color: const Color(0xFF10B981),
                              ),
                              const SizedBox(height: 36),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Today\'s Patient Stream',
                                    style: context.textStyles.h2.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      mainLayoutKey.currentState?.switchToTab(1);
                                    },
                                    child: const Text(
                                      'View all',
                                      style: TextStyle(
                                        color: Color(0xFF3B82F6),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              PatientTimelineStream(appointments: stats.todayAppointments),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    // Mobile View Stacking
                    Text(
                      "Today's Overview",
                      style: context.textStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DashboardOverviewSection(stats: stats),
                    const SizedBox(height: 24),
                    Text(
                      'Practice Overview',
                      style: context.textStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    QuickStatRow(
                      icon: Icons.people_rounded,
                      label: 'Total Patients',
                      value: '${stats.totalPatients}',
                      color: const Color(0xFF3B82F6),
                    ),
                    const SizedBox(height: 10),
                    QuickStatRow(
                      icon: Icons.medical_services_rounded,
                      label: 'Patients under active sessions',
                      value: '${stats.patientsWithActiveSessions}',
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Today\'s Patient Stream',
                          style: context.textStyles.h3.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            mainLayoutKey.currentState?.switchToTab(1);
                          },
                          child: const Text(
                            'View all',
                            style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    PatientTimelineStream(appointments: stats.todayAppointments),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderActions(BuildContext context, bool isDesktop) {
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: const Color(0xFF131924),
      ),
      child: PopupMenuButton<bool>(
        tooltip: 'Book New Appointment',
        offset: const Offset(0, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        onSelected: (isCallBy) {
          Navigator.pushNamed(
            context,
            '/appointments/create',
            arguments: {'isCallBy': isCallBy},
          );
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: true,
            child: Row(
              children: [
                Icon(Icons.phone_in_talk_rounded, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                const Text('Call-By / Booking', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem(
            value: false,
            child: Row(
              children: [
                Icon(Icons.directions_walk_rounded, color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                const Text('Walk-In Patient', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ],
        child: isDesktop 
          ? const _HeaderCTAButton()
          : Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'New Appointment',
                    style: context.textStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
      ),
    );
  }
}

class _HeaderCTAButton extends StatefulWidget {
  const _HeaderCTAButton();

  @override
  State<_HeaderCTAButton> createState() => _HeaderCTAButtonState();
}

class _HeaderCTAButtonState extends State<_HeaderCTAButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(_isHovered ? 0.35 : 0.2),
              blurRadius: _isHovered ? 20 : 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF60A5FA).withOpacity(_isHovered ? 0.4 : 0.3),
                    const Color(0xFF1D4ED8).withOpacity(0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF60A5FA).withOpacity(_isHovered ? 0.45 : 0.35),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'New Appointment',
                    style: context.textStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
