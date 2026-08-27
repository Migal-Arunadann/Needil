import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/features/dashboard/providers/dashboard_provider.dart';
import 'package:pms_app/features/dashboard/widgets/dashboard_widgets.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/widgets/responsive_wrapper.dart';
import 'package:pms_app/features/dashboard/screens/main_layout.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/core/services/appointment_reconciliation_service.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/appointments/screens/auto_scheduling_dashboard.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});



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
                      style: context.textStyles.h3,
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
                    context.push(
                      '/appointments/create',
                      extra: {'isCallBy': true},
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
                    context.push(
                      '/appointments/create',
                      extra: {'isCallBy': false},
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
    final doctor = authState.doctor;
    final stats = ref.watch(dashboardStatsProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    return Scaffold(
      backgroundColor: isDesktop ? Colors.transparent : context.colors.background,
      floatingActionButton: !isDesktop
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _showNewAppointmentTypeSelector(context),
              label: const Text('New Appointment',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.2)),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              backgroundColor: context.colors.primary,
              elevation: 4,
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
              padding: EdgeInsets.fromLTRB(isDesktop ? 36 : 20, 20, isDesktop ? 36 : 20, 120),
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
                            color: context.colors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            image: doctor?.photoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(ImageHelper.getSecureUrl(doctor!.photoUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: doctor?.photoUrl == null
                              ? Icon(Icons.person_rounded, color: context.colors.primary, size: 22)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                doctor?.name ?? 'Doctor',
                                style: context.textStyles.h1.copyWith(
                                  color: context.colors.textPrimary,
                                  ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                style: context.textStyles.caption.copyWith(
                                  color: context.colors.textMuted,
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
                            color: context.colors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            image: doctor?.photoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(ImageHelper.getSecureUrl(doctor!.photoUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: doctor?.photoUrl == null
                              ? Icon(Icons.person_rounded, color: context.colors.primary, size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor?.name ?? 'Doctor',
                                style: context.textStyles.h3.copyWith(
                                  color: context.colors.textPrimary,
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
                        color: context.colors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 28),

                  if (stats.isLoading)
                    DashboardSkeletonView(isDesktop: isDesktop, showBottomCards: false)
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
                                  color: context.colors.textPrimary,
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
                                  color: context.colors.textPrimary,
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
                                    'Patients Waiting',
                                    style: context.textStyles.h2.copyWith(
                                      color: context.colors.textPrimary,
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
                              PatientsWaitingList(appointments: stats.todayAppointments),
                              const SizedBox(height: 24),
                              _DoctorConsecutiveMissesCard(),
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
                        color: context.colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DashboardOverviewSection(stats: stats),
                    const SizedBox(height: 24),
                    Text(
                      'Practice Overview',
                      style: context.textStyles.h3.copyWith(
                        color: context.colors.textPrimary,
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
                          'Patients Waiting',
                          style: context.textStyles.h3.copyWith(
                            color: context.colors.textPrimary,
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
                    PatientsWaitingList(appointments: stats.todayAppointments),
                    const SizedBox(height: 24),
                    _DoctorConsecutiveMissesCard(),
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
        cardColor: context.colors.surface,
      ),
      child: Row(
        children: [
          // Scheduling Exceptions shortcut
          Tooltip(
            message: 'Scheduling Exceptions',
            child: IconButton(
              icon: Icon(Icons.event_busy_rounded, size: 20, color: context.colors.textSecondary),
              onPressed: () => context.push('/scheduling/exceptions'),
            ),
          ),
          // Book appointment popup
          PopupMenuButton<bool>(
            tooltip: 'Book New Appointment',
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.colors.border.withValues(alpha: 0.5)),
            ),
            onSelected: (isCallBy) {
              context.push(
                '/appointments/create',
                extra: {'isCallBy': isCallBy},
              );
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.phone_in_talk_rounded, color: Colors.blueAccent, size: 16),
                    const SizedBox(width: 8),
                    Text('Call-By / Booking', style: TextStyle(color: context.colors.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.directions_walk_rounded, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 8),
                    Text('Walk-In Patient', style: TextStyle(color: context.colors.textPrimary, fontSize: 13)),
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
                      color: const Color(0xFF0F5D4F),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F5D4F).withValues(alpha: 0.25),
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
        ],
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
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF136B5C) : const Color(0xFF0F5D4F),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F5D4F).withValues(alpha: _isHovered ? 0.25 : 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
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
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Dashboard card for doctors — shows pending consecutive miss alerts.
class _DoctorConsecutiveMissesCard extends ConsumerStatefulWidget {
  const _DoctorConsecutiveMissesCard();

  @override
  ConsumerState<_DoctorConsecutiveMissesCard> createState() =>
      _DoctorConsecutiveMissesCardState();
}

class _DoctorConsecutiveMissesCardState
    extends ConsumerState<_DoctorConsecutiveMissesCard> {
  List<SessionModel>? _plans;
  List<AppointmentModel>? _consultations;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = ref.read(authProvider);
      final lifecycle = ref.read(sessionLifecycleServiceProvider);
      final reconciliation = ref.read(appointmentReconciliationServiceProvider);
      final doctorId = auth.userId ?? '';
      final sessions = await lifecycle.getOverdueSessions(doctorId);
      final consultations = await reconciliation.getOverdueConsultations(doctorId);
      if (mounted) {
        setState(() {
          _plans = sessions;
          _consultations = consultations;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; _plans = []; _consultations = []; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    final plans = _plans ?? [];
    final consultations = _consultations ?? [];
    final totalCount = plans.length + consultations.length;
    if (totalCount == 0) return const SizedBox.shrink();

    return InkWell(
      onTap: () => AutoSchedulingDashboard.show(
        context,
        overdueSessions: plans,
        overdueConsultations: consultations,
        onRefresh: _load,
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colors.error.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_active_rounded,
                color: context.colors.warning,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Needs Attention',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: context.colors.warning,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$totalCount overdue item${totalCount == 1 ? '' : 's'} need your review',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.colors.warning,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
