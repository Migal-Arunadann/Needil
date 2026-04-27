import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../auth/providers/auth_provider.dart';

// ── Superadmin colour palette ──────────────────────────────────────────────
class _SA {
  static const bg = Color(0xFF0A0A1A);
  static const card = Color(0xFF1C1C3A);
  static const accent = Color(0xFF7C6FFF);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textHint = Color(0xFF475569);
  static const border = Color(0xFF2D2D5E);

  static const gradient = LinearGradient(
    colors: [Color(0xFF0A0A1A), Color(0xFF13132B), Color(0xFF0F0F28)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const accentGradient = LinearGradient(
    colors: [Color(0xFF7C6FFF), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class SuperadminLoginScreen extends ConsumerStatefulWidget {
  const SuperadminLoginScreen({super.key});

  @override
  ConsumerState<SuperadminLoginScreen> createState() => _SuperadminLoginScreenState();
}

class _SuperadminLoginScreenState extends ConsumerState<SuperadminLoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());

  bool _obscurePass = true;
  bool _otpPhase = false;
  bool _isLoading = false;
  int _otpSeconds = 120;
  Timer? _otpTimer;

  // Stored as LOCAL state — immune to Riverpod global state resets
  String? _pendingOtpId;
  String? _pendingMfaId;
  String? _pendingEmail;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _otpTimer?.cancel();
    super.dispose();
  }

  void _startOtpTimer() {
    _otpSeconds = 120;
    _otpTimer?.cancel();
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_otpSeconds <= 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _otpSeconds--);
      }
    });
  }

  String get _timerLabel {
    final m = _otpSeconds ~/ 60;
    final s = _otpSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: _SA.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submitCredentials() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) { _showError('Enter email and password'); return; }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    // Call AuthService directly — bypass the global Riverpod notifier
    final authService = ref.read(authServiceProvider);
    final result = await authService.loginSuperadmin(email, pass);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) { _showError(result.error ?? 'Login failed'); return; }

    // Store locally in widget state — never gets wiped by global state changes
    _pendingOtpId = result.otpId;
    _pendingMfaId = result.mfaId;
    _pendingEmail = email;

    setState(() => _otpPhase = true);
    _startOtpTimer();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _otpFocus[0].requestFocus();
    });
  }

  Future<void> _submitOtp() async {
    final code = _otpCtrls.map((c) => c.text).join();
    if (code.length != 6) { _showError('Enter the full 6-digit code'); return; }
    if (_pendingOtpId == null) { _showError('Session lost — please go back and try again'); return; }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.verifySuperadminOtp(
      otpId: _pendingOtpId!,
      otpCode: code,
      mfaId: _pendingMfaId,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      _showError(result.error ?? 'Invalid OTP');
      for (final c in _otpCtrls) c.clear();
      if (mounted) _otpFocus[0].requestFocus();
      return;
    }

    // OTP verified — update global auth state so app.dart routes to SuperadminShell
    ref.read(authProvider.notifier).setSuperadminAuthenticated();
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    final result = await authService.loginSuperadmin(_emailCtrl.text.trim(), _passCtrl.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) { _showError(result.error ?? 'Failed to resend OTP'); return; }

    _pendingOtpId = result.otpId;
    _pendingMfaId = result.mfaId;
    _startOtpTimer();
    for (final c in _otpCtrls) c.clear();
    if (mounted) _otpFocus[0].requestFocus();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('New OTP sent to your email'),
      backgroundColor: _SA.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SA.bg,
      body: Container(
        decoration: const BoxDecoration(gradient: _SA.gradient),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          gradient: _SA.accentGradient,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: _SA.accent.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 10))],
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 42),
                      ),
                      const SizedBox(height: 28),
                      Text('Superadmin Access', style: AppTextStyles.h2.copyWith(color: _SA.textPrimary)),
                      const SizedBox(height: 8),
                      Text(
                        _otpPhase
                            ? 'OTP sent to ${_pendingEmail ?? ''}\nEnter the 6-digit code below.'
                            : 'Restricted access. Enter your\nadmin credentials to continue.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(color: _SA.textSecondary, height: 1.6),
                      ),
                      const SizedBox(height: 48),

                      if (!_otpPhase) ...[
                        _buildCredentialsForm(),
                        const SizedBox(height: 28),
                        _buildPrimaryButton('Continue', _submitCredentials),
                      ] else ...[
                        _buildOtpGrid(),
                        const SizedBox(height: 24),
                        _buildPrimaryButton('Verify & Enter', _submitOtp),
                        const SizedBox(height: 20),
                        _buildResendRow(),
                      ],

                      const SizedBox(height: 28),
                      TextButton.icon(
                        onPressed: () {
                          if (_otpPhase) {
                            setState(() { _otpPhase = false; _otpTimer?.cancel(); });
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: Icon(Icons.arrow_back_rounded, size: 16, color: _SA.textHint),
                        label: Text(_otpPhase ? 'Back to credentials' : 'Back to login',
                          style: AppTextStyles.caption.copyWith(color: _SA.textHint)),
                      ),
                      const SizedBox(height: 40),
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

  Widget _buildCredentialsForm() {
    return Column(children: [
      _darkField(controller: _emailCtrl, label: 'Admin Email', icon: Icons.email_outlined, type: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _darkField(
        controller: _passCtrl, label: 'Password', icon: Icons.lock_outline_rounded, obscure: _obscurePass,
        suffixIcon: IconButton(
          icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _SA.textHint, size: 20),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
      ),
    ]);
  }

  Widget _buildOtpGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 46, height: 56,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                if (_otpCtrls[i].text.isEmpty && i > 0) {
                  _otpFocus[i - 1].requestFocus();
                }
              }
            },
            child: TextFormField(
              controller: _otpCtrls[i],
              focusNode: _otpFocus[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.h3.copyWith(color: _SA.textPrimary, fontSize: 22),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                counterText: '',
                filled: true, fillColor: _SA.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.accent, width: 2)),
              ),
              onChanged: (val) {
                if (val.isNotEmpty && i < 5) _otpFocus[i + 1].requestFocus();
                if (val.isEmpty && i > 0) _otpFocus[i - 1].requestFocus();
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResendRow() {
    final canResend = _otpSeconds == 0;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Didn't receive it? ", style: AppTextStyles.caption.copyWith(color: _SA.textHint)),
      GestureDetector(
        onTap: canResend ? _resendOtp : null,
        child: Text(
          canResend ? 'Resend OTP' : 'Resend in $_timerLabel',
          style: AppTextStyles.caption.copyWith(color: canResend ? _SA.accent : _SA.textHint, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          gradient: _SA.accentGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _SA.accent.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(label, style: AppTextStyles.buttonLarge.copyWith(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _darkField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? type,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: AppTextStyles.bodyMedium.copyWith(color: _SA.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTextStyles.caption.copyWith(color: _SA.textHint),
        prefixIcon: Icon(icon, color: _SA.textHint, size: 20),
        suffixIcon: suffixIcon,
        filled: true, fillColor: _SA.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.accent, width: 1.5)),
      ),
    );
  }
}
