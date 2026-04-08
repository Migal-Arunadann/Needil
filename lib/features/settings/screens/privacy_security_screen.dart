import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';

class PrivacySecurityScreen extends ConsumerStatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  ConsumerState<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends ConsumerState<PrivacySecurityScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isChanging = false;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentPassCtrl.text.trim();
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }
    if (newPass.length < 8) {
      _showError('New password must be at least 8 characters');
      return;
    }
    if (newPass != confirm) {
      _showError('New passwords do not match');
      return;
    }
    if (newPass == current) {
      _showError('New password must be different from the current one');
      return;
    }

    setState(() => _isChanging = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);
      final isClinic = auth.role == UserRole.clinic;
      final userId = auth.userId!;
      final collection = isClinic ? PBCollections.clinics : PBCollections.doctors;

      await pb.collection(collection).update(userId, body: {
        'oldPassword': current,
        'password': newPass,
        'passwordConfirm': confirm,
      });

      if (mounted) {
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Password changed successfully. Please log in again.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ));
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) ref.read(authProvider.notifier).logout();
      }
    } catch (e) {
      _showError('Failed to change password. Check your current password and try again.');
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Privacy & Security', style: AppTextStyles.h4),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account info read-only
          _sectionHeader('Account', Icons.shield_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _infoRow(
                  Icons.person_rounded,
                  'Account type',
                  isClinic ? 'Clinic Account' : 'Doctor Account',
                ),
                Divider(height: 16, color: AppColors.border),
                _infoRow(
                  Icons.alternate_email_rounded,
                  'Username',
                  isClinic
                      ? (auth.clinic?.username ?? '—')
                      : (auth.doctor?.username ?? '—'),
                ),
                if (!isClinic) ...[
                  Divider(height: 16, color: AppColors.border),
                  _infoRow(
                    Icons.business_rounded,
                    'Clinic',
                    auth.doctor?.clinicId?.isNotEmpty == true
                        ? 'Associated with a clinic'
                        : 'Independent doctor',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Change password
          _sectionHeader('Change Password', Icons.lock_reset_rounded),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                AppTextField(
                  controller: _currentPassCtrl,
                  label: 'Current Password',
                  hint: 'Enter your current password',
                  obscureText: _obscureCurrent,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _newPassCtrl,
                  label: 'New Password',
                  hint: 'Min. 8 characters',
                  obscureText: _obscureNew,
                  prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _confirmPassCtrl,
                  label: 'Confirm New Password',
                  hint: 'Re-enter your new password',
                  obscureText: _obscureConfirm,
                  prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textHint,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: 'Change Password',
                  isLoading: _isChanging,
                  icon: Icons.lock_reset_rounded,
                  onPressed: _changePassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Data & Privacy
          _sectionHeader('Data & Privacy', Icons.privacy_tip_rounded),
          const SizedBox(height: 10),
          _infoCard(
            icon: Icons.storage_rounded,
            iconColor: AppColors.info,
            title: 'Your Data',
            body:
                'All patient records, appointments, and consultation data are stored securely on your private PocketBase server. Data is not shared with third parties.',
          ),
          const SizedBox(height: 10),
          _infoCard(
            icon: Icons.person_off_rounded,
            iconColor: AppColors.warning,
            title: 'Patient Confidentiality',
            body:
                'Patient information is accessible only to authorised clinic staff. Doctors can control data sharing settings from their profile.',
          ),
          const SizedBox(height: 10),
          _infoCard(
            icon: Icons.delete_forever_rounded,
            iconColor: AppColors.error,
            title: 'Account Deletion',
            body:
                'To request account deletion or data export, please contact your system administrator.',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.h3.copyWith(color: AppColors.primary, fontSize: 15)),
        ],
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textHint),
          const SizedBox(width: 10),
          Text('$label: ', style: AppTextStyles.caption),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.label.copyWith(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String body,
  }) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.label.copyWith(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(body, style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
