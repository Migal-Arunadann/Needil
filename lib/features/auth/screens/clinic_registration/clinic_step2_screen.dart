import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';

/// Clinic Registration — Step 2: Number of beds.
class ClinicStep2Screen extends StatefulWidget {
  final Map<String, dynamic> clinicData;

  const ClinicStep2Screen({super.key, required this.clinicData});

  @override
  State<ClinicStep2Screen> createState() => _ClinicStep2ScreenState();
}

class _ClinicStep2ScreenState extends State<ClinicStep2Screen> {
  int _bedCount = 1;

  void _next() {
    Navigator.of(context).pushNamed(
      '/register/clinic/step3',
      arguments: {
        ...widget.clinicData,
        'bed_count': _bedCount,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Clinic Registration', style: AppTextStyles.h4),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildStepIndicator(2, 3),
              const SizedBox(height: 24),
              Text('Bed Capacity', style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                'How many beds/treatment stations does your clinic have? This determines concurrent appointment capacity.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 48),
              // Bed counter
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _counterButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (_bedCount > 1) {
                            setState(() => _bedCount--);
                          }
                        },
                        enabled: _bedCount > 1,
                      ),
                      const SizedBox(width: 32),
                      Column(
                        children: [
                          Text(
                            '$_bedCount',
                            style: AppTextStyles.h1.copyWith(
                              fontSize: 48,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            _bedCount == 1 ? 'Bed' : 'Beds',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(width: 32),
                      _counterButton(
                        icon: Icons.add_rounded,
                        onTap: () => setState(() => _bedCount++),
                        enabled: true,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              AppButton(
                  label: 'Next',
                  onPressed: _next,
                  icon: Icons.arrow_forward_rounded),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : AppColors.textHint,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final step = i + 1;
        final isActive = step <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: step < total ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
