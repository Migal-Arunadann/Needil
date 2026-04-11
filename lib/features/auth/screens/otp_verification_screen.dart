import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

enum OtpMode { registration, forgotPassword }

/// Reusable OTP verification screen for both registration and forgot-password flows.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  final OtpMode mode;
  final String email;           // displayed (masked) and used for resend
  final Map<String, dynamic>? clinicData; // only for registration mode

  const OtpVerificationScreen({
    super.key,
    required this.mode,
    required this.email,
    this.clinicData,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  String? _error;

  // Resend cooldown
  int _resendSeconds = 60;
  bool _canResend = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _startResendTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() { _resendSeconds = 60; _canResend = false; });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) _canResend = true;
      });
      return _resendSeconds > 0;
    });
  }

  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name[0]}${name[1]}***@$domain';
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    } else if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() => _error = null);
    if (_otp.length == 6) _verify();
  }

  Future<void> _verify() async {
    if (_otp.length < 6) {
      setState(() => _error = 'Enter all 6 digits');
      return;
    }
    setState(() { _isVerifying = true; _error = null; });
    FocusScope.of(context).unfocus();

    final notifier = ref.read(authProvider.notifier);

    if (widget.mode == OtpMode.registration) {
      await notifier.verifyRegistrationOtp(otpCode: _otp);
      if (!mounted) return;
      final authState = ref.read(authProvider);
      if (authState.error != null) {
        setState(() { _isVerifying = false; _error = authState.error; });
        ref.read(authProvider.notifier).clearError();
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      } else {
        // OTP verified — app.dart reactively switches home to MainLayout.
        // Do NOT call Navigator.pushNamedAndRemoveUntil here — it causes a black screen.
        setState(() => _isVerifying = false);
      }
      return;
    } else {
      // Forgot-password mode: navigate to reset-password screen with OTP code
      final authState = ref.read(authProvider);
      if (!mounted) return;
      setState(() => _isVerifying = false);
      Navigator.of(context).pushReplacementNamed(
        '/auth/reset-password',
        arguments: {'otp_code': _otp, 'otp_id': authState.pendingOtpId},
      );
      return;
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() => _error = null);
    final notifier = ref.read(authProvider.notifier);
    if (widget.mode == OtpMode.registration) {
      await notifier.resendRegistrationOtp();
    } else {
      await notifier.requestForgotPasswordOtp(widget.email);
    }
    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = _isVerifying || authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),

                // Icon
                Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 20, offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mark_email_read_rounded,
                        color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  widget.mode == OtpMode.registration
                      ? 'Verify Your Email'
                      : 'Reset Password',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1,
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a 6-digit code to',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _maskedEmail,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 40),

                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _otpBox(i)),
                ),

                // Error
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error))),
                    ]),
                  ),
                ],

                const SizedBox(height: 32),

                AppButton(
                  label: 'Verify Code',
                  onPressed: _verify,
                  isLoading: isLoading,
                  icon: Icons.check_circle_outline_rounded,
                ),

                const SizedBox(height: 24),

                // Resend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Didn't receive the code? ",
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                    GestureDetector(
                      onTap: _canResend ? _resend : null,
                      child: Text(
                        _canResend
                            ? 'Resend'
                            : 'Resend in ${_resendSeconds}s',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: _canResend
                              ? AppColors.primary
                              : AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 48, height: 56,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: AppTextStyles.h2.copyWith(letterSpacing: 0),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
        ),
        onChanged: (v) => _onDigitChanged(index, v),
      ),
    );
  }
}
