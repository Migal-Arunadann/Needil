import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pms_app/core/utils/validators.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/auth/widgets/brand_panel.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step0_otp_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step1_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step2_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step3_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step4_screen.dart';
import 'package:pms_app/features/auth/screens/clinic_registration/clinic_step5_screen.dart';
import 'package:pms_app/features/auth/screens/otp_verification_screen.dart';
import 'package:pms_app/features/auth/screens/forgot_password_screen.dart';
import 'package:pms_app/features/auth/screens/reset_password_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<NavigatorState> _nestedNavKey = GlobalKey<NavigatorState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  String? _focusedField;

  static const _bg = Color(0xFFF8F0EA);
  static const _surface = Color(0xFFFFFFFF);
  static const _primary = Color(0xFF0F5D4F);
  static const _textDark = Color(0xFF161616);
  static const _textMuted = Color(0xFF6F6F6F);
  static const _border = Color(0xFFE8E6E2);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _login() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).loginAny(
          _emailCtrl.text.trim(),
          _passwordCtrl.text.trim(),
        );
  }

  void _loginWithGoogle() {
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).loginWithGoogle();
  }

  void _showAccountExistsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'This account already exists.',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'We found an existing Needil account for this email.\n\nTo keep your account secure, please sign in using your password first. You can then connect your Google account anytime from Profile → Security.',
          style: GoogleFonts.inter(color: _textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Got it',
              style: GoogleFonts.inter(color: _primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        if (next.error == 'google_account_exists_unlinked') {
          _showAccountExistsDialog();
        } else {
          AppToast.show(next.error!, type: ToastType.error);
        }
      }
      
      if (next.requiresGoogleRegistration && !(prev?.requiresGoogleRegistration ?? false)) {
        context.push('/register/clinic/step1', extra: {'is_google': true});
      }
    });

    return Scaffold(
      backgroundColor: _surface,
      body: isDesktop
          ? Row(
              children: [
                const Expanded(flex: 55, child: BrandPanel()),
                Expanded(
                  flex: 45,
                  child: Container(
                    color: _surface,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: PopScope(
                            canPop: false,
                            onPopInvokedWithResult: (didPop, result) async {
                              if (didPop) return;
                              final navigator = _nestedNavKey.currentState;
                              if (navigator != null && navigator.canPop()) {
                                navigator.pop();
                              } else {
                                final mainNavigator = Navigator.of(context);
                                if (mainNavigator.canPop()) {
                                  mainNavigator.pop();
                                }
                              }
                            },
                              child: Navigator(
                                key: _nestedNavKey,
                                initialRoute: '/',
                                onGenerateRoute: (RouteSettings settings) {
                                  Widget builder(BuildContext context) {
                                    switch (settings.name) {
                                      case '/':
                                        return _buildFormPanel(authState);
                                    case '/register/clinic':
                                    case '/register/clinic/step0':
                                      return const ClinicStep0OtpScreen();
                                    case '/register/clinic/step1':
                                        final args = settings.arguments as Map<String, dynamic>?;
                                        final isGoogle = args?['is_google'] as bool? ?? false;
                                        return ClinicStep1Screen(isGoogleRegistration: isGoogle);
                                    case '/register/clinic/step2':
                                      final args = settings.arguments as Map<String, dynamic>;
                                      return ClinicStep2Screen(clinicData: args);
                                    case '/register/clinic/step3':
                                      final args = settings.arguments as Map<String, dynamic>;
                                      return ClinicStep3Screen(clinicData: args);
                                    case '/register/clinic/step4':
                                      final args = settings.arguments as Map<String, dynamic>;
                                      return ClinicStep4Screen(clinicData: args);
                                    case '/register/clinic/step5':
                                      final args = settings.arguments as Map<String, dynamic>;
                                      return ClinicStep5Screen(clinicData: args);
                                    case '/auth/otp-verify':
                                      final args = settings.arguments as Map<String, dynamic>;
                                      return OtpVerificationScreen(
                                        mode: args['mode'] as OtpMode,
                                        email: args['email'] as String,
                                        clinicData: args['clinic_data'] as Map<String, dynamic>?,
                                      );
                                    case '/auth/forgot-password':
                                      return const ForgotPasswordScreen();
                                    case '/auth/reset-password':
                                      final args = settings.arguments as Map<String, dynamic>;
                                      return ResetPasswordScreen(
                                        otpCode: args['otp_code'] as String,
                                        otpId: args['otp_id'] as String?,
                                      );
                                    default:
                                      return _buildFormPanel(authState);
                                  }
                                }

                                return PageRouteBuilder(
                                  settings: settings,
                                  pageBuilder: (context, _, __) {
                                    return Theme(
                                      data: AppTheme.lightTheme,
                                      child: builder(context),
                                    );
                                  },
                                  transitionsBuilder: (_, animation, __, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                  transitionDuration: const Duration(milliseconds: 250),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : _buildMobileLayout(authState),
    );
  }

  Widget _buildFormPanel(AuthState authState) {
    return Container(
      color: _surface,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _buildForm(authState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(AuthState authState) {
    return SafeArea(
      child: Container(
        color: _bg,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: _surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: _border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/needil_logo_cropped.png',
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '— CLINIC MANAGEMENT —',
                        style: GoogleFonts.inter(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: _textMuted,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildForm(authState),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onLongPress: () => context.push('/superadmin/login'),
            child: Text(
              'Welcome Back',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 52,
                fontWeight: FontWeight.w700,
                color: _textDark,
                height: 0.95,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in to continue managing your clinic',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF555555), // slightly darker for better contrast
            ),
          ),
          const SizedBox(height: 36),
          _label('Email or Username'),
          const SizedBox(height: 8),
          _input(
            controller: _emailCtrl,
            hint: 'Email or username',
            field: 'email',
            icon: Icons.person_outline_rounded,
            validator: (v) => Validators.required(v, 'Username'),
          ),
          const SizedBox(height: 20),
          _label('Password'),
          const SizedBox(height: 8),
          _input(
            controller: _passwordCtrl,
            hint: 'Password',
            field: 'password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (v) => Validators.required(v, 'Password'),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => context.push('/auth/forgot-password'),
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _primary.withValues(alpha: 0.7),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: _primary.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ).copyWith(
                elevation: WidgetStateProperty.resolveWith<double>((states) {
                  if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return 4;
                  return 0;
                }),
              ),
              child: authState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Container(height: 1, color: const Color(0xFFF0EFEB))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or continue with',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF999999),
                  ),
                ),
              ),
              Expanded(child: Container(height: 1, color: const Color(0xFFF0EFEB))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: OutlinedButton(
              onPressed: authState.isLoading ? null : _loginWithGoogle,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E0D9)),
                backgroundColor: Colors.white,
                foregroundColor: _textDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CustomPaint(painter: _GoogleLogoPainter()),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: _textMuted,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/register/clinic'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Register Clinic',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: _primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _textDark,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required String field,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    final isFocused = _focusedField == field;
    return Focus(
      onFocusChange: (f) => setState(() => _focusedField = f ? field : null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: isFocused ? Colors.white : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused ? _primary : const Color(0xFFE2E0D9),
            width: isFocused ? 1.5 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.06),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: TextFormField(
          controller: controller,
          obscureText: isPassword && _obscure,
          autocorrect: false,
          textCapitalization: TextCapitalization.none,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: _textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFB0B0B0),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            prefixIcon: Icon(
              icon,
              size: 20,
              color: const Color(0xFF999999),
            ),
            border: InputBorder.none,
            suffixIcon: isPassword
                ? GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: const Color(0xFF999999),
                      ),
                    ),
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            errorStyle: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFFEF4444),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.35;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth/2),
      -3.14159, 3.14159 / 2,
      false, paint,
    );

    // Yellow (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth/2),
      -3.14159 / 2, 3.14159 / 2,
      false, paint,
    );

    // Green (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth/2),
      0, 3.14159 / 2,
      false, paint,
    );

    // Blue (right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth/2),
      3.14159 / 2, 3.14159 / 2,
      false, paint,
    );
    
    // Draw the horizontal bar of 'G'
    paint.style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - strokeWidth/2, radius, strokeWidth),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
