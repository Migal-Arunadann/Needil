import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/providers/auth_provider.dart';

class ClinicDashboardScreen extends ConsumerWidget {
  const ClinicDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final clinic = authState.clinic;

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
                          'Welcome back! 👋',
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clinic?.name ?? 'Clinic',
                          style: AppTextStyles.h2,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.business_rounded,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (clinic != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Clinic ID: ${clinic.clinicId}',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.primary, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 28),

              // Quick Stats
              Row(
                children: [
                  _statCard('Beds', '${clinic?.bedCount ?? 0}',
                      Icons.hotel_rounded, AppColors.primary),
                  const SizedBox(width: 12),
                  _statCard('Doctors', '0', Icons.person_rounded,
                      AppColors.accent),
                  const SizedBox(width: 12),
                  _statCard('Patients', '0', Icons.people_rounded,
                      AppColors.warning),
                ],
              ),
              const SizedBox(height: 28),

              // Quick Actions
              Text('Quick Actions', style: AppTextStyles.h3),
              const SizedBox(height: 14),
              _actionTile(
                icon: Icons.calendar_month_rounded,
                title: 'New Appointment',
                subtitle: 'Schedule a call-by or walk-in',
                color: AppColors.primary,
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _actionTile(
                icon: Icons.person_add_rounded,
                title: 'Add Doctor',
                subtitle: 'Share your Clinic ID with doctors',
                color: AppColors.accent,
                onTap: () {},
              ),
              const SizedBox(height: 10),
              _actionTile(
                icon: Icons.list_alt_rounded,
                title: 'View Appointments',
                subtitle: 'See all scheduled appointments',
                color: AppColors.info,
                onTap: () {},
              ),
              const SizedBox(height: 32),

              // Logout
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
