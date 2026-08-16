import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pms_app/core/utils/validators.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/auth/screens/otp_verification_screen.dart';

/// Registration entry screen — matches the Figma login design language.
///
/// Desktop: 55/45 split (dark green BrandPanel left, white form right).
/// Mobile: Stacked — dark green hero top, white form bottom.
class ClinicStep0OtpScreen extends ConsumerStatefulWidget {
  const ClinicStep0OtpScreen({super.key});

  @override
  ConsumerState<ClinicStep0OtpScreen> createState() =>
      _ClinicStep0OtpScreenState();
}

class _ClinicStep0OtpScreenState extends ConsumerState<ClinicStep0OtpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isChecking = false;
  String? _error;
  bool _emailFocused = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _primary = Color(0xFF1B3D2F);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkEmailAndSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isChecking = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final auth = ref.read(authProvider.notifier);

    try {
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

      context.push(
        '/auth/otp-verify',
        extra: {
          'mode': OtpMode.registration,
          'email': email,
          'clinic_data': const <String, dynamic>{},
        },
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: isDesktop ? _buildFormPanel() : _buildMobileLayout(),
    );
  }

  Widget _buildFormPanel() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: _buildForm(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Dark green hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              color: _primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/needil_logo_white.png',
                    height: 32,
                    fit: BoxFit.contain,
                    color: Colors.white,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CLINIC MANAGEMENT SOFTWARE',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 24),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                      children: [
                        const TextSpan(text: 'Register your\n'),
                        TextSpan(
                          text: 'clinic today.',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                            color: const Color(0xFFA8D5B5),
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Form
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: _buildForm(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Heading
          Text(
            'Register Your Clinic',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              height: 1.1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your email to get started with a secure one-time code.',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 32),

          // Email field
          Text(
            'Clinic Email Address',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Focus(
            onFocusChange: (f) => setState(() => _emailFocused = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _emailFocused ? _primary : const Color(0xFFE5E7EB),
                  width: _emailFocused ? 1.5 : 1,
                ),
                boxShadow: _emailFocused
                    ? [
                        BoxShadow(
                          color: _primary.withValues(alpha: 0.1),
                          blurRadius: 0,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF1F2937),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. contact@cityhealth.com',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFD1D5DB),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                  errorStyle: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  return Validators.email(v);
                },
              ),
            ),
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Send OTP button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isChecking ? null : _checkEmailAndSendOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _primary.withValues(alpha: 0.7),
                foregroundColor: Colors.white,
                elevation: 1,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Send Secure OTP',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Info text
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.shield,
                  size: 14,
                  color: const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 6),
                Text(
                  "We'll send a code to verify your email",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Sign in link
          Center(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF9CA3AF),
                ),
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Sign In',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
