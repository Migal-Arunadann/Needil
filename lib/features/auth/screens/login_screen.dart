import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _backgroundAnimController;
  late Animation<double> _glowAnimation;

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

    _backgroundAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _glowAnimation = CurvedAnimation(
      parent: _backgroundAnimController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    _backgroundAnimController.dispose();
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

  Widget _buildLogoIcon({required double size, required double padding}) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/neediliconforweb.png',
        fit: BoxFit.contain,
      ),
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
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
      width: 5,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
        borderRadius: BorderRadius.circular(1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMockup(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromRGBO(18, 22, 40, 0.45),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Row(
                children: [
                  // Left Mock Sidebar
                  Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0F19).withValues(alpha: 0.5),
                      border: Border(
                        right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          Text('Dashboard', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
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
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Recent Appointments', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 8, fontWeight: FontWeight.bold)),
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
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Appointments', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 8, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _mockBar(16), _mockBar(32), _mockBar(24), _mockBar(44), _mockBar(28), _mockBar(56), _mockBar(38),
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
            ),
          ),
          // Reflection overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.06),
                      Colors.white.withValues(alpha: 0.01),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.15, 0.3, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingAnalyticsCard(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(24, 30, 54, 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF60A5FA).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Queue',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '8 Patients',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Avg. wait: 12 mins',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white38,
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardMockupWithFloatingCard(BuildContext context) {
    return SizedBox(
      width: 520,
      height: 360,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient blue glow behind the preview image
          Positioned(
            top: 30,
            left: 30,
            right: 70,
            bottom: 50,
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                    blurRadius: 48,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          // Mockup positioned inside
          Positioned(
            top: 20,
            left: 20,
            right: 40,
            bottom: 40,
            child: _buildDashboardMockup(context),
          ),
          // Floating card positioned relative to mockup bounds
          Positioned(
            bottom: 25,
            right: 25,
            child: _buildFloatingAnalyticsCard(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingPanel(BuildContext context, {required bool isMobileLayout}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildLogoIcon(size: 40, padding: 8),
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
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Manage your clinic\n'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                  ).createShader(bounds),
                  child: Text(
                    'smarter',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const TextSpan(text: ', not harder.'),
            ],
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 34,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Everything you need to simplify appointments, patients, and daily operations — all in one place.',
          style: context.textStyles.bodyMedium.copyWith(
            color: const Color(0xFF94A3B8),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: _buildDashboardMockupWithFloatingCard(context),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Icon(Icons.verified_user_outlined, color: const Color(0xFF64748B), size: 16),
            const SizedBox(width: 8),
            Text(
              'Secure. Reliable. Built for healthcare professionals.',
              style: context.textStyles.bodySmall.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );

    if (isMobileLayout) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: content,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useScroll = constraints.maxHeight < 700;
        if (useScroll) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            child: content,
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildLogoIcon(size: 40, padding: 8),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Manage your clinic\n'),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF60A5FA), Color(0xFF3B82F6)],
                          ).createShader(bounds),
                          child: Text(
                            'smarter',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ', not harder.'),
                    ],
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Everything you need to simplify appointments, patients, and daily operations — all in one place.',
                  style: context.textStyles.bodyMedium.copyWith(
                    color: const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
                const Spacer(flex: 1),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _buildDashboardMockupWithFloatingCard(context),
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: const Color(0xFF64748B), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Secure. Reliable. Built for healthcare professionals.',
                      style: context.textStyles.bodySmall.copyWith(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    final authState = ref.watch(authProvider);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460),
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1E293B).withValues(alpha: 0.6), // Brighter top highlight
            const Color(0xFF0D1121).withValues(alpha: 0.55), // Deeper bottom glass
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
        boxShadow: [
          // Soft blue ambient glow
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
            blurRadius: 48,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
          // Deep card shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: GestureDetector(
                    onLongPress: () => Navigator.of(context).pushNamed('/superadmin/login'),
                    child: _buildLogoIcon(size: 64, padding: 12),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: context.textStyles.h2.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to manage your clinic',
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodyMedium.copyWith(color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 36),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      PremiumTextField(
                        controller: _usernameController,
                        label: 'Username',
                        hint: 'Enter your username',
                        icon: Icons.person_outline_rounded,
                        isPassword: false,
                        validator: (v) => Validators.required(v, 'Username'),
                      ),
                      const SizedBox(height: 20),
                      PremiumTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (v) => Validators.required(v, 'Password'),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pushNamed('/auth/forgot-password'),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      child: Text(
                        'Forgot Password?',
                        style: context.textStyles.caption.copyWith(
                          color: const Color(0xFF93C5FD),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                PremiumButton(
                  onPressed: _login,
                  isLoading: authState.isLoading,
                  text: 'Sign In',
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: context.textStyles.bodyMedium.copyWith(color: const Color(0xFF94A3B8)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushNamed('/register/clinic'),
                      child: Text(
                        'Register Clinic',
                        style: context.textStyles.bodyMedium.copyWith(
                          color: const Color(0xFF93C5FD),
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

  Widget _buildAmbientBackground(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final val = _glowAnimation.value;
        return Stack(
          children: [
            // Base gradient
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF020617),
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF020617),
                    Color(0xFF081226),
                    Color(0xFF0B1730),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Radial glow 1 (Top Left / Center Left)
            Positioned(
              top: -200 + (val * 30),
              left: -200 + (val * 40),
              child: Container(
                width: 600 + (val * 80),
                height: 600 + (val * 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF3B82F6).withValues(alpha: 0.15 + (val * 0.04)),
                      const Color(0xFF1E3A8A).withValues(alpha: 0.05 + (val * 0.02)),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Radial glow 2 (Center Right / Bottom Right)
            Positioned(
              bottom: -150 - (val * 40),
              right: -150 - (val * 30),
              child: Container(
                width: 700 + (val * 100),
                height: 700 + (val * 100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF2563EB).withValues(alpha: 0.10 + (val * 0.03)),
                      const Color(0xFF1D4ED8).withValues(alpha: 0.03 + (val * 0.01)),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        message: 'Signing in...',
        child: Stack(
          children: [
            // Unified animated background
            Positioned.fill(
              child: _buildAmbientBackground(context),
            ),
            // Screen content
            Positioned.fill(
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    if (width >= 1100) {
                      // Desktop Layout
                      return Row(
                        children: [
                          Expanded(flex: 11, child: _buildBrandingPanel(context, isMobileLayout: false)),
                          Expanded(
                            flex: 13,
                            child: Center(
                              child: SingleChildScrollView(
                                child: FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: SlideTransition(
                                    position: _slideAnimation,
                                    child: _buildLoginCard(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Tablet and Mobile Layout
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: SlideTransition(
                                  position: _slideAnimation,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: width >= 700 ? 60 : 20),
                                    child: _buildLoginCard(context),
                                  ),
                                ),
                              ),
                            ),
                            _buildBrandingPanel(context, isMobileLayout: true),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// PREMIUM SUPPORTING WIDGETS

class PremiumTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final String? Function(String?) validator;
  final bool isLast;
  final bool obscureText;
  final VoidCallback? onTogglePassword;

  const PremiumTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.isPassword,
    required this.validator,
    this.isLast = false,
    this.obscureText = false,
    this.onTogglePassword,
  });

  @override
  State<PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<PremiumTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (_isFocused)
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
        child: TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          validator: widget.validator,
          textInputAction: widget.isLast ? TextInputAction.done : TextInputAction.next,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            labelStyle: TextStyle(
              color: _isFocused
                  ? const Color(0xFF60A5FA)
                  : (_isHovered ? Colors.white70 : Colors.white38),
            ),
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
            prefixIcon: Icon(
              widget.icon,
              color: _isFocused
                  ? const Color(0xFF60A5FA)
                  : (_isHovered ? Colors.white54 : Colors.white38),
              size: 18,
            ),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      widget.obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: _isFocused
                          ? const Color(0xFF60A5FA)
                          : (_isHovered ? Colors.white54 : Colors.white38),
                      size: 18,
                    ),
                    onPressed: widget.onTogglePassword,
                  )
                : null,
            filled: true,
            fillColor: _isFocused
                ? const Color(0xFF1E293B).withValues(alpha: 0.3)
                : (_isHovered ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.02)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: _isHovered ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF3B82F6),
                width: 1.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 0.8,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.redAccent,
                width: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final String text;

  const PremiumButton({
    super.key,
    required this.onPressed,
    required this.isLoading,
    required this.text,
  });

  @override
  State<PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<PremiumButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: _isHovered
                  ? [const Color(0xFF4F46E5), const Color(0xFF3B82F6)]
                  : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: _isHovered ? 0.35 : 0.2),
                blurRadius: _isHovered ? 20 : 12,
                spreadRadius: _isHovered ? 1 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: EdgeInsets.zero,
            ),
            onPressed: widget.isLoading ? null : widget.onPressed,
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.text,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}