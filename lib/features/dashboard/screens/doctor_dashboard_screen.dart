import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../appointments/models/appointment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import 'main_layout.dart';
import 'package:pms_app/core/theme/app_theme.dart';


class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final doctor = authState.doctor;
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: context.colors.primary,
          onRefresh: () => ref.read(dashboardStatsProvider.notifier).load(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: doctor?.photoUrl == null ? context.colors.accentGradient : null,
                        color: doctor?.photoUrl != null ? context.colors.surface : null,
                        borderRadius: BorderRadius.circular(16),
                        image: doctor?.photoUrl != null
                            ? DecorationImage(
                                image: NetworkImage(doctor!.photoUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: doctor?.photoUrl == null
                          ? const Icon(Icons.person_rounded, color: Colors.white, size: 26)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()} 👋',
                            style: context.textStyles.caption.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doctor?.name ?? 'Doctor',
                            style: context.textStyles.h2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: context.textStyles.caption.copyWith(color: context.colors.textHint),
                ),
                const SizedBox(height: 20),

                // ── Today's Summary ──
                _TodaySummaryBar(stats: stats),
                const SizedBox(height: 28),

                // ── Upcoming Today (Next appointment only) ──
                Text("Upcoming Today", style: context.textStyles.h3),
                const SizedBox(height: 14),
                if (stats.isLoading)
                  _buildLoadingCard(context)
                else if (stats.nextAppointment == null)
                  _EmptyState(
                    icon: Icons.event_available_rounded,
                    message: 'No upcoming appointments scheduled',
                  )
                else
                  GestureDetector(
                    onTap: () {
                      final layout = mainLayoutKey.currentState;
                      if (layout != null) {
                        layout.switchToTab(1,
                            highlightAppointmentId: stats.nextAppointment!.id);
                      }
                    },
                    child: _NextAppointmentCard(appt: stats.nextAppointment!),
                  ),

                const SizedBox(height: 28),

                // ── Today's Overview ──
                Text("Today's Overview", style: context.textStyles.h3),
                const SizedBox(height: 14),
                if (stats.isLoading)
                  _buildLoadingCard(context)
                else ...[
                  // Row 1: Consultations + Sessions
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.medical_information_rounded,
                        label: 'Consultations',
                        value: '${stats.consultationsToday}',
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.event_repeat_rounded,
                        label: 'Sessions',
                        value: '${stats.sessionAppointmentsToday}',
                        color: context.colors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 2: Scheduled + In-Progress
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.schedule_rounded,
                        label: 'Scheduled',
                        value: '${stats.scheduledCount}',
                        color: const Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.play_circle_rounded,
                        label: 'In Progress',
                        value: '${stats.inProgressCount}',
                        color: context.colors.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Row 3: Completed + Cancelled
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.check_circle_rounded,
                        label: 'Completed',
                        value: '${stats.completedCount}',
                        color: context.colors.success,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.cancel_rounded,
                        label: 'Cancelled',
                        value: '${stats.cancelledCount}',
                        color: context.colors.error,
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 28),

                // ── Practice Overview ──
                Text('Practice Overview', style: context.textStyles.h3),
                const SizedBox(height: 14),
                if (stats.isLoading)
                  _buildLoadingCard(context)
                else ...[
                  _QuickStatRow(
                    icon: Icons.people_rounded,
                    label: 'Total Patients',
                    value: '${stats.totalPatients}',
                    color: context.colors.primary,
                  ),
                  const SizedBox(height: 10),
                  _QuickStatRow(
                    icon: Icons.medical_services_rounded,
                    label: 'Active Treatment Plans',
                    value: '${stats.activePlans}',
                    color: context.colors.accent,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Center(
        child: CircularProgressIndicator(color: context.colors.primary, strokeWidth: 3),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────

class _TodaySummaryBar extends StatelessWidget {
  final DashboardStats stats;
  const _TodaySummaryBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isLoading) {
      return Container(
        height: 76,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Center(
          child: CircularProgressIndicator(color: context.colors.primary, strokeWidth: 2.5),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colors.primary.withValues(alpha: 0.12),
            context.colors.accent.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(child: _summaryItem(
            context,
            icon: Icons.people_rounded,
            label: "Total Patients",
            value: '${stats.totalPatients}',
            color: context.colors.primary,
          )),
          _divider(context),
          Expanded(child: _summaryItem(
            context,
            icon: Icons.directions_walk_rounded,
            label: "Walk-Ins Today",
            value: '${stats.walkInsToday}',
            color: context.colors.accent,
          )),
          _divider(context),
          Expanded(child: _summaryItem(
            context,
            icon: Icons.pending_actions_rounded,
            label: "Pending",
            value: '${stats.pendingConsultations}',
            color: context.colors.warning,
          )),
        ],
      ),
    );
  }

  Widget _summaryItem(BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: context.textStyles.h3.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: context.textStyles.caption.copyWith(
            fontSize: 10,
            color: context.colors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.colors.border,
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  final AppointmentModel appt;
  const _NextAppointmentCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final isSession = appt.type == AppointmentType.session;
    final isCallBy = appt.type == AppointmentType.callBy;
    final color = isSession ? context.colors.accent : (isCallBy ? context.colors.primary : context.colors.success);
    final icon = isSession
        ? Icons.event_repeat_rounded
        : (isCallBy ? Icons.phone_rounded : Icons.person_rounded);
    final typeLabel = isSession ? 'Session' : (isCallBy ? 'Call-By Appointment' : 'Walk-In');
    final name = appt.expandedPatientName ?? appt.patientName ?? 'Unknown Patient';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: context.textStyles.label.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(typeLabel,
                    style: context.textStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              appt.time,
              style: context.textStyles.label.copyWith(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 14),
            Text(value,
                style: context.textStyles.h1
                    .copyWith(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: context.textStyles.caption.copyWith(color: context.colors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _QuickStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label, style: context.textStyles.bodyMedium),
          ),
          Text(value,
              style: context.textStyles.h3
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: context.colors.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(message,
              style: context.textStyles.caption.copyWith(color: context.colors.textHint)),
        ],
      ),
    );
  }
}
