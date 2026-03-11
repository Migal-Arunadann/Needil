import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';

/// Clinic Registration — Step 1: Clinic details (name, username, password).
class ClinicStep1Screen extends ConsumerStatefulWidget {
  const ClinicStep1Screen({super.key});

  @override
  ConsumerState<ClinicStep1Screen> createState() => _ClinicStep1ScreenState();
}

class _ClinicStep1ScreenState extends ConsumerState<ClinicStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pushNamed(
      '/register/clinic/step2',
      arguments: {
        'clinic_name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Clinic Registration', style: AppTextStyles.h4),
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
                const SizedBox(height: 8),
                _buildStepIndicator(1, 3),
                const SizedBox(height: 24),
                Text('Clinic Details', style: AppTextStyles.h2),
                const SizedBox(height: 8),
                Text(
                  'Enter your clinic or hospital information',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                AppTextField(
                  label: 'Clinic / Hospital Name',
                  hint: 'e.g. City Health Clinic',
                  controller: _nameController,
                  validator: (v) => Validators.required(v, 'Clinic name'),
                  prefixIcon: const Icon(Icons.business_rounded,
                      color: AppColors.textHint),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Username',
                  hint: 'Choose a unique username',
                  controller: _usernameController,
                  validator: (v) =>
                      Validators.minLength(v, 3, 'Username'),
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      color: AppColors.textHint),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Password',
                  hint: 'Min. 8 characters',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: Validators.password,
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
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  validator: (v) => Validators.confirmPassword(
                      v, _passwordController.text),
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.textHint),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textHint,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 36),
                AppButton(label: 'Next', onPressed: _next, icon: Icons.arrow_forward_rounded),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final step = i + 1;
        final isActive = step <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: step < total ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
