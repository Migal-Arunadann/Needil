import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _ageCtrl = TextEditingController(); // Doctor
  final _bedCountCtrl = TextEditingController(); // Clinic

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.role == UserRole.clinic && auth.clinic != null) {
      _nameCtrl.text = auth.clinic!.name;
      _emailCtrl.text = auth.clinic!.email ?? '';
      _bedCountCtrl.text = auth.clinic!.bedCount.toString();
    } else if (auth.role == UserRole.doctor && auth.doctor != null) {
      _nameCtrl.text = auth.doctor!.name;
      _emailCtrl.text = auth.doctor!.email ?? '';
      _ageCtrl.text = auth.doctor!.age.toString();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _ageCtrl.dispose();
    _bedCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);

      if (auth.role == UserRole.clinic) {
        await pb.collection(PBCollections.clinics).update(auth.clinic!.id, body: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'bed_count': int.tryParse(_bedCountCtrl.text.trim()) ?? auth.clinic!.bedCount,
        });
      } else {
        await pb.collection(PBCollections.doctors).update(auth.doctor!.id, body: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'age': int.tryParse(_ageCtrl.text.trim()) ?? auth.doctor!.age,
        });
      }

      await ref.read(authProvider.notifier).restoreSession();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
          ),
          title: Text('Edit Profile', style: AppTextStyles.h4),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _nameCtrl,
                    label: isClinic ? 'Clinic Name' : 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textHint),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 16),
                  if (isClinic)
                    AppTextField(
                      controller: _bedCountCtrl,
                      label: 'Bed Count',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.bed_outlined, color: AppColors.textHint),
                    )
                  else
                    AppTextField(
                      controller: _ageCtrl,
                      label: 'Age',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.textHint),
                    ),
                  const SizedBox(height: 32),
                  AppButton(
                    label: 'Save Changes',
                    isLoading: _isLoading,
                    icon: Icons.save_rounded,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
