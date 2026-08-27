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
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/patients/providers/patient_provider.dart';
import 'package:pms_app/features/patients/screens/patient_profile_screen.dart';
import 'package:pms_app/core/providers/session_lifecycle_provider.dart';
import 'package:pms_app/core/services/appointment_reconciliation_service.dart';
import 'package:pms_app/features/appointments/screens/auto_scheduling_dashboard.dart';
import 'package:pms_app/features/treatments/models/session_model.dart';
import 'package:pms_app/core/services/auth_service.dart';


class ClinicDashboardScreen extends ConsumerWidget {
  const ClinicDashboardScreen({super.key});

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
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
    final clinic = authState.clinic;
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
                            shape: BoxShape.circle,
                            image: clinic?.logoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(ImageHelper.getSecureUrl(clinic!.logoUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            border: Border.all(color: context.colors.border.withValues(alpha: 0.8)),
                            color: context.colors.border.withValues(alpha: 0.3),
                          ),
                          child: clinic?.logoUrl == null
                              ? Icon(Icons.person_rounded, color: context.colors.textSecondary, size: 24)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clinic?.name ?? 'Clinic',
                                style: context.textStyles.h1.copyWith(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: context.colors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_getTimeGreeting()} · ${DateFormat('EEEE, d MMMM y').format(DateTime.now())}',
                                style: context.textStyles.caption.copyWith(
                                  color: context.colors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Right Side Header: + New Appointment
                        _buildHeaderActions(context, isDesktop),
                      ],
                    )
                  else ...[
                    // Mobile Header layout
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.colors.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: context.colors.primary.withValues(alpha: 0.15)),
                            image: clinic?.logoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(ImageHelper.getSecureUrl(clinic!.logoUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: clinic?.logoUrl == null
                              ? Icon(Icons.business_rounded, color: context.colors.primary, size: 22)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                clinic?.name ?? 'Clinic',
                                style: context.textStyles.h2.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_getTimeGreeting()} · ${DateFormat('EEEE, d MMMM').format(DateTime.now())}',
                                style: context.textStyles.caption.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 32),

                  if (stats.isLoading)
                    DashboardSkeletonView(isDesktop: isDesktop, showBottomCards: true)
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
                              const SizedBox(height: 28),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _TodayScheduleCard(
                                      appointments: stats.todayAppointments,
                                      treatmentTypes: stats.appointmentTreatmentTypes,
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _RecentPatientsCard(),
                                  ),
                                ],
                              ),
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
                                color: context.colors.primary,
                              ),
                              const SizedBox(height: 16),
                              QuickStatRow(
                                icon: Icons.medical_services_rounded,
                                label: 'Patients under active sessions',
                                value: '${stats.patientsWithActiveSessions}',
                                color: context.colors.success,
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
                                    child: Text(
                                      'View all',
                                      style: TextStyle(
                                        color: context.colors.primary,
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
                              _ConsecutiveMissesAlertCard(),
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
                      color: context.colors.primary,
                    ),
                    const SizedBox(height: 10),
                    QuickStatRow(
                      icon: Icons.medical_services_rounded,
                      label: 'Patients under active sessions',
                      value: '${stats.patientsWithActiveSessions}',
                      color: context.colors.success,
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
                          child: Text(
                            'View all',
                            style: TextStyle(
                              color: context.colors.primary,
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
                    _ConsecutiveMissesAlertCard(),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Doctor Leaves & Clinic Holidays',
            child: IconButton(
              icon: Icon(Icons.event_busy_rounded, size: 20, color: context.colors.textSecondary),
              onPressed: () => context.push('/scheduling/exceptions'),
            ),
          ),
          const SizedBox(width: 4),
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
                    Icon(Icons.phone_in_talk_rounded, color: context.colors.info, size: 16),
                    const SizedBox(width: 8),
                    Text('Call-By / Booking', style: TextStyle(color: context.colors.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.directions_walk_rounded, color: context.colors.success, size: 16),
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
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: context.colors.primary.withValues(alpha: 0.3),
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
              style: GoogleFonts.inter(
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

class _TodayScheduleCard extends StatelessWidget {
  final List<AppointmentModel> appointments;
  final Map<String, String> treatmentTypes;

  const _TodayScheduleCard({
    required this.appointments,
    this.treatmentTypes = const {},
  });

  String _formatTimeString(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final ampm = hour >= 12 ? 'PM' : 'AM';
        final formattedHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final formattedMinute = minute.toString().padLeft(2, '0');
        return '$formattedHour:$formattedMinute $ampm';
      }
    } catch (_) {}
    return timeStr;
  }

  Widget _buildStatusChip(AppointmentStatus status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case AppointmentStatus.completed:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF15803D);
        label = 'Completed';
        break;
      case AppointmentStatus.inProgress:
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'In Progress';
        break;
      case AppointmentStatus.waiting:
        bg = const Color(0xFFE0F2FE);
        text = const Color(0xFF0369A1);
        label = 'Waiting';
        break;
      case AppointmentStatus.cancelled:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFB91C1C);
        label = 'Cancelled';
        break;
      case AppointmentStatus.scheduled:
      default:
        bg = const Color(0xFFF3F4F6);
        text = const Color(0xFF4B5563);
        label = 'Scheduled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = appointments.isEmpty;
    final List<_ScheduleItem> items = [];
    if (!isEmpty) {
      // Deduplicate by patientId + time to avoid duplicate items
      final seenKeys = <String>{};
      final uniqueAppts = <AppointmentModel>[];
      for (final appt in appointments) {
        final key = '${appt.patientId ?? appt.displayName}_${appt.time}';
        if (!seenKeys.contains(key)) {
          seenKeys.add(key);
          uniqueAppts.add(appt);
        }
      }

      final sorted = List<AppointmentModel>.from(uniqueAppts)
        ..sort((a, b) => a.time.compareTo(b.time));
      for (final appt in sorted.take(4)) {
        final label = treatmentTypes[appt.id] ??
            (appt.type == AppointmentType.session
                ? (appt.sessionType == 'maintenance' ? 'Maintenance' : 'Treatment')
                : (appt.type == AppointmentType.walkIn
                    ? 'Walk-in'
                    : (appt.type == AppointmentType.callBy ? 'Call-in' : 'Consultation')));
        items.add(_ScheduleItem(
          time: _formatTimeString(appt.time),
          name: appt.displayName,
          treatment: label,
          appointmentId: appt.id,
          status: appt.status,
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Schedule",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 32,
                          color: context.colors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No appointments scheduled today',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: MouseRegion(
                        cursor: item.appointmentId != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: item.appointmentId == null
                              ? null
                              : () {
                                  mainLayoutKey.currentState?.switchToTab(1, highlightAppointmentId: item.appointmentId);
                                },
                          child: Row(
                            children: [
                              SizedBox(
                                width: 70,
                                child: Text(
                                  item.time,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: item.appointmentId != null ? const Color(0xFF0F5D4F) : context.colors.textPrimary,
                                        decoration: item.appointmentId != null ? TextDecoration.underline : null,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.treatment,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: context.colors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusChip(item.status),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                mainLayoutKey.currentState?.switchToTab(1);
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View full schedule',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F5D4F),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F5D4F), size: 14),
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

class _ScheduleItem {
  final String time;
  final String name;
  final String treatment;
  final String? appointmentId;
  final AppointmentStatus status;

  const _ScheduleItem({
    required this.time,
    required this.name,
    required this.treatment,
    this.appointmentId,
    required this.status,
  });
}

class _RecentPatientsCard extends ConsumerWidget {
  const _RecentPatientsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientState = ref.watch(patientListProvider);
    final patientsList = patientState.patients;
    final lastVisits = patientState.lastVisitDates;

    // Deduplicate by name/lowercase to avoid duplicate values
    final seenPatientKeys = <String>{};
    final uniquePatients = <PatientModel>[];
    for (final p in patientsList) {
      final key = p.fullName.trim().toLowerCase();
      if (key.isNotEmpty && !seenPatientKeys.contains(key)) {
        seenPatientKeys.add(key);
        uniquePatients.add(p);
      }
    }

    final sortedPatients = List<PatientModel>.from(uniquePatients)
      ..sort((a, b) {
        final dateA = lastVisits[a.id];
        final dateB = lastVisits[b.id];
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });

    final bool isEmpty = sortedPatients.isEmpty;
    final List<_RecentPatientItem> items = [];
    if (!isEmpty) {
      String formatLastVisit(DateTime? dt) {
        if (dt == null) return 'No visits recorded';
        final diff = DateTime.now().difference(dt).inDays;
        if (diff <= 0) return 'Last visit: Today';
        if (diff == 1) return 'Last visit: Yesterday';
        if (diff < 7) return 'Last visit: $diff days ago';
        if (diff < 30) {
          final weeks = (diff / 7).round();
          return 'Last visit: $weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
        }
        final months = (diff / 30).round();
        return 'Last visit: $months ${months == 1 ? 'month' : 'months'} ago';
      }

      for (final p in sortedPatients.take(4)) {
        items.add(_RecentPatientItem(
          name: p.fullName,
          lastVisit: formatLastVisit(lastVisits[p.id]),
          patientModel: p,
        ));
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.6),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadowColor.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Recent Patients",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 18),
          isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 32,
                          color: context.colors.textSecondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No recent patients found',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
              final item = items[index];
              final initials = item.name.split(' ').map((e) => e[0]).take(2).join().toUpperCase();

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: MouseRegion(
                  cursor: item.patientModel != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: item.patientModel == null ? null : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientProfileScreen(patient: item.patientModel!),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F5D4F).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F5D4F),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: item.patientModel != null ? const Color(0xFF0F5D4F) : context.colors.textPrimary,
                                  decoration: item.patientModel != null ? TextDecoration.underline : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.lastVisit,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: context.colors.textHint,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () {
                mainLayoutKey.currentState?.switchToTab(3);
              },
              child: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View all patients',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F5D4F),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F5D4F), size: 14),
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

class _RecentPatientItem {
  final String name;
  final String lastVisit;
  final PatientModel? patientModel;

  const _RecentPatientItem({
    required this.name,
    required this.lastVisit,
    this.patientModel,
  });
}

/// Dashboard card that shows the count of treatment plans with 3+ consecutive
/// misses. Tapping opens the Auto-Scheduling Dashboard dialog.
class _ConsecutiveMissesAlertCard extends ConsumerStatefulWidget {
  const _ConsecutiveMissesAlertCard();

  @override
  ConsumerState<_ConsecutiveMissesAlertCard> createState() =>
      _ConsecutiveMissesAlertCardState();
}

class _ConsecutiveMissesAlertCardState
    extends ConsumerState<_ConsecutiveMissesAlertCard> {
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
      final isClinic = auth.role == UserRole.clinic || auth.role == UserRole.receptionist;
      final clinicId = auth.clinicId ?? '';
      final doctorId = auth.userId ?? '';
      final sessions = isClinic
          ? await lifecycle.getOverdueSessionsForClinic(clinicId)
          : await lifecycle.getOverdueSessions(doctorId);
      final consultations = isClinic
          ? await reconciliation.getOverdueConsultations(clinicId, isClinic: true)
          : await reconciliation.getOverdueConsultations(doctorId);
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
          color: context.colors.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colors.warning.withValues(alpha: 0.35),
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
