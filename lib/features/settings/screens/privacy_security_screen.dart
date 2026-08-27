import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';


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
  bool _isGoogleLinked = false;
  bool _isLoadingGoogle = true;

  @override
  void initState() {
    super.initState();
    _checkGoogleLinked();
  }

  Future<void> _checkGoogleLinked() async {
    final auth = ref.read(authProvider);
    if (auth.role != UserRole.clinic || auth.userId == null) {
      if (mounted) setState(() => _isLoadingGoogle = false);
      return;
    }
    
    final isLinked = await ref.read(authProvider.notifier).authService.hasGoogleAccount(auth.userId!);
    if (mounted) {
      setState(() {
        _isGoogleLinked = isLinked;
        _isLoadingGoogle = false;
      });
    }
  }

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
      final userId = auth.userId!;
      final String collection;
      if (auth.role == UserRole.clinic) {
        collection = PBCollections.clinics;
      } else if (auth.role == UserRole.receptionist) {
        collection = PBCollections.receptionists;
      } else {
        collection = PBCollections.doctors;
      }

      await pb.collection(collection).update(userId, body: {
        'oldPassword': current,
        'password': newPass,
        'passwordConfirm': confirm,
      });

      if (mounted) {
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        AppToast.show('Password changed successfully. Please log in again.', type: ToastType.success, duration: const Duration(seconds: 3));
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          ref.read(authProvider.notifier).logout();
        }
      }
    } catch (e) {
      _showError('Failed to change password. Check your current password and try again.');
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  Future<void> _toggleGoogleLink(bool newValue) async {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;
    final pb = ref.read(pocketbaseProvider);

    if (newValue) {
      // Link Google Account
      setState(() => _isLoadingGoogle = true);
      final result = await ref.read(authProvider.notifier).authService.linkGoogleAccount();
      if (result.success) {
        if (mounted) {
          AppToast.show('Google Account successfully linked.', type: ToastType.success);
          setState(() => _isGoogleLinked = true);
        }
      } else {
        if (mounted) {
          _showError('Failed to link Google account.');
        }
      }
      if (mounted) setState(() => _isLoadingGoogle = false);
    } else {
      // Unlink Google Account - check if password exists
      setState(() => _isLoadingGoogle = true);
      
      // Ask for password to confirm unlinking
      final passwordCtrl = TextEditingController();
      bool obscureConfirmPassword = true;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Disconnect Google Account?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To ensure you do not lose access to your account, please enter your password to confirm.',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: passwordCtrl,
                  label: 'Password',
                  hint: 'Enter your password',
                  obscureText: obscureConfirmPassword,
                  prefixIcon: Icon(Icons.lock_rounded, color: context.colors.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: context.colors.textHint,
                    ),
                    onPressed: () => setStateDialog(() => obscureConfirmPassword = !obscureConfirmPassword),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: context.colors.textHint)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Disconnect', style: TextStyle(color: context.colors.error)),
              ),
            ],
          ),
        ),
      );

      if (confirm == true && passwordCtrl.text.isNotEmpty) {
        // Validate password first by trying to re-authenticate
        try {
          final isClinic = auth.role == UserRole.clinic;
          final username = isClinic ? auth.clinic!.username : auth.doctor!.username;
          final collection = isClinic ? PBCollections.clinics : PBCollections.doctors;
          await pb.collection(collection).authWithPassword(username, passwordCtrl.text);
          
          final success = await ref.read(authProvider.notifier).authService.unlinkGoogleAccount(auth.userId!);
          if (success) {
            if (mounted) {
              AppToast.show('Google Account disconnected.', type: ToastType.success);
              setState(() => _isGoogleLinked = false);
            }
          } else {
            if (mounted) {
              _showError('Failed to disconnect Google account.');
            }
          }
        } catch (e) {
          if (mounted) {
            _showError('Incorrect password or failed to disconnect.');
          }
        }
      } else if (confirm == true) {
         if (mounted) _showError('Password is required to disconnect.');
      }
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }

  void _showError(String msg) {
    AppToast.show(msg, type: ToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Privacy & Security', style: context.textStyles.h4),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final children = [
              // Account info read-only
              _sectionHeader('Account', Icons.shield_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    _infoRow(
                      Icons.person_rounded,
                      'Account type',
                      isClinic
                          ? 'Clinic Account'
                          : (auth.role == UserRole.receptionist
                              ? 'Receptionist / Staff'
                              : 'Doctor Account'),
                    ),
                    Divider(height: 16, color: context.colors.border),
                    _infoRow(
                      Icons.alternate_email_rounded,
                      'Username',
                      isClinic
                          ? (auth.clinic?.username ?? '—')
                          : (auth.role == UserRole.receptionist
                              ? (auth.receptionist?.username ?? '—')
                              : (auth.doctor?.username ?? '—')),
                    ),
                    if (auth.role == UserRole.receptionist) ...[
                      Divider(height: 16, color: context.colors.border),
                      _infoRow(
                        Icons.tag_rounded,
                        'Staff ID',
                        auth.receptionist?.receptionistId ?? '—',
                      ),
                    ] else if (auth.role == UserRole.doctor) ...[
                      Divider(height: 16, color: context.colors.border),
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

              // Connected Accounts (Clinics Only)
              if (isClinic) ...[
                _sectionHeader('Connected Accounts', Icons.link_rounded),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.colors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(Icons.g_mobiledata_rounded, size: 24, color: context.colors.primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Google', style: context.textStyles.h4.copyWith(fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in quickly using your Google account',
                              style: context.textStyles.caption.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (_isLoadingGoogle)
                        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Switch(
                          value: _isGoogleLinked,
                          activeThumbColor: context.colors.primary,
                          onChanged: _toggleGoogleLink,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Change password
              _sectionHeader('Change Password', Icons.lock_reset_rounded),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    AppTextField(
                      controller: _currentPassCtrl,
                      label: 'Current Password',
                      hint: 'Enter your current password',
                      obscureText: _obscureCurrent,
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: context.colors.textHint),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: context.colors.textHint,
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
                      prefixIcon: Icon(Icons.lock_rounded, color: context.colors.textHint),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: context.colors.textHint,
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
                      prefixIcon: Icon(Icons.lock_rounded, color: context.colors.textHint),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: context.colors.textHint,
                        ),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: SizedBox(
                        width: isDesktop ? 320 : double.infinity,
                        child: AppButton(
                          label: 'Change Password',
                          isLoading: _isChanging,
                          icon: Icons.lock_reset_rounded,
                          onPressed: _changePassword,
                        ),
                      ),
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
                iconColor: context.colors.info,
                title: 'Data Encryption & Storage',
                body:
                    'Your clinical data, patient medical records, and treatment sessions are protected using industry-standard AES-256 encryption at rest and TLS 1.3 in transit. All records are hosted on isolated, secure backend instances.',
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.person_off_rounded,
                iconColor: context.colors.warning,
                title: 'Access Control & HIPAA Alignment',
                body:
                    'Strict role-based access control (RBAC) ensures patient charts are visible only to authorized medical practitioners. Detailed audit logs track all access to medical histories, aligning with HIPAA compliance guidelines.',
              ),
              const SizedBox(height: 10),
              _infoCard(
                icon: Icons.delete_forever_rounded,
                iconColor: context.colors.error,
                title: 'Data Portability & Deletion',
                body:
                    'Export your complete clinical directory or request permanent account deletion at any time. Data requests are processed in compliance with GDPR guidelines. Contact support@needil.com for administrative actions.',
              ),
            ];

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
                            color: context.colors.shadowColor.withValues(alpha: 0.2),
                            blurRadius: 32,
                            spreadRadius: 4,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    ),
                  ),
                ),
              );
            } else {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: children,
              );
            }
          },
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(
        children: [
          Icon(icon, size: 18, color: context.colors.primary),
          const SizedBox(width: 8),
          Text(title, style: context.textStyles.h3.copyWith(color: context.colors.primary, fontSize: 15)),
        ],
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(
        children: [
          Icon(icon, size: 16, color: context.colors.textHint),
          const SizedBox(width: 10),
          Text('$label: ', style: context.textStyles.caption),
          Expanded(
            child: Text(
              value,
              style: context.textStyles.label.copyWith(fontSize: 13),
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
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
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
                  Text(title, style: context.textStyles.label.copyWith(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(body, style: context.textStyles.caption.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
