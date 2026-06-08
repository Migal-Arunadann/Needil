import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/theme/app_theme.dart';


class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _appVersion = '1.0.1';
  static const _buildNumber = '3';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('About', style: context.textStyles.h4),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            
            final mainBody = ListView(
              shrinkWrap: isDesktop,
              physics: isDesktop ? const NeverScrollableScrollPhysics() : null,
              padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.all(20),
              children: [
                // App logo + version hero
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: context.colors.heroGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.primary.withValues(alpha: 0.3),
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
                        'Needil',
                        style: context.textStyles.h1.copyWith(color: Colors.white, fontSize: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Advanced Clinic Management System',
                        style: context.textStyles.caption.copyWith(
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
                          'Version $_appVersion (Build $_buildNumber) • OTA Active',
                          style: context.textStyles.caption.copyWith(
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
                _sectionHeader(context, 'About Needil', Icons.info_outline_rounded),
                const SizedBox(height: 10),
                _textCard(context, 
                  'Needil is a comprehensive clinical management system designed for clinics offering session-based treatments such as physiotherapy, acupuncture, and reflexology.\n\nIt streamlines patient registration, appointment booking, consultation management, and treatment session planning — all in one place.',
                ),
                const SizedBox(height: 20),

                // Features
                _sectionHeader(context, 'Key Features', Icons.star_outline_rounded),
                const SizedBox(height: 10),
                ..._getFeatures(context).map((f) => _featureTile(context, f.$1, f.$2, f.$3)),
                const SizedBox(height: 20),

                // Build info
                _sectionHeader(context, 'Technical Information', Icons.build_outlined),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    children: [
                      _techRow(context, 'App Version', _appVersion),
                      _divider(context),
                      _techRow(context, 'Build Number', _buildNumber),
                      _divider(context),
                      _techRow(context, 'Compatibility', 'Android 6.0+ / iOS 12+'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Legal
                _sectionHeader(context, 'Legal', Icons.gavel_rounded),
                const SizedBox(height: 10),
                _legalTile(
                  context,
                  icon: Icons.description_rounded,
                  title: 'Terms of Use',
                  subtitle: 'Usage terms for clinic and doctor accounts',
                  content:
                      'By using Needil, you agree to use this software solely for legitimate medical practice management. Patient data must be handled in accordance with applicable data protection laws. Unauthorised access, data misuse, or sharing of credentials is strictly prohibited.',
                ),
                const SizedBox(height: 8),
                _legalTile(
                  context,
                  icon: Icons.privacy_tip_rounded,
                  title: 'Privacy Policy',
                  subtitle: 'How patient and clinic data is handled',
                  content:
                      'Needil stores all data on your self-hosted PocketBase server. No data is transmitted to third-party servers. Patient records, appointment history, and consultation data are encrypted at rest. You are responsible for maintaining the security of your server.',
                ),
                const SizedBox(height: 8),

                // Copy build info
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: 'Needil v$_appVersion (Build $_buildNumber)'));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Build info copied'),
                      backgroundColor: context.colors.primary,
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
                      style: context.textStyles.caption.copyWith(color: context.colors.textHint),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            );

            if (isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: mainBody,
                    ),
                  ),
                ),
              );
            } else {
              return mainBody;
            }
          },
        ),
      ),
    );
  }

  List<(IconData, Color, String)> _getFeatures(BuildContext context) => [
    (Icons.people_rounded, context.colors.primary, 'Patient Management — complete records, history, search'),
    (Icons.calendar_today_rounded, context.colors.success, 'Smart Appointment Booking — walk-in & call-by'),
    (Icons.medical_services_rounded, context.colors.accent, 'Consultation & Treatment Planning'),
    (Icons.schedule_rounded, context.colors.warning, 'Auto-Schedule Engine — conflict-free slot booking'),
    (Icons.analytics_rounded, context.colors.info, 'Dashboard Overview — real-time clinic stats'),
    (Icons.group_rounded, context.colors.error, 'Multi-Doctor Support — clinic doctor management'),
  ];

  Widget _sectionHeader(BuildContext context, String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: context.colors.primary),
          const SizedBox(width: 8),
          Text(title, style: context.textStyles.h3.copyWith(color: context.colors.primary, fontSize: 15)),
        ],
      );

  Widget _textCard(BuildContext context, String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Text(text, style: context.textStyles.bodyMedium.copyWith(height: 1.5, fontSize: 13.5)),
      );

  Widget _featureTile(BuildContext context, IconData icon, Color color, String text) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
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
            Expanded(child: Text(text, style: context.textStyles.caption.copyWith(fontSize: 12.5))),
          ],
        ),
      );

  Widget _techRow(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: context.textStyles.caption),
            ),
            Expanded(
              child: Text(
                value,
                style: context.textStyles.label.copyWith(fontSize: 13),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );

  Widget _divider(BuildContext context) => Divider(height: 1, color: context.colors.border);

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
          backgroundColor: context.colors.surface,
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
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(title, style: context.textStyles.h3),
                  const SizedBox(height: 16),
                  Text(content, style: context.textStyles.bodyMedium.copyWith(height: 1.6)),
                ],
              ),
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
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
                  color: context.colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: context.colors.primary, size: 18),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.textStyles.label.copyWith(fontSize: 14)),
                    Text(subtitle, style: context.textStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: context.colors.textHint),
            ],
          ),
        ),
      );
}
