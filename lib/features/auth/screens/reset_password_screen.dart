import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/utils/validators.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';


/// Reset password screen — shown after OTP is verified for forgot-password flow.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  final String otpCode;
  final String? otpId;

  const ResetPasswordScreen({
    super.key,
    required this.otpCode,
    this.otpId,
  });

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).verifyOtpAndResetPassword(
      otpCode: widget.otpCode,
      newPassword: _newPassCtrl.text,
    );

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.error != null) {
      AppToast.show(authState.error!, type: ToastType.error);
      ref.read(authProvider.notifier).clearError();
      return;
    }

    // Success — show dialog then go back to login
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: context.colors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded,
                color: context.colors.success, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Password Reset!', style: context.textStyles.h3),
          const SizedBox(height: 8),
          Text(
            'Your password has been updated. Please log in with your new password.',
            style: context.textStyles.bodyMedium
                .copyWith(color: context.colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Go to Login',
                  style: context.textStyles.buttonMedium
                      .copyWith(color: context.colors.textPrimary)),
            ),
          ),
        ]),
      ),
    );

    if (!mounted) return;
    // Pop all auth screens back to login
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // No back — can't go back to OTP
        title: Text('New Password', style: context.textStyles.h4),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 32),

                  Center(
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: context.colors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: context.colors.success.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.lock_open_rounded,
                          color: context.colors.success, size: 38),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Set New Password', textAlign: TextAlign.center,
                      style: context.textStyles.h2),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a strong password for your clinic account.',
                    textAlign: TextAlign.center,
                    style: context.textStyles.bodyMedium
                        .copyWith(color: context.colors.textSecondary),
                  ),
                  SizedBox(height: 40),

                  AppTextField(
                    label: 'New Password',
                    hint: 'Min. 8 characters',
                    controller: _newPassCtrl,
                    obscureText: _obscureNew,
                    validator: Validators.password,
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: context.colors.textHint),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.colors.textHint,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: 20),

                  AppTextField(
                    label: 'Confirm New Password',
                    hint: 'Re-enter password',
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    validator: (v) =>
                        Validators.confirmPassword(v, _newPassCtrl.text),
                    prefixIcon: Icon(Icons.lock_outline_rounded,
                        color: context.colors.textHint),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: context.colors.textHint,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 36),

                  AppButton(
                    label: 'Save New Password',
                    onPressed: _save,
                    isLoading: authState.isLoading,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
