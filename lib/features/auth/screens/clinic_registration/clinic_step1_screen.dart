import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/location_fields.dart';
import '../../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

import 'dart:async';

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
  String? _lockedEmail;
  final _pincodeController = TextEditingController();
  final _countryController = TextEditingController();
  final _stateController = TextEditingController();
  final _cityController = TextEditingController();
  final _areaController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isChangingEmail = false;

  Timer? _debounce;
  bool _isCheckingUsername = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final value = _usernameController.text;
    
    if (value.length < 3) {
      if (mounted) setState(() => _usernameError = null);
      return;
    }

    if (mounted) setState(() => _isCheckingUsername = true);
    
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final authService = ref.read(authProvider.notifier).authService;
      final exists = await authService.checkUsernameExists(value);
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _usernameError = exists ? 'This username is already taken' : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pincodeController.dispose();
    _countryController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _changeEmail(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.surface,
        title: const Text('Change Email?'),
        content: const Text(
          'This will remove the current email from our system and take you back to start. You can then register with a different email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep This Email'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Change Email',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isChangingEmail = true);
    await ref.read(authProvider.notifier).deleteShellAndRestart();
    if (!mounted) return;

    // Pop all the way back to the root — app.dart will render LoginScreen
    // because auth state is now unauthenticated.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _next() {
    if (_usernameError != null) return;
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pushNamed(
      '/register/clinic/step2',
      arguments: {
        'clinic_name': _nameController.text.trim(),
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'email': _lockedEmail ?? '',
        'pincode': _pincodeController.text.trim(),
        'country': _countryController.text.trim(),
        'state': _stateController.text.trim(),
        'city': _cityController.text.trim(),
        'area': _areaController.text.trim(),
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
              _buildStepIndicator(1, 5),
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
                Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    AppTextField(
                      label: 'Username',
                      hint: 'Choose a unique username',
                      controller: _usernameController,
                      errorText: _usernameError,
                      validator: (v) {
                        if (_usernameError != null) return _usernameError;
                        return Validators.minLength(v, 3, 'Username');
                      },
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          color: AppColors.textHint),
                      textInputAction: TextInputAction.next,
                    ),
                    if (_isCheckingUsername)
                      const Positioned(
                        right: 16,
                        top: 40,
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Show the email they used to verify
                Consumer(builder: (context, ref, _) {
                  final auth = ref.watch(authProvider);
                  _lockedEmail = auth.clinic?.email;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'Email Address',
                        hint: 'Verified',
                        controller: TextEditingController(text: _lockedEmail ?? 'Verified Email'),
                        enabled: false,
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                      ),
                      const SizedBox(height: 6),
                      // Change email — deletes shell record and restarts
                      Align(
                        alignment: Alignment.centerRight,
                        child: _isChangingEmail
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : GestureDetector(
                                onTap: () => _changeEmail(ref),
                                child: Text(
                                  'Use a different email?',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primary,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Set Password',
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

                // ── Clinic Location ──────────────────────────────────
                Text('Clinic Location', style: AppTextStyles.h3),
                const SizedBox(height: 6),
                Text(
                  'Required for patient records and scheduling',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                LocationFields(
                  pincodeCtrl: _pincodeController,
                  countryCtrl: _countryController,
                  stateCtrl: _stateController,
                  cityCtrl: _cityController,
                  areaCtrl: _areaController,
                  allRequired: true,
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
