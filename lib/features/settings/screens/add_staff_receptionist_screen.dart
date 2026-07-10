import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/core/theme/app_theme.dart';


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
    AppToast.show(msg, type: ToastType.error);
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

  Widget _responsiveRow(Widget left, Widget right, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          const SizedBox(height: 20),
          right,
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
            onPressed: () => Navigator.pop(context, false),
          ),
          title: Text('Add Receptionist', style: context.textStyles.h4),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              final mainBody = Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.info.withValues(alpha: 0.1),
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
                            child: Icon(Icons.support_agent_rounded, color: context.colors.info, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Receptionist Details', style: context.textStyles.label.copyWith(fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(
                                  'Receptionists can manage appointments but cannot access medical records.',
                                  style: context.textStyles.caption.copyWith(color: context.colors.textHint, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Name & Username
                    _responsiveRow(
                      AppTextField(
                        label: 'Full Name',
                        hint: 'e.g. Priya Sharma',
                        controller: _nameCtrl,
                        validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                        prefixIcon: Icon(Icons.person_outline_rounded, color: context.colors.textHint),
                        textInputAction: TextInputAction.next,
                      ),
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
                            prefixIcon: Icon(Icons.alternate_email_rounded, color: context.colors.textHint),
                            textInputAction: TextInputAction.next,
                          ),
                          if (_isCheckingUsername)
                            Positioned(
                              right: 16,
                              top: 40,
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary),
                              ),
                            ),
                        ],
                      ),
                      isDesktop,
                    ),
                    const SizedBox(height: 20),

                    // Phone & Password
                    _responsiveRow(
                      AppTextField(
                        label: 'Phone (optional)',
                        hint: 'Contact number',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icon(Icons.phone_outlined, color: context.colors.textHint),
                        textInputAction: TextInputAction.next,
                      ),
                      AppTextField(
                        label: 'Password',
                        hint: 'Min 8 characters',
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        validator: (v) => v == null || v.length < 8 ? 'Password must be at least 8 characters' : null,
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: context.colors.textHint),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          child: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: context.colors.textHint, size: 20),
                        ),
                        textInputAction: TextInputAction.done,
                      ),
                      isDesktop,
                    ),
                    
                    const SizedBox(height: 40),

                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isDesktop ? 320 : double.infinity),
                        child: AppButton(
                          label: 'Add Receptionist',
                          onPressed: _submit,
                          isLoading: _loading,
                          icon: Icons.add_circle_outline_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );

              if (isDesktop) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.shadowColor.withValues(alpha: 0.2),
                              blurRadius: 32,
                              spreadRadius: 4,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: mainBody,
                      ),
                    ),
                  ),
                );
              } else {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: mainBody,
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
