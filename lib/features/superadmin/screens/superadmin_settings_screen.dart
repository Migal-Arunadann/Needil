import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/services/superadmin_service.dart';
import 'package:pms_app/core/utils/error_formatter.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/superadmin/screens/superadmin_shell.dart';
import 'package:pms_app/core/theme/app_theme.dart';

final _systemSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final pb = ref.read(pocketbaseProvider);
  return SuperadminService(pb).getSystemSettings();
});

class SuperadminSettingsScreen extends ConsumerStatefulWidget {
  const SuperadminSettingsScreen({super.key});

  @override
  ConsumerState<SuperadminSettingsScreen> createState() => _SuperadminSettingsScreenState();
}

class _SuperadminSettingsScreenState extends ConsumerState<SuperadminSettingsScreen> {
  final _trialDaysCtrl = TextEditingController(text: '14');
  final _graceDaysCtrl = TextEditingController(text: '3');
  final _photoLimitCtrl = TextEditingController(text: '2000');
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _trialDaysCtrl.dispose();
    _graceDaysCtrl.dispose();
    _photoLimitCtrl.dispose();
    super.dispose();
  }

  void _initSettings(Map<String, dynamic> settings) {
    if (_initialized) return;
    _trialDaysCtrl.text = '${settings['default_trial_days'] ?? 14}';
    _graceDaysCtrl.text = '${settings['grace_period_days'] ?? 3}';
    _photoLimitCtrl.text = '${settings['default_photo_limit'] ?? 2000}';
    _initialized = true;
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final trialDays = int.tryParse(_trialDaysCtrl.text.trim()) ?? 14;
      final graceDays = int.tryParse(_graceDaysCtrl.text.trim()) ?? 3;
      final photoLimit = int.tryParse(_photoLimitCtrl.text.trim()) ?? 2000;

      await SuperadminService(pb).saveSystemSettings({
        'default_trial_days': trialDays,
        'grace_period_days': graceDays,
        'default_photo_limit': photoLimit,
      });

      ref.invalidate(_systemSettingsProvider);
      if (mounted) {
        AppToast.show('✓ Platform settings saved successfully', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to save settings: ${ErrorFormatter.format(e)}', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(_systemSettingsProvider);

    return Scaffold(
      backgroundColor: SAColors.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: SAColors.gradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: SAColors.accentGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: SAColors.accent.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            )
                          ],
                        ),
                        child: Icon(Icons.admin_panel_settings_rounded, color: context.colors.textPrimary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Superadmin Console', style: context.textStyles.h4.copyWith(color: SAColors.textPrimary)),
                        Text('Platform Master Controls', style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
                      ]),
                    ]),
                    const SizedBox(height: 32),

                    // Dynamic System Settings Card
                    _sectionLabel(context, 'Subscription & Platform Defaults'),
                    settingsAsync.when(
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: SAColors.accent))),
                      error: (e, _) => Text('Error loading settings: $e', style: const TextStyle(color: SAColors.error)),
                      data: (settings) {
                        _initSettings(settings);

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: SAColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: SAColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Default Trial Period', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Number of trial days automatically granted upon clinic registration.',
                                  style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
                              const SizedBox(height: 8),
                              _darkNumField(_trialDaysCtrl, 'Trial Days (e.g. 14)', Icons.timer_outlined),
                              const SizedBox(height: 18),

                              Text('Expiration Grace Period', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Days of banner warning before hard-locking staff and clinics.',
                                  style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
                              const SizedBox(height: 8),
                              _darkNumField(_graceDaysCtrl, 'Grace Period Days (e.g. 3)', Icons.warning_amber_rounded),
                              const SizedBox(height: 18),

                              Text('Default Photo Limit', style: context.textStyles.label.copyWith(color: SAColors.textPrimary, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('Standard clinical photo storage limit for Base plans.',
                                  style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
                              const SizedBox(height: 8),
                              _darkNumField(_photoLimitCtrl, 'Photo Limit (e.g. 2000)', Icons.photo_library_outlined),
                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveSettings,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SAColors.accent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Save System Defaults', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),

                    _sectionLabel(context, 'System Info'),
                    _infoTile(context, Icons.dns_rounded, 'PocketBase Server', pbBaseUrl),
                    _infoTile(context, Icons.security_rounded, 'Session', 'PocketBase _superusers'),
                    _infoTile(context, Icons.verified_user_rounded, 'Access Level', 'Full Read & Write (All Collections)'),
                    const SizedBox(height: 24),

                    _sectionLabel(context, 'Superadmin Permissions'),
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
                          _policyRow(context, Icons.check_circle_outline_rounded, SAColors.success, 'Full Access across all registered Clinics'),
                          _policyRow(context, Icons.check_circle_outline_rounded, SAColors.success, 'Inspect & Edit Patient Records (Read & Write)'),
                          _policyRow(context, Icons.check_circle_outline_rounded, SAColors.success, 'Inspect & Delete Consultations & Sessions'),
                          _policyRow(context, Icons.check_circle_outline_rounded, SAColors.success, 'Edit Subscription Plans, Expiry Dates & Photo Quotas'),
                          _policyRow(context, Icons.check_circle_outline_rounded, SAColors.success, 'Manage Doctors, Receptionists & Reset Passwords'),
                          _policyRow(context, Icons.check_circle_outline_rounded, SAColors.success, 'Full Data Export (ZIP) & Irreversible Purge Operations'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Logout
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: SAColors.card,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text('Logout', style: context.textStyles.h4.copyWith(color: SAColors.textPrimary)),
                              content: Text('End your superadmin session?',
                                  style: context.textStyles.bodyMedium.copyWith(color: SAColors.textSecondary)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel', style: TextStyle(color: SAColors.textHint)),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: SAColors.error, foregroundColor: Colors.white),
                                  child: const Text('Logout'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(authProvider.notifier).logout();
                            if (context.mounted) {
                              context.go('/superadmin/login');
                            }
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
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(label, style: context.textStyles.caption.copyWith(color: SAColors.textHint, letterSpacing: 1, fontSize: 11)),
      );

  Widget _darkNumField(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: SAColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SAColors.border),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: SAColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: SAColors.textHint, fontSize: 13),
          prefixIcon: Icon(icon, color: SAColors.textHint, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _infoTile(BuildContext context, IconData icon, String label, String value) {
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
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: context.textStyles.caption.copyWith(color: SAColors.textHint)),
          Text(value, style: context.textStyles.bodyMedium.copyWith(color: SAColors.textPrimary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _policyRow(BuildContext context, IconData icon, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(color: SAColors.textPrimary, fontSize: 13))),
      ]),
    );
  }
}

