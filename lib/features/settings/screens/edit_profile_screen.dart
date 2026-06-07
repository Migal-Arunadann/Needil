import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/location_fields.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/constants/pb_collections.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/services/auth_service.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import '../../../core/utils/image_helper.dart';


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
  final _countryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _patientIdPrefixCtrl = TextEditingController();
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
      _countryCtrl.text = 'India'; // default; update when country saved to PB model
      _locationCtrl.text = c.location ?? '';
      _patientIdPrefixCtrl.text = c.patientIdPrefix ?? '';
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
    _countryCtrl.dispose();
    _locationCtrl.dispose();
    _patientIdPrefixCtrl.dispose();
    _ageCtrl.dispose();
    _doctorPhoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isLogo) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (picked != null && mounted) {
      final compressed = await ImageHelper.compressToWebP(picked);
      if (compressed != null && mounted) {
        setState(() {
          if (isLogo) {
            _logoFile = File(compressed.path);
          } else {
            _photoFile = File(compressed.path);
          }
        });
      }
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1980),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _dobCtrl.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    // Capture navigator before async gap — fixes Vivo/iQOO devices
    final navigator = Navigator.of(context);

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
          'patient_id_prefix': _patientIdPrefixCtrl.text.trim().toUpperCase(),
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
            backgroundColor: context.colors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: context.colors.error,
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
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
            onPressed: () { FocusScope.of(context).unfocus(); Navigator.pop(context); },
          ),
          title: Text('Edit Profile', style: context.textStyles.h4),
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
                    // ── Photo / Logo Picker ──
                    Center(
                      child: GestureDetector(
                        onTap: kIsWeb ? null : () => _pickImage(isClinic),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: context.colors.surface,
                              backgroundImage: isClinic
                                  ? (!kIsWeb && _logoFile != null ? FileImage(_logoFile!) : (_existingLogoUrl != null ? NetworkImage(_existingLogoUrl!) as ImageProvider : null))
                                  : (!kIsWeb && _photoFile != null ? FileImage(_photoFile!) : (_existingPhotoUrl != null ? NetworkImage(_existingPhotoUrl!) as ImageProvider : null)),
                              child: (isClinic ? (_logoFile == null && _existingLogoUrl == null) : (_photoFile == null && _existingPhotoUrl == null))
                                  ? Icon(isClinic ? Icons.business_rounded : Icons.person_rounded, size: 40, color: context.colors.textHint)
                                  : null,
                            ),
                            if (!kIsWeb)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: context.colors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: context.colors.background, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    _sectionLabel(isClinic ? 'Clinic Information' : 'Doctor Information'),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _nameCtrl,
                      label: isClinic ? 'Clinic Name' : 'Doctor Name',
                      prefixIcon: Icon(isClinic ? Icons.business_rounded : Icons.person_rounded, color: context.colors.textHint),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _emailCtrl,
                      label: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined, color: context.colors.textHint),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),

                    if (isClinic) ...[
                      // ── Clinic-specific ──
                      AppTextField(
                        controller: _bedCountCtrl,
                        label: 'Bed Count',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icon(Icons.bed_outlined, color: context.colors.textHint),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _patientIdPrefixCtrl,
                        label: 'Patient ID Prefix (e.g. HSK)',
                        hint: 'Auto-generates HSK-001, HSK-002...',
                        prefixIcon: Icon(Icons.badge_outlined, color: context.colors.textHint),
                      ),
                      const SizedBox(height: 14),
                      LocationFields(
                        countryCtrl: _countryCtrl,
                        stateCtrl: _stateCtrl,
                        cityCtrl: _cityCtrl,
                        areaCtrl: _areaCtrl,
                        pincodeCtrl: _pinCtrl,
                        allRequired: false,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _locationCtrl,
                        label: 'Clinic GMap Link',
                        prefixIcon: Icon(Icons.place_outlined, color: context.colors.textHint),
                      ),
                    ] else ...[ 
                      // ── Doctor-specific ──
                      AppTextField(
                        controller: _ageCtrl,
                        label: 'Age',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icon(Icons.cake_outlined, color: context.colors.textHint),
                      ),
                      const SizedBox(height: 24),
                      _sectionLabel('Personal Details'),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _doctorPhoneCtrl,
                        label: 'Phone Number',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icon(Icons.phone_outlined, color: context.colors.textHint),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _dobCtrl,
                        label: 'Date of Birth (DD/MM/YYYY)',
                        prefixIcon: Icon(Icons.calendar_today_rounded, color: context.colors.textHint, size: 18),
                        readOnly: true,
                        onTap: _pickDob,
                        suffixIcon: GestureDetector(
                          onTap: _pickDob,
                          child: Icon(Icons.calendar_month_rounded, color: context.colors.primary),
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),
                    Center(
                      child: SizedBox(
                        width: isDesktop ? 320 : double.infinity,
                        child: AppButton(
                          label: 'Save Changes',
                          isLoading: _isLoading,
                          icon: Icons.save_rounded,
                          onPressed: _save,
                        ),
                      ),
                    ),
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
                              color: Colors.black.withValues(alpha: 0.2),
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
                  padding: const EdgeInsets.all(24),
                  child: mainBody,
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(label, style: context.textStyles.h4),
      ],
    );
  }
}