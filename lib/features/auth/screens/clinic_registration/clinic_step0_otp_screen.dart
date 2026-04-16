import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_text_styles.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_text_field.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../core/constants/pb_collections.dart';
import '../../../../../core/providers/pocketbase_provider.dart';
import '../../providers/auth_provider.dart';
import '../otp_verification_screen.dart';

class ClinicStep0OtpScreen extends ConsumerStatefulWidget {
  const ClinicStep0OtpScreen({super.key});

  @override
  ConsumerState<ClinicStep0OtpScreen> createState() => _ClinicStep0OtpScreenState();
}

class _ClinicStep0OtpScreenState extends ConsumerState<ClinicStep0OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isChecking = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkEmailAndSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isChecking = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final pb = ref.read(pocketbaseProvider);
    final auth = ref.read(authProvider.notifier);

    try {
      // We can't check email existence anonymously due to PB security.
      // Request OTP to sign in or sign up automatically.

      // 2. Email doesn't exist -> Request OTP to create the shell clinic
      await auth.requestRegistrationOtp(email: email, clinicData: {});
      
      if (!mounted) return;
      final authState = ref.read(authProvider);
      
      if (authState.error != null) {
        setState(() {
          _error = authState.error;
          _isChecking = false;
        });
        ref.read(authProvider.notifier).clearError();
        return;
      }

      setState(() => _isChecking = false);
      
      // Navigate to OTP verification screen inline
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            mode: OtpMode.registration,
            email: email,
            clinicData: const {}, 
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Start Registration', style: AppTextStyles.h4),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Text('Get Started', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text(
                  'Enter your email address to register or sign in securely via a one-time password.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 48),
                AppTextField(
                  label: 'Clinic Email Address',
                  hint: 'e.g. contact@cityhealth.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    return Validators.email(v);
                  },
                  prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                  textInputAction: TextInputAction.done,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                ],
                const SizedBox(height: 48),
                AppButton(
                  label: 'Send Secure OTP',
                  onPressed: _checkEmailAndSendOtp,
                  isLoading: _isChecking,
                  icon: Icons.security_rounded,
                ),
                const SizedBox(height: 32),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/auth/login');
                    },
                    child: Text(
                      'Already have an account? Log in',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
}
