import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _login() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).loginAny(
          _usernameController.text.trim(),
          _passwordController.text,
        );
  }

  Widget _mockSidebarItem(IconData icon, String label, bool isActive, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: isActive ? const Color(0xFF60A5FA) : Colors.white24, size: 10),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white24,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mockMetricCard(String title, String val, String percentage, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white30, fontSize: 6)),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(val, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(percentage, style: const TextStyle(color: Colors.greenAccent, fontSize: 6, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mockApptRow(String name, String time, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFF475569),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name[0],
                style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white70, fontSize: 7, fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: Colors.white24, fontSize: 6),
          ),
        ],
      ),
    );
  }

  Widget _mockBar(double height) {
    return Container(
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildDashboardMockup(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Slate 900
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Mock Sidebar (width: 100)
          Container(
            width: 100,
            decoration: const BoxDecoration(
              color: Color(0xFF020617), // Slate 955
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Windows dots
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 24),
                // Items
                _mockSidebarItem(Icons.home_rounded, 'Home', true, context),
                _mockSidebarItem(Icons.calendar_month_rounded, 'Schedule', false, context),
                _mockSidebarItem(Icons.analytics_rounded, 'Analytics', false, context),
                _mockSidebarItem(Icons.people_alt_rounded, 'Patients', false, context),
              ],
            ),
          ),
          // Right Mock Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Metric cards Row
                  Row(
                    children: [
                      Expanded(child: _mockMetricCard('Patients', '248', '+12%', context)),
                      const SizedBox(width: 8),
                      Expanded(child: _mockMetricCard('Schedule', '32', '+8%', context)),
                      const SizedBox(width: 8),
                      Expanded(child: _mockMetricCard('Revenue', '₹64K', '+15%', context)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Lower split Row
                  Expanded(
                    child: Row(
                      children: [
                        // Left panel (Recent Appointments)
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recent Appointments',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: ListView(
                                    physics: const NeverScrollableScrollPhysics(),
                                    children: [
                                      _mockApptRow('John Smith', '10:00 AM', context),
                                      _mockApptRow('Emily Davis', '11:30 AM', context),
                                      _mockApptRow('Michael Brown', '01:00 PM', context),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right panel (Chart mockup)
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Appointments',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _mockBar(12),
                                      _mockBar(24),
                                      _mockBar(18),
                                      _mockBar(32),
                                      _mockBar(20),
                                      _mockBar(40),
                                      _mockBar(28),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900.0;

    Widget loginCard = Container(
      width: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: context.colors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glowing logo
          Center(
            child: GestureDetector(
              onLongPress: () => Navigator.of(context).pushNamed('/superadmin/login'),
              child: Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.colors.primary.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/needil_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome Back',
            textAlign: TextAlign.center,
            style: context.textStyles.h2.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to manage your clinic',
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 36),

          // Login form
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  label: 'Username',
                  hint: 'Enter your username',
                  controller: _usernameController,
                  validator: (v) => Validators.required(v, 'Username'),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: context.colors.textHint),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (v) => Validators.required(v, 'Password'),
                  prefixIcon: Icon(Icons.lock_outline_rounded, color: context.colors.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: context.colors.textHint,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),

          // Forgot Password link
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushNamed('/auth/forgot-password'),
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                child: Text(
                  'Forgot Password?',
                  style: context.textStyles.caption.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          AppButton(
            label: 'Sign In',
            onPressed: _login,
            isLoading: authState.isLoading,
            icon: Icons.login_rounded,
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/register/clinic'),
                child: Text(
                  'Register Clinic',
                  style: context.textStyles.bodyMedium.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: context.colors.background,
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        message: 'Signing in...',
        child: SafeArea(
          child: isDesktop
              ? Row(
                  children: [
                    // Left Hero Panel
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0B0F19), // Dark Slate
                              Color(0xFF0F172A), // Slate 900
                              Color(0xFF1E1B4B), // Indigo 955
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Needil Logo row
                            Row(
                              children: [
                                Image.asset(
                                  'assets/images/needil_icon.png',
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Needil',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(flex: 2),
                            // Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Text(
                                'Smart Clinic Management',
                                style: context.textStyles.bodySmall.copyWith(
                                  color: const Color(0xFF93C5FD),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Title
                            Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(text: 'Manage your clinic '),
                                  TextSpan(
                                    text: 'smarter,',
                                    style: TextStyle(color: const Color(0xFF60A5FA)),
                                  ),
                                  const TextSpan(text: ' not harder.'),
                                ],
                              ),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Description
                            Text(
                              'Everything you need to simplify appointments, patients, and daily operations — all in one place.',
                              style: context.textStyles.bodyMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                                height: 1.5,
                              ),
                            ),
                            const Spacer(),
                            // Dashboard illustration mockup
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 460),
                                child: _buildDashboardMockup(context),
                              ),
                            ),
                            const Spacer(flex: 2),
                            // Trust Footer
                            Row(
                              children: [
                                Icon(
                                  Icons.verified_user_outlined,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Secure. Reliable. Built for healthcare professionals.',
                                  style: context.textStyles.bodySmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Right Login Panel
                    Expanded(
                      flex: 6,
                      child: Container(
                        color: context.colors.background,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: loginCard,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: loginCard,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}