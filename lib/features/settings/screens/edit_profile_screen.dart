import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Common
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Clinic-specific
  final _bedCountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  File? _logoFile;
  String? _existingLogoUrl;

  // Doctor-specific
  final _ageCtrl = TextEditingController();
  final _doctorPhoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  File? _photoFile;
  String? _existingPhotoUrl;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    if (auth.role == UserRole.clinic && auth.clinic != null) {
      final c = auth.clinic!;
      _nameCtrl.text = c.name;
      _emailCtrl.text = c.email ?? '';
      _bedCountCtrl.text = c.bedCount.toString();
      _phoneCtrl.text = c.phone ?? '';
      _addressCtrl.text = c.address ?? '';
      _areaCtrl.text = c.area ?? '';
      _cityCtrl.text = c.city ?? '';
      _stateCtrl.text = c.state ?? '';
      _pinCtrl.text = c.pin ?? '';
      _locationCtrl.text = c.location ?? '';
      _existingLogoUrl = c.logoUrl;
    } else if (auth.role == UserRole.doctor && auth.doctor != null) {
      final d = auth.doctor!;
      _nameCtrl.text = d.name;
      _emailCtrl.text = d.email ?? '';
      _ageCtrl.text = d.age.toString();
      _doctorPhoneCtrl.text = d.phone ?? '';
      _dobCtrl.text = d.dateOfBirth ?? '';
      _existingPhotoUrl = d.photoUrl;
    }
    _pinCtrl.addListener(_onPinChanged);
  }

  void _onPinChanged() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length == 6) {
      try {
        final res = await http.get(Uri.parse('https://api.postalpincode.in/pincode/$pin'));
        if (res.statusCode == 200 && mounted) {
          final data = jsonDecode(res.body);
          if (data.isNotEmpty && data[0]['Status'] == 'Success') {
            final postOffice = data[0]['PostOffice'][0];
            setState(() {
              _areaCtrl.text = postOffice['Name'] ?? _areaCtrl.text;
              _cityCtrl.text = postOffice['District'] ?? _cityCtrl.text;
              _stateCtrl.text = postOffice['State'] ?? _stateCtrl.text;
            });
          }
        }
      } catch (e) {
        // ignore network error
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _bedCountCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _locationCtrl.dispose();
    _ageCtrl.dispose();
    _doctorPhoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLogo) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() {
        if (isLogo) {
          _logoFile = File(picked.path);
        } else {
          _photoFile = File(picked.path);
        }
      });
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1980),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, surface: AppColors.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);

      if (auth.role == UserRole.clinic) {
        final body = {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'bed_count': int.tryParse(_bedCountCtrl.text.trim()) ?? auth.clinic!.bedCount,
          'phone': _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'area': _areaCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'state': _stateCtrl.text.trim(),
          'pin': _pinCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
        };

        if (_logoFile != null) {
          final files = [await http.MultipartFile.fromPath('logo', _logoFile!.path)];
          await pb.collection(PBCollections.clinics).update(
            auth.clinic!.id,
            body: body,
            files: files,
          );
        } else {
          await pb.collection(PBCollections.clinics).update(auth.clinic!.id, body: body);
        }
      } else {
        // Convert DOB to storage format if entered in DD/MM/YYYY
        String? dobStorage;
        if (_dobCtrl.text.contains('/')) {
          final parts = _dobCtrl.text.split('/');
          if (parts.length == 3) dobStorage = '${parts[2]}-${parts[1]}-${parts[0]}';
        } else {
          dobStorage = _dobCtrl.text.isNotEmpty ? _dobCtrl.text : null;
        }

        final body = {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'age': int.tryParse(_ageCtrl.text.trim()) ?? auth.doctor!.age,
          'phone': _doctorPhoneCtrl.text.trim(),
          if (dobStorage != null && dobStorage.isNotEmpty) 'dob': dobStorage,
        };

        if (_photoFile != null) {
          final files = [await http.MultipartFile.fromPath('photo', _photoFile!.path)];
          await pb.collection(PBCollections.doctors).update(
            auth.doctor!.id,
            body: body,
            files: files,
          );
        } else {
          await pb.collection(PBCollections.doctors).update(auth.doctor!.id, body: body);
        }
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
            onPressed: () { FocusScope.of(context).unfocus(); Navigator.pop(context); },
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
                  // ── Photo / Logo Picker ──
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickImage(isClinic),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.surface,
                            backgroundImage: isClinic
                                ? (_logoFile != null ? FileImage(_logoFile!) : (_existingLogoUrl != null ? NetworkImage(_existingLogoUrl!) as ImageProvider : null))
                                : (_photoFile != null ? FileImage(_photoFile!) : (_existingPhotoUrl != null ? NetworkImage(_existingPhotoUrl!) as ImageProvider : null)),
                            child: (isClinic ? (_logoFile == null && _existingLogoUrl == null) : (_photoFile == null && _existingPhotoUrl == null))
                                ? Icon(isClinic ? Icons.business_rounded : Icons.person_rounded, size: 40, color: AppColors.textHint)
                                : null,
                          ),
                          Positioned(
                            right: 0, bottom: 0,
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.background, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      isClinic ? 'Tap to upload clinic logo' : 'Tap to upload profile photo',
                      style: AppTextStyles.caption,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Core Fields ──
                  _sectionLabel('Basic Information'),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _nameCtrl,
                    label: isClinic ? 'Clinic Name' : 'Full Name',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textHint),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),

                  if (isClinic) ...[ 
                    // ── Clinic-specific ──
                    AppTextField(
                      controller: _bedCountCtrl,
                      label: 'Bed Count',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.bed_outlined, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('Contact & Location'),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _phoneCtrl,
                      label: 'Clinic Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _addressCtrl,
                      label: 'Street Address',
                      prefixIcon: const Icon(Icons.home_outlined, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _areaCtrl,
                            label: 'Area / Locality',
                            prefixIcon: const Icon(Icons.map_outlined, color: AppColors.textHint),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AppTextField(
                            controller: _cityCtrl,
                            label: 'City',
                            prefixIcon: const Icon(Icons.location_city_outlined, color: AppColors.textHint),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _stateCtrl,
                            label: 'State',
                            prefixIcon: const Icon(Icons.flag_outlined, color: AppColors.textHint),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: AppTextField(
                            controller: _pinCtrl,
                            label: 'PIN Code',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.textHint),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _locationCtrl,
                      label: 'Clinic GMap Link',
                      prefixIcon: const Icon(Icons.place_outlined, color: AppColors.textHint),
                    ),
                  ] else ...[ 
                    // ── Doctor-specific ──
                    AppTextField(
                      controller: _ageCtrl,
                      label: 'Age',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.cake_outlined, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('Personal Details'),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _doctorPhoneCtrl,
                      label: 'Phone Number',
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textHint),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _dobCtrl,
                      label: 'Date of Birth (DD/MM/YYYY)',
                      prefixIcon: const Icon(Icons.calendar_today_rounded, color: AppColors.textHint, size: 18),
                      readOnly: true,
                      onTap: _pickDob,
                      suffixIcon: GestureDetector(
                        onTap: _pickDob,
                        child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                      ),
                    ),
                  ],

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

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: AppTextStyles.h4),
      ],
    );
  }
}
