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
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }
}
