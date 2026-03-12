import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../appointments/models/appointment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class ClinicDashboardScreen extends ConsumerWidget {
  const ClinicDashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final clinic = authState.clinic;
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
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
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.business_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_greeting()} 👋',
                            style: AppTextStyles.caption.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            clinic?.name ?? 'Clinic',
                            style: AppTextStyles.h2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 28),

                // ── Today's Overview ──
                Text("Today's Overview", style: AppTextStyles.h3),
                const SizedBox(height: 14),
                if (stats.isLoading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 3),
                  ))
                else ...[
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.calendar_today_rounded,
                        label: 'Appointments',
                        value: '${stats.todayAppointments}',
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.schedule_rounded,
                        label: 'Scheduled',
                        value: '${stats.scheduledCount}',
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.check_circle_rounded,
                        label: 'Completed',
                        value: '${stats.completedCount}',
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        icon: Icons.cancel_rounded,
                        label: 'Cancelled',
                        value: '${stats.cancelledCount}',
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 28),

                // ── Quick Stats ──
                Text('Practice Overview', style: AppTextStyles.h3),
                const SizedBox(height: 14),
                _QuickStatRow(
                  icon: Icons.people_rounded,
                  label: 'Total Patients',
                  value: '${stats.totalPatients}',
                  color: AppColors.primary,
                ),
                const SizedBox(height: 10),
                _QuickStatRow(
                  icon: Icons.medical_services_rounded,
                  label: 'Active Treatment Plans',
                  value: '${stats.activePlans}',
                  color: AppColors.accent,
                ),
                const SizedBox(height: 10),
                _QuickStatRow(
                  icon: Icons.event_repeat_rounded,
                  label: 'Upcoming Sessions',
                  value: '${stats.upcomingSessions}',
                  color: AppColors.warning,
                ),
                const SizedBox(height: 28),

                // ── Upcoming Appointments ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Upcoming Today', style: AppTextStyles.h3),
                    GestureDetector(
                      onTap: () {},
                      child: Text('View All',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: AppColors.primary)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (stats.upcomingAppointments.isEmpty)
                  _EmptyState(
                    icon: Icons.event_available_rounded,
                    message: 'No upcoming appointments today',
                  )
                else
                  ...stats.upcomingAppointments.map(
                    (appt) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AppointmentPreviewCard(
                        name: appt.patientName ?? 'Unknown Patient',
                        time: appt.time,
                        type: appt.type,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────

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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
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
                style: AppTextStyles.h1
                    .copyWith(fontSize: 28, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textHint)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
            child: Text(label, style: AppTextStyles.bodyMedium),
          ),
          Text(value,
              style: AppTextStyles.h3
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 18)),
        ],
      ),
    );
  }
}

class _AppointmentPreviewCard extends StatelessWidget {
  final String name;
  final String time;
  final AppointmentType type;

  const _AppointmentPreviewCard({
    required this.name,
    required this.time,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final isCallBy = type == AppointmentType.callBy;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCallBy ? AppColors.accent : AppColors.primary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCallBy ? Icons.phone_rounded : Icons.person_rounded,
              color: isCallBy ? AppColors.accent : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.label.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  isCallBy ? 'Call-By Appointment' : 'Walk-In',
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(time,
                style: AppTextStyles.label
                    .copyWith(color: AppColors.primary, fontSize: 13)),
          ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(message,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}
