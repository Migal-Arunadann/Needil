import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/theme/app_theme.dart';


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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: isDesktop ? Colors.white : context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: isDesktop ? const Color(0xFF161616) : context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: isDesktop ? null : Text('Clinic Registration', style: context.textStyles.h4),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildStepIndicator(2, 5),
              const SizedBox(height: 24),
              Text(
                'Bed Capacity',
                style: isDesktop
                    ? GoogleFonts.cormorantGaramond(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF161616),
                      )
                    : context.textStyles.h2,
              ),
              const SizedBox(height: 8),
              Text(
                'How many beds/treatment stations does your clinic have? This determines concurrent appointment capacity.',
                style: isDesktop
                    ? GoogleFonts.inter(
                        fontSize: 15,
                        color: const Color(0xFF6F6F6F),
                      )
                    : context.textStyles.bodyMedium
                        .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 48),
              // Bed counter
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: isDesktop ? Colors.white : context.colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDesktop ? const Color(0xFFE8E6E2) : context.colors.border),
                    boxShadow: [
                      BoxShadow(
                        color: isDesktop
                            ? const Color(0xFF0F5D4F).withValues(alpha: 0.04)
                            : context.colors.shadowColor.withValues(alpha: 0.04),
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
                            style: context.textStyles.h1.copyWith(
                              fontSize: 48,
                              color: context.colors.primary,
                            ),
                          ),
                          Text(
                            _bedCount == 1 ? 'Bed' : 'Beds',
                            style: context.textStyles.label
                                .copyWith(color: context.colors.textSecondary),
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      final primary = const Color(0xFF0F5D4F);
      return GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: enabled ? primary : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.white : const Color(0xFFCCCCCC),
            size: 24,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? context.colors.primary : context.colors.border,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : context.colors.textHint,
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
              color: isActive ? context.colors.primary : context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
