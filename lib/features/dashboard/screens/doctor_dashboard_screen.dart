import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/providers/auth_provider.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final doctor = authState.doctor;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good day! 👋',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctor?.name ?? 'Doctor',
                          style: AppTextStyles.h2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
              if (doctor?.clinicId != null && doctor!.clinicId!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business_rounded,
                          size: 14, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Text(
                        'Part of a clinic',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Quick Stats
              Row(
                children: [
                  _statCard("Today's", '0', Icons.calendar_today_rounded,
                      AppColors.primary),
                  const SizedBox(width: 12),
                  _statCard('Patients', '0', Icons.people_rounded,
                      AppColors.accent),
                  const SizedBox(width: 12),
                  _statCard('Plans', '0', Icons.assignment_rounded,
                      AppColors.warning),
                ],
              ),
              const SizedBox(height: 28),

              // Treatments badge
              Text('Your Treatments', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (doctor?.treatments ?? []).map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${t.type} · ${t.durationMinutes}min · ₹${t.fee.toInt()}',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: Colors.white),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),

              // Quick Actions
              Text('Quick Actions', style: AppTextStyles.h3),
              const SizedBox(height: 14),
              _actionTile(
                icon: Icons.calendar_month_rounded,
                title: 'New Appointment',
                subtitle: 'Schedule or walk-in',
                color: AppColors.primary,
                onTap: () => Navigator.pushNamed(context, '/appointments/create'),
              ),
              const SizedBox(height: 10),
              _actionTile(
                icon: Icons.person_add_rounded,
                title: 'New Consultation',
                subtitle: 'Record initial consultation',
                color: AppColors.accent,
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _actionTile(
                icon: Icons.event_available_rounded,
                title: 'Available Slots',
                subtitle: 'View your schedule & slots',
                color: AppColors.info,
                onTap: () => Navigator.pushNamed(context, '/available-slots'),
              ),
              const SizedBox(height: 10),
              _actionTile(
                icon: Icons.settings_rounded,
                title: 'Settings',
                subtitle: 'Profile, schedule, join clinic',
                color: AppColors.textSecondary,
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
              const SizedBox(height: 32),

              AppButton(
                label: 'Sign Out',
                isOutlined: true,
                icon: Icons.logout_rounded,
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: AppTextStyles.h3.copyWith(color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
