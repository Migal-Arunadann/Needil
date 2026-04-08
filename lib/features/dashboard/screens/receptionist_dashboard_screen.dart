import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../appointments/models/appointment_model.dart';
import '../../../core/utils/time_utils.dart';
import 'main_layout.dart';

class ReceptionistDashboardScreen extends ConsumerWidget {
  const ReceptionistDashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final receptionist = authState.receptionist;
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
                      child: const Icon(Icons.support_agent_rounded,
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
                            receptionist?.name ?? 'Receptionist',
                            style: AppTextStyles.h2,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.info.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Staff',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                  style:
                      AppTextStyles.caption.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 28),

                // ── Upcoming Appointment ──
                Text("Upcoming Today", style: AppTextStyles.h3),
                const SizedBox(height: 14),
                if (stats.isLoading)
                  _buildLoadingCard()
                else if (stats.nextAppointment == null)
                  _EmptyState(
                    icon: Icons.event_available_rounded,
                    message: 'No upcoming appointments',
                  )
                else
                  GestureDetector(
                    onTap: () {
                      final layout = mainLayoutKey.currentState;
                      if (layout != null) {
                        layout.switchToTab(1,
                            highlightAppointmentId:
                                stats.nextAppointment!.id);
                      }
                    },
                    child: _NextAppointmentCard(
                        appt: stats.nextAppointment!),
                  ),

                const SizedBox(height: 28),

                // ── Today's Overview ──
                Text("Today's Schedule", style: AppTextStyles.h3),
                const SizedBox(height: 14),
                if (stats.isLoading)
                  _buildLoadingCard()
                else ...[
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
                        color: AppColors.warning,
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
                Text('Overview', style: AppTextStyles.h3),
                const SizedBox(height: 14),
                if (stats.isLoading)
                  _buildLoadingCard()
                else ...[
                  _QuickStatRow(
                    icon: Icons.medical_information_rounded,
                    label: 'Consultations Today',
                    value: '${stats.consultationsToday}',
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  _QuickStatRow(
                    icon: Icons.event_repeat_rounded,
                    label: 'Sessions Today',
                    value: '${stats.sessionAppointmentsToday}',
                    color: AppColors.accent,
                  ),
                  const SizedBox(height: 10),
                  _QuickStatRow(
                    icon: Icons.people_rounded,
                    label: 'Total Patients',
                    value: '${stats.totalPatients}',
                    color: AppColors.info,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child:
            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
      ),
    );
  }
}

// ── Shared widgets (same design as clinic dashboard) ──

class _NextAppointmentCard extends StatelessWidget {
  final AppointmentModel appt;
  const _NextAppointmentCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final isSession = appt.type == AppointmentType.session;
    final isCallBy = appt.type == AppointmentType.callBy;
    final color = isSession
        ? AppColors.accent
        : (isCallBy ? AppColors.primary : AppColors.success);
    final icon = isSession
        ? Icons.event_repeat_rounded
        : (isCallBy ? Icons.phone_rounded : Icons.person_rounded);
    final typeLabel =
        isSession ? 'Session' : (isCallBy ? 'Call-By' : 'Walk-In');
    final name =
        appt.expandedPatientName ?? appt.patientName ?? 'Unknown Patient';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04)
          ],
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
                    style: AppTextStyles.label.copyWith(fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(typeLabel,
                        style: AppTextStyles.caption.copyWith(
                            color: color, fontWeight: FontWeight.w600)),
                    if (appt.doctorName != null) ...[
                      const SizedBox(width: 8),
                      Text('• Dr. ${appt.doctorName}',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textHint, fontSize: 11)),
                    ],
                  ],
                ),
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
              TimeUtils.formatStringTime(appt.time),
              style: AppTextStyles.label
                  .copyWith(color: Colors.white, fontSize: 14),
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
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
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
  const _QuickStatRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
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
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Text(value,
              style: AppTextStyles.h3
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 40, color: AppColors.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(message,
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
        ],
      ),
    );
  }
}
