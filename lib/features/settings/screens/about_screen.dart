import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appVersion = '1.0.0';
  static const _buildNumber = '1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('About', style: AppTextStyles.h4),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App logo + version hero
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 38),
                ),
                const SizedBox(height: 16),
                Text(
                  'PMS',
                  style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 28),
                ),
                const SizedBox(height: 4),
                Text(
                  'Practice Management System',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Version $_appVersion (Build $_buildNumber)',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // What is PMS
          _sectionHeader('About PMS', Icons.info_outline_rounded),
          const SizedBox(height: 10),
          _textCard(
            'PMS is a comprehensive Practice Management System designed for clinics offering session-based treatments such as physiotherapy, acupuncture, and reflexology.\n\nIt streamlines patient registration, appointment booking, consultation management, and treatment session planning — all in one place.',
          ),
          const SizedBox(height: 20),

          // Features
          _sectionHeader('Key Features', Icons.star_outline_rounded),
          const SizedBox(height: 10),
          ..._features.map((f) => _featureTile(f.$1, f.$2, f.$3)),
          const SizedBox(height: 20),

          // Build info
          _sectionHeader('Technical Information', Icons.build_outlined),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _techRow('Framework', 'Flutter'),
                _divider(),
                _techRow('Backend', 'PocketBase'),
                _divider(),
                _techRow('App Version', _appVersion),
                _divider(),
                _techRow('Build Number', _buildNumber),
                _divider(),
                _techRow('Min SDK', 'Android 6.0 / iOS 12'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Legal
          _sectionHeader('Legal', Icons.gavel_rounded),
          const SizedBox(height: 10),
          _legalTile(
            context,
            icon: Icons.description_rounded,
            title: 'Terms of Use',
            subtitle: 'Usage terms for clinic and doctor accounts',
            content:
                'By using PMS, you agree to use this software solely for legitimate medical practice management. Patient data must be handled in accordance with applicable data protection laws. Unauthorised access, data misuse, or sharing of credentials is strictly prohibited.',
          ),
          const SizedBox(height: 8),
          _legalTile(
            context,
            icon: Icons.privacy_tip_rounded,
            title: 'Privacy Policy',
            subtitle: 'How patient and clinic data is handled',
            content:
                'PMS stores all data on your self-hosted PocketBase server. No data is transmitted to third-party servers. Patient records, appointment history, and consultation data are encrypted at rest. You are responsible for maintaining the security of your server.',
          ),
          const SizedBox(height: 8),

          // Copy build info
          GestureDetector(
            onTap: () {
              Clipboard.setData(const ClipboardData(text: 'PMS v$_appVersion (Build $_buildNumber)'));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Build info copied'),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 1),
              ));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: Text(
                'Tap to copy build information',
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static const _features = [
    (Icons.people_rounded, AppColors.primary, 'Patient Management — complete records, history, search'),
    (Icons.calendar_today_rounded, AppColors.success, 'Smart Appointment Booking — walk-in & call-by'),
    (Icons.medical_services_rounded, AppColors.accent, 'Consultation & Treatment Planning'),
    (Icons.schedule_rounded, AppColors.warning, 'Auto-Schedule Engine — conflict-free slot booking'),
    (Icons.analytics_rounded, AppColors.info, 'Dashboard Overview — real-time clinic stats'),
    (Icons.group_rounded, AppColors.error, 'Multi-Doctor Support — clinic doctor management'),
  ];

  Widget _sectionHeader(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontSize: 15)),
        ],
      );

  Widget _textCard(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(text, style: AppTextStyles.bodyMedium.copyWith(height: 1.5, fontSize: 13.5)),
      );

  Widget _featureTile(IconData icon, Color color, String text) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 12.5))),
          ],
        ),
      );

  Widget _techRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: AppTextStyles.caption),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTextStyles.label.copyWith(fontSize: 13),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );

  Widget _divider() => Divider(height: 1, color: AppColors.border);

  Widget _legalTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String content,
  }) =>
      GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            maxChildSize: 0.9,
            builder: (_, sc) => Padding(
              padding: const EdgeInsets.all(24),
              child: ListView(
                controller: sc,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(title, style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  Text(content, style: AppTextStyles.bodyMedium.copyWith(height: 1.6)),
                ],
              ),
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
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
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.label.copyWith(fontSize: 14)),
                    Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
            ],
          ),
        ),
      );
}
