import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../auth/providers/auth_provider.dart';

class AddStaffReceptionistScreen extends ConsumerStatefulWidget {
  const AddStaffReceptionistScreen({super.key});

  @override
  ConsumerState<AddStaffReceptionistScreen> createState() => _AddStaffReceptionistScreenState();
}

class _AddStaffReceptionistScreenState extends ConsumerState<AddStaffReceptionistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  
  bool _obscurePassword = true;
  bool _loading = false;
  
  Timer? _debounce;
  bool _isCheckingUsername = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    _usernameCtrl.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final value = _usernameCtrl.text;

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
          _usernameError = exists ? 'Username is already taken' : null;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) return;
    if (_usernameError != null) {
      _showSnack(_usernameError!);
      return;
    }

    setState(() => _loading = true);

    try {
      final authService = ref.read(authProvider.notifier).authService;
      await authService.addReceptionist({
        'name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
      });
      _showSnack('Receptionist added successfully!', isError: false);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Failed to add receptionist: ${e.toString()}');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context, false),
          ),
          title: Text('Add Receptionist', style: AppTextStyles.h4),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.support_agent_rounded, color: AppColors.info, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Receptionist Details', style: AppTextStyles.label.copyWith(fontSize: 15)),
                              const SizedBox(height: 2),
                              Text(
                                'Receptionists can manage appointments but cannot access medical records.',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  AppTextField(
                    label: 'Full Name',
                    hint: 'e.g. Priya Sharma',
                    controller: _nameCtrl,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textHint),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      AppTextField(
                        label: 'Username',
                        hint: 'Choose a login username',
                        controller: _usernameCtrl,
                        errorText: _usernameError,
                        validator: (v) {
                          if (_usernameError != null) return _usernameError;
                          if (v == null || v.length < 3) return 'Min 3 characters';
                          return null;
                        },
                        prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppColors.textHint),
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

                  AppTextField(
                    label: 'Phone (optional)',
                    hint: 'Contact number',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textHint),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),

                  AppTextField(
                    label: 'Password',
                    hint: 'Min 8 characters',
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    validator: (v) => v == null || v.length < 8 ? 'Password must be at least 8 characters' : null,
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.textHint, size: 20),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                  
                  const SizedBox(height: 40),

                  AppButton(
                    label: 'Add Receptionist',
                    onPressed: _submit,
                    isLoading: _loading,
                    icon: Icons.add_circle_outline_rounded,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
