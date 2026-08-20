import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<NavigatorState> _nestedNavKey = GlobalKey<NavigatorState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscure = true;
  bool _rememberMe = true;
  bool _isCapsLockOn = false;
  bool _isGoogleLoginActive = false;
  bool _isEmailLoginActive = false;

  static const _bg = Color(0xFFF8F0EA);
  static const _surface = Color(0xFFFFFFFF);
  static const _primary = Color(0xFF0F5D4F);
  static const _textDark = Color(0xFF161616);
  static const _textMuted = Color(0xFF6F6F6F);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        final capsOn = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
        if (capsOn != _isCapsLockOn) setState(() => _isCapsLockOn = capsOn);
      }
      setState(() {});
    });
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _emailFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isGoogleLoginActive) {
      // If user came back to the app without completing Google auth in external browser
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _isGoogleLoginActive) {
          final auth = ref.read(authProvider);
          if (!auth.isAuthenticated && !auth.requiresGoogleRegistration) {
            ref.read(authProvider.notifier).cancelOAuth();
            setState(() {
              _isGoogleLoginActive = false;
            });
          }
        }
      });
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    final capsOn = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
    if (capsOn != _isCapsLockOn) {
      setState(() {
        _isCapsLockOn = capsOn;
      });
    }
    return false;
  }

  void _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    TextInput.finishAutofillContext();
    setState(() => _isEmailLoginActive = true);
    try {
      await ref.read(authProvider.notifier).loginAny(
            _emailCtrl.text.trim(),
            _passwordCtrl.text.trim(),
          );
    } finally {
      if (mounted) {
        setState(() => _isEmailLoginActive = false);
      }
    }
  }

  void _loginWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() => _isGoogleLoginActive = true);
    try {
      await ref.read(authProvider.notifier).loginWithGoogle();
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoginActive = false);
      }
    }
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
      backgroundColor: isDesktop ? _bg : _surface,
      body: isDesktop
          ? Row(
              children: [
                const Expanded(flex: 62, child: BrandPanel()),
                Expanded(
                  flex: 38,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        bottomLeft: Radius.circular(28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF161616).withValues(alpha: 0.05),
                          blurRadius: 32,
                          spreadRadius: 0,
                          offset: const Offset(-8, 0),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
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
                                  pageBuilder: (context, anim, secAnim) {
                                    return Theme(
                                      data: AppTheme.lightTheme,
                                      child: builder(context),
                                    );
                                  },
                                  transitionsBuilder: (context, anim, secAnim, child) {
                                    return FadeTransition(
                                      opacity: anim,
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildForm(authState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(AuthState authState) {
    return Container(
      color: _surface,
      child: Stack(
        children: [
          // Subtle ambient emerald mint glow at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFE6F4F0).withValues(alpha: 0.85),
                    const Color(0xFFF2FAF7).withValues(alpha: 0.4),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      Image.asset(
                        'assets/images/needil_logo_cropped.png',
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '— CLINIC MANAGEMENT —',
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: _textMuted,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildForm(authState, isMobile: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AuthState authState, {bool isMobile = false}) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onLongPress: () => context.push('/superadmin/login'),
                    child: Text(
                      'Welcome Back',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: isMobile ? 44 : 52,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                        height: 1.0,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in to continue managing your clinic',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF555555),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _label('Email or Username'),
            const SizedBox(height: 8),
            _input(
              controller: _emailCtrl,
              focusNode: _emailFocusNode,
              hint: 'Email or username',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
              validator: (v) => Validators.required(v, 'Username'),
            ),
            const SizedBox(height: 18),
            _label('Password'),
            const SizedBox(height: 8),
            _input(
              controller: _passwordCtrl,
              focusNode: _passwordFocusNode,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _login(),
              validator: (v) => Validators.required(v, 'Password'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? true),
                            activeColor: _primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                GestureDetector(
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
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: authState.isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: _primary.withValues(alpha: 0.7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: _primary.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ).copyWith(
                  elevation: WidgetStateProperty.resolveWith<double>((states) {
                    if (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) return 4;
                    return 0;
                  }),
                ),
                child: (_isEmailLoginActive && authState.isLoading)
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
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: authState.isLoading ? null : _loginWithGoogle,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E0D9)),
                  backgroundColor: Colors.white,
                  foregroundColor: _textDark,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ).copyWith(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.hovered)) return const Color(0xFFF9FAFB);
                    if (states.contains(WidgetState.pressed)) return const Color(0xFFF3F4F6);
                    return Colors.white;
                  }),
                  side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                    if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) {
                      return const BorderSide(color: Color(0xFFCBD5E1), width: 1.2);
                    }
                    return const BorderSide(color: Color(0xFFE2E0D9), width: 1);
                  }),
                ),
                child: (_isGoogleLoginActive && authState.isLoading)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F5D4F)),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
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
            const SizedBox(height: 28),
            Center(
              child: Text.rich(
                TextSpan(
                  text: 'By continuing, you agree to Needil\'s ',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF888888),
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: 'Terms of Service',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textDark,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFCCCCCC),
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _textDark,
                        decoration: TextDecoration.underline,
                        decorationColor: const Color(0xFFCCCCCC),
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _textDark,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    final isFocused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        color: isFocused ? Colors.white : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused ? _primary : const Color(0xFFE2E0D9),
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.08),
                  blurRadius: 14,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isPassword && _obscure,
        autocorrect: false,
        textCapitalization: TextCapitalization.none,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onFieldSubmitted: onFieldSubmitted,
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
            color: isFocused ? _primary : const Color(0xFF999999),
          ),
          border: InputBorder.none,
          suffixIcon: isPassword
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFocused && _isCapsLockOn)
                      Tooltip(
                        message: 'Caps Lock is on',
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward_rounded, size: 11, color: Color(0xFFD97706)),
                              SizedBox(width: 2),
                              Text(
                                'CAPS',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    GestureDetector(
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
                    ),
                  ],
                )
              : null,
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          errorStyle: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFFEF4444),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final paint = Paint()..style = PaintingStyle.fill;

    // 1. Blue segment (#4285F4)
    paint.color = const Color(0xFF4285F4);
    final bluePath = Path()
      ..moveTo(22.56, 12.25)
      ..cubicTo(22.56, 11.47, 22.49, 10.72, 22.36, 10.0)
      ..lineTo(12.0, 10.0)
      ..lineTo(12.0, 14.26)
      ..lineTo(17.92, 14.26)
      ..cubicTo(17.66, 15.63, 16.88, 16.79, 15.71, 17.57)
      ..lineTo(15.71, 20.34)
      ..lineTo(19.28, 20.34)
      ..cubicTo(21.36, 18.42, 22.56, 15.6, 22.56, 12.25)
      ..close();
    canvas.drawPath(bluePath, paint);

    // 2. Green segment (#34A853)
    paint.color = const Color(0xFF34A853);
    final greenPath = Path()
      ..moveTo(12.0, 23.0)
      ..cubicTo(14.97, 23.0, 17.46, 22.02, 19.28, 20.34)
      ..lineTo(15.71, 17.57)
      ..cubicTo(14.73, 18.23, 13.48, 18.63, 12.0, 18.63)
      ..cubicTo(9.14, 18.63, 6.71, 16.7, 5.84, 14.09)
      ..lineTo(2.18, 14.09)
      ..lineTo(2.18, 16.93)
      ..cubicTo(3.99, 20.53, 7.7, 23.0, 12.0, 23.0)
      ..close();
    canvas.drawPath(greenPath, paint);

    // 3. Yellow segment (#FBBC05)
    paint.color = const Color(0xFFFBBC05);
    final yellowPath = Path()
      ..moveTo(5.84, 14.09)
      ..cubicTo(5.62, 13.43, 5.49, 12.73, 5.49, 12.0)
      ..cubicTo(5.49, 11.27, 5.62, 10.57, 5.84, 9.91)
      ..lineTo(5.84, 7.07)
      ..lineTo(2.18, 7.07)
      ..cubicTo(1.43, 8.55, 1.0, 10.22, 1.0, 12.0)
      ..cubicTo(1.0, 13.78, 1.43, 15.45, 2.18, 16.93)
      ..lineTo(5.84, 14.09)
      ..close();
    canvas.drawPath(yellowPath, paint);

    // 4. Red segment (#EA4335)
    paint.color = const Color(0xFFEA4335);
    final redPath = Path()
      ..moveTo(12.0, 5.38)
      ..cubicTo(13.62, 5.38, 15.06, 5.94, 16.21, 7.02)
      ..lineTo(19.36, 3.87)
      ..cubicTo(17.45, 2.09, 14.97, 1.0, 12.0, 1.0)
      ..cubicTo(7.7, 1.0, 3.99, 3.47, 2.18, 7.07)
      ..lineTo(5.84, 9.91)
      ..cubicTo(6.71, 7.31, 9.14, 5.38, 12.0, 5.38)
      ..close();
    canvas.drawPath(redPath, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
