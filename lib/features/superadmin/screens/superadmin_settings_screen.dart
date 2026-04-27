import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'superadmin_shell.dart';

class SuperadminSettingsScreen extends ConsumerWidget {
  const SuperadminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SAColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: SAColors.gradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(gradient: SAColors.accentGradient, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: SAColors.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
                    child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Superadmin', style: AppTextStyles.h4.copyWith(color: SAColors.textPrimary)),
                    Text('Developer Account', style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
                  ]),
                ]),
                const SizedBox(height: 32),

                _sectionLabel('System Info'),
                _infoTile(Icons.dns_rounded, 'PocketBase Server', pbBaseUrl),
                _infoTile(Icons.security_rounded, 'Session', 'PocketBase _superusers'),
                _infoTile(Icons.verified_user_rounded, 'Access Level', 'Full Admin (All Collections)'),
                const SizedBox(height: 24),

                _sectionLabel('Access Policy'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: SAColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SAColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _policyRow(Icons.check_circle_outline_rounded, SAColors.success, 'Manage all clinic accounts'),
                      _policyRow(Icons.check_circle_outline_rounded, SAColors.success, 'Reset any user password'),
                      _policyRow(Icons.check_circle_outline_rounded, SAColors.success, 'View doctors and receptionists'),
                      _policyRow(Icons.check_circle_outline_rounded, SAColors.success, 'Verify / delete clinics'),
                      _policyRow(Icons.cancel_outlined, SAColors.error, 'Patient records (excluded)'),
                      _policyRow(Icons.cancel_outlined, SAColors.error, 'Consultation & treatment data'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Logout
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: SAColors.card,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('Logout', style: AppTextStyles.h4.copyWith(color: SAColors.textPrimary)),
                          content: Text('End your superadmin session?',
                            style: AppTextStyles.bodyMedium.copyWith(color: SAColors.textSecondary)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel', style: TextStyle(color: SAColors.textHint))),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(backgroundColor: SAColors.error, foregroundColor: Colors.white),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(authProvider.notifier).logout();
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout Superadmin'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SAColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(label,
      style: AppTextStyles.caption.copyWith(color: SAColors.textHint, letterSpacing: 1, fontSize: 11)),
  );

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: SAColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SAColors.border),
      ),
      child: Row(children: [
        Icon(icon, color: SAColors.accent, size: 18),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: SAColors.textHint)),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(color: SAColors.textPrimary, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _policyRow(IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: SAColors.textSecondary, fontSize: 13)),
      ]),
    );
  }
}
