import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isJoining = false;
  bool _isSaving = false;
  final _clinicIdCtrl = TextEditingController();

  // Data sharing preferences
  late bool _sharePast;
  late bool _shareFuture;

  @override
  void initState() {
    super.initState();
    final doctor = ref.read(authProvider).doctor;
    _sharePast = doctor?.sharePastPatients ?? false;
    _shareFuture = doctor?.shareFuturePatients ?? false;
  }

  @override
  void dispose() {
    _clinicIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinClinic() async {
    final clinicCode = _clinicIdCtrl.text.trim();
    if (clinicCode.isEmpty) {
      _showError('Please enter a Clinic ID');
      return;
    }

    setState(() => _isJoining = true);

    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);

      // Find clinic by clinic_id code
      final clinics = await pb.collection(PBCollections.clinics).getList(
        filter: 'clinic_id = "$clinicCode"',
      );

      if (clinics.items.isEmpty) {
        _showError('No clinic found with ID: $clinicCode');
        setState(() => _isJoining = false);
        return;
      }

      final clinicRecord = clinics.items.first;

      // Update doctor record to link to clinic
      await pb.collection(PBCollections.doctors).update(
        auth.userId!,
        body: {'clinic': clinicRecord.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${clinicRecord.getStringValue('name')}!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        _clinicIdCtrl.clear();

        // Refresh auth state
        ref.read(authProvider.notifier).restoreSession();
      }
    } catch (e) {
      _showError('Failed to join clinic: $e');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _leaveClinic() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Clinic?'),
        content: const Text(
            'You will no longer be associated with this clinic. Your patient data sharing settings will be preserved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final pb = ref.read(pocketbaseProvider);
        final auth = ref.read(authProvider);

        await pb.collection(PBCollections.doctors).update(
          auth.userId!,
          body: {'clinic': ''},
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Left clinic'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
          ref.read(authProvider.notifier).restoreSession();
        }
      } catch (e) {
        _showError('Failed: $e');
      }
    }
  }

  Future<void> _saveSharingPrefs() async {
    setState(() => _isSaving = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);

      await pb.collection(PBCollections.doctors).update(
        auth.userId!,
        body: {
          'share_past_patients': _sharePast,
          'share_future_patients': _shareFuture,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sharing preferences saved'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.read(authProvider.notifier).restoreSession();
      }
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final doctor = auth.doctor;
    final isInClinic =
        doctor?.clinicId != null && doctor!.clinicId!.isNotEmpty;

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
                  // Top level tab, no back button needed.
                  const SizedBox(width: 14),
                  Text('Settings', style: AppTextStyles.h2),
                ],
              ),
              const SizedBox(height: 28),

              // Profile Section
              _sectionHeader('Profile', Icons.person_outline_rounded),
              const SizedBox(height: 10),
              _infoCard([
                _infoRow('Name', doctor?.name ?? '—'),
                _infoRow('Username', doctor?.username ?? '—'),
                if (doctor?.email != null && doctor!.email!.isNotEmpty)
                  _infoRow('Email', doctor.email!),
              ]),
              const SizedBox(height: 24),

              // Clinic Association
              _sectionHeader('Clinic', Icons.business_rounded),
              const SizedBox(height: 10),
              if (isInClinic) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Part of a clinic',
                                style: AppTextStyles.label.copyWith(
                                    color: AppColors.success)),
                            Text('Clinic ID: ${doctor.clinicId}',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _leaveClinic,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Leave',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.error)),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Join a Clinic',
                          style: AppTextStyles.label
                              .copyWith(color: AppColors.primary)),
                      const SizedBox(height: 4),
                      Text(
                          'Enter the Clinic ID provided by your clinic administrator.',
                          style: AppTextStyles.caption),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _clinicIdCtrl,
                        label: 'Clinic ID',
                        hint: 'e.g. CL-XXXXXX',
                        prefixIcon: const Icon(Icons.vpn_key_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Join Clinic',
                        isLoading: _isJoining,
                        icon: Icons.link_rounded,
                        onPressed: _joinClinic,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Data Sharing Section
              if (isInClinic) ...[
                _sectionHeader(
                    'Data Sharing', Icons.share_rounded),
                const SizedBox(height: 6),
                Text(
                  'Control what patient data the clinic can access.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      _sharingToggle(
                        title: 'Share Past Patients',
                        subtitle:
                            'Allow clinic to view patients you treated before joining',
                        value: _sharePast,
                        icon: Icons.history_rounded,
                        onChanged: (v) => setState(() => _sharePast = v),
                      ),
                      Divider(height: 1, color: AppColors.border),
                      _sharingToggle(
                        title: 'Share Future Patients',
                        subtitle:
                            'Allow clinic to view patients you treat after joining',
                        value: _shareFuture,
                        icon: Icons.upcoming_rounded,
                        onChanged: (v) => setState(() => _shareFuture = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppButton(
                  label: 'Save Sharing Preferences',
                  isLoading: _isSaving,
                  icon: Icons.save_rounded,
                  onPressed: _saveSharingPrefs,
                ),
                const SizedBox(height: 24),
              ],

              // Danger zone
              _sectionHeader('Account', Icons.shield_rounded),
              const SizedBox(height: 10),
              AppButton(
                label: 'Sign Out',
                isOutlined: true,
                icon: Icons.logout_rounded,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              color: AppColors.error, size: 22),
                          const SizedBox(width: 10),
                          const Text('Sign Out'),
                        ],
                      ),
                      content: const Text(
                          'Are you sure you want to sign out? You will need to log in again to access your account.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text('Cancel',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                            backgroundColor:
                                AppColors.error.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Sign Out',
                              style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    ref.read(authProvider.notifier).logout();
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/login', (route) => false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(title,
            style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
      ],
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sharingToggle({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.label.copyWith(fontSize: 13)),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
