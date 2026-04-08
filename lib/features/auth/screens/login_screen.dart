import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_overlay.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';

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
  UserRole _selectedRole = UserRole.clinic;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
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
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    switch (_selectedRole) {
      case UserRole.clinic:
        ref.read(authProvider.notifier).loginClinic(username, password);
        break;
      case UserRole.doctor:
        ref.read(authProvider.notifier).loginDoctor(username, password);
        break;
      case UserRole.receptionist:
        ref.read(authProvider.notifier).loginReceptionist(username, password);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for errors
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LoadingOverlay(
        isLoading: authState.isLoading,
        message: 'Signing in...',
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  _buildHeader(),
                  const SizedBox(height: 40),
                  _buildRoleToggle(),
                  const SizedBox(height: 32),
                  _buildLoginForm(),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Sign In',
                    onPressed: _login,
                    isLoading: authState.isLoading,
                    icon: Icons.login_rounded,
                  ),
                  const SizedBox(height: 24),
                  _buildRegisterLink(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_hospital_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 20),
        Text('Welcome Back', style: AppTextStyles.h1),
        const SizedBox(height: 8),
        Text(
          'Sign in to manage your practice',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _roleTab('Clinic', UserRole.clinic, Icons.business_rounded),
          _roleTab('Doctor', UserRole.doctor, Icons.person_rounded),
          _roleTab('Staff', UserRole.receptionist, Icons.support_agent_rounded),
        ],
      ),
    );
  }

  Widget _roleTab(String label, UserRole role, IconData icon) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.buttonMedium.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppTextField(
            label: 'Username',
            hint: 'Enter your username',
            controller: _usernameController,
            validator: (v) => Validators.required(v, 'Username'),
            prefixIcon: const Icon(Icons.person_outline_rounded,
                color: AppColors.textHint),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Password',
            hint: 'Enter your password',
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (v) => Validators.required(v, 'Password'),
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: AppColors.textHint),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textHint,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: () {
            // Navigate directly to clinic registration (no role selection)
            Navigator.of(context).pushNamed('/register/clinic');
          },
          child: Text(
            'Register Clinic',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
