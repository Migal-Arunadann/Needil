import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';


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
        setState(() => _isVerifying = false);
        
        // If the clinic is already fully registered, we can show a brief message
        // before popping to the dashboard.
        if (authState.clinic?.name.isNotEmpty == true) {
          AppToast.show('Welcome back! You are already registered.', type: ToastType.error);
        }

        // Pop all overlayed screens (Step 0, OTP screen) so app.dart's root home takes over
        Navigator.of(context).popUntil((route) => route.isFirst);
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF161616)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: _buildWebLayout(context, isLoading),
              ),
            ),
          ),
        ),
      );
    }

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
                const SizedBox(height: 24),

                // Icon
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
                    child: Icon(Icons.mark_email_read_rounded,
                        color: context.colors.textPrimary, size: 38),
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  widget.mode == OtpMode.registration
                      ? 'Verify Your Email'
                      : 'Reset Password',
                  textAlign: TextAlign.center,
                  style: context.textStyles.h1,
                ),
                const SizedBox(height: 10),
                Text(
                  'We sent a 6-digit code to',
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodyMedium
                      .copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  _maskedEmail,
                  textAlign: TextAlign.center,
                  style: context.textStyles.label.copyWith(color: context.colors.primary),
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
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline_rounded,
                          size: 16, color: context.colors.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                          style: context.textStyles.caption
                              .copyWith(color: context.colors.error))),
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
                        style: context.textStyles.bodyMedium
                            .copyWith(color: context.colors.textSecondary)),
                    GestureDetector(
                      onTap: _canResend ? _resend : null,
                      child: Text(
                        _canResend
                            ? 'Resend'
                            : 'Resend in ${_resendSeconds}s',
                        style: context.textStyles.bodyMedium.copyWith(
                          color: _canResend
                              ? context.colors.primary
                              : context.colors.textHint,
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

  Widget _buildWebLayout(BuildContext context, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        Text(
          widget.mode == OtpMode.registration ? 'Verify Your Email' : 'Reset Password',
          textAlign: TextAlign.center,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 44,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF161616),
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a 6-digit code to',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF6F6F6F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _maskedEmail,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F5D4F),
          ),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _otpBoxWeb(i)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: isLoading ? null : _verify,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F5D4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Verify Code',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive the code? ",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6F6F6F),
                ),
              ),
              GestureDetector(
                onTap: _canResend ? _resend : null,
                child: Text(
                  _canResend ? 'Resend' : 'Resend in ${_resendSeconds}s',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _canResend ? const Color(0xFF0F5D4F) : const Color(0xFF999999),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _otpBoxWeb(int index) {
    final focusNode = _focusNodes[index];
    final controller = _controllers[index];

    return Focus(
      onFocusChange: (_) => setState(() {}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 50,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: focusNode.hasFocus ? const Color(0xFF0F5D4F) : const Color(0xFFE8E6E2),
            width: focusNode.hasFocus ? 1.5 : 1,
          ),
          boxShadow: focusNode.hasFocus
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F5D4F).withValues(alpha: 0.08),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
              if (controller.text.isEmpty && index > 0) {
                _focusNodes[index - 1].requestFocus();
              }
            }
          },
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF161616),
            ),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.zero,
              counterText: '',
              border: InputBorder.none,
            ),
            onChanged: (v) => _onDigitChanged(index, v),
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 48, height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          }
        },
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: context.textStyles.h2.copyWith(letterSpacing: 0),
          decoration: InputDecoration(
            contentPadding: EdgeInsets.zero,
            counterText: '',
            filled: true,
            fillColor: context.colors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.colors.error, width: 2),
            ),
          ),
          onChanged: (v) => _onDigitChanged(index, v),
        ),
      ),
    );
  }
}
