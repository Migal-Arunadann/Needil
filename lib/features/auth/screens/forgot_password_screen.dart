import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/utils/validators.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/auth/screens/otp_verification_screen.dart';
import 'package:pms_app/core/theme/app_theme.dart';


/// Forgot Password screen — clinic enters their email, receives OTP.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    await ref.read(authProvider.notifier).requestForgotPasswordOtp(email);

    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (authState.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(authState.error!),
        backgroundColor: context.colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      ref.read(authProvider.notifier).clearError();
      return;
    }

    // Navigate to OTP screen
    Navigator.of(context).pushNamed(
      '/auth/otp-verify',
      arguments: {
        'mode': OtpMode.forgotPassword,
        'email': email,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: context.colors.primaryGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.primary.withValues(alpha: 0.3),
                          blurRadius: 20, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.lock_reset_rounded,
                        color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 28),

                Text('Forgot Password?', textAlign: TextAlign.center,
                    style: context.textStyles.h1),
                const SizedBox(height: 10),
                Text(
                  'Enter the email address on your clinic account.\nWe\'ll send you a one-time code to reset your password.',
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodyMedium
                      .copyWith(color: context.colors.textSecondary, height: 1.5),
                ),
                SizedBox(height: 44),

                Form(
                  key: _formKey,
                  child: AppTextField(
                    label: 'Clinic Email Address',
                    hint: 'Enter your registered email',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      return Validators.email(v);
                    },
                    prefixIcon: Icon(Icons.email_outlined,
                        color: context.colors.textHint),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(height: 32),

                AppButton(
                  label: 'Send OTP',
                  onPressed: _send,
                  isLoading: authState.isLoading,
                  icon: Icons.send_rounded,
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Only clinic accounts can reset password via email.\nDoctors and staff should contact their clinic admin.',
                    textAlign: TextAlign.center,
                    style: context.textStyles.caption
                        .copyWith(color: context.colors.textHint),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
