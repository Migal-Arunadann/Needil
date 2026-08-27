import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pms_app/core/constants/pb_collections.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/core/services/auth_service.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/date_picker_helper.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/core/widgets/location_fields.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';

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
  final _phoneCtrl = TextEditingController();

  // Clinic-specific
  final _bedCountCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _patientIdPrefixCtrl = TextEditingController();

  // Doctor-specific
  final _ageCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  // Image handling (Web + Mobile compatible)
  Uint8List? _pickedBytes;
  String? _pickedFileName;
  File? _localFile;
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
      _countryCtrl.text = 'India';
      _locationCtrl.text = c.location ?? '';
      _patientIdPrefixCtrl.text = c.patientIdPrefix ?? '';
      _existingPhotoUrl = c.logoUrl;
    } else if (auth.role == UserRole.doctor && auth.doctor != null) {
      final d = auth.doctor!;
      _nameCtrl.text = d.name;
      _emailCtrl.text = d.email ?? '';
      _ageCtrl.text = d.age.toString();
      _phoneCtrl.text = d.phone ?? '';
      _dobCtrl.text = d.dateOfBirth ?? '';
      _existingPhotoUrl = d.photoUrl;
    } else if (auth.role == UserRole.receptionist && auth.receptionist != null) {
      final r = auth.receptionist!;
      _nameCtrl.text = r.name;
      _phoneCtrl.text = r.phone ?? '';
      _existingPhotoUrl = r.photoUrl;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bedCountCtrl.dispose();
    _addressCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _countryCtrl.dispose();
    _locationCtrl.dispose();
    _patientIdPrefixCtrl.dispose();
    _ageCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 65);
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _pickedBytes = bytes;
          _pickedFileName = picked.name;
          if (!kIsWeb) {
            _localFile = File(picked.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to pick image: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _pickDob() async {
    final picked = await showAppDatePicker(
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

    final navigator = Navigator.of(context);
    setState(() => _isLoading = true);

    try {
      final pb = ref.read(pocketbaseProvider);
      final auth = ref.read(authProvider);

      if (auth.role == UserRole.clinic && auth.clinic != null) {
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

        if (_pickedBytes != null) {
          final files = [
            http.MultipartFile.fromBytes(
              'logo',
              _pickedBytes!,
              filename: _pickedFileName ?? 'logo.jpg',
            )
          ];
          await pb.collection(PBCollections.clinics).update(
            auth.clinic!.id,
            body: body,
            files: files,
          );
        } else {
          await pb.collection(PBCollections.clinics).update(auth.clinic!.id, body: body);
        }
      } else if (auth.role == UserRole.receptionist && auth.receptionist != null) {
        final body = {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
        };

        if (_pickedBytes != null) {
          final files = [
            http.MultipartFile.fromBytes(
              'photo',
              _pickedBytes!,
              filename: _pickedFileName ?? 'receptionist.jpg',
            )
          ];
          await pb.collection(PBCollections.receptionists).update(
            auth.receptionist!.id,
            body: body,
            files: files,
          );
        } else {
          await pb.collection(PBCollections.receptionists).update(
            auth.receptionist!.id,
            body: body,
          );
        }
      } else if (auth.role == UserRole.doctor && auth.doctor != null) {
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
          'phone': _phoneCtrl.text.trim(),
          if (dobStorage != null && dobStorage.isNotEmpty) 'dob': dobStorage,
        };

        if (_pickedBytes != null) {
          final files = [
            http.MultipartFile.fromBytes(
              'photo',
              _pickedBytes!,
              filename: _pickedFileName ?? 'doctor.jpg',
            )
          ];
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
        AppToast.show('Profile updated successfully ✓', type: ToastType.success);
        navigator.pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to update profile: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ImageProvider? _resolveAvatarImage(bool isClinic) {
    if (_pickedBytes != null) {
      return MemoryImage(_pickedBytes!);
    }
    if (_localFile != null && !kIsWeb) {
      return FileImage(_localFile!);
    }
    if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      return NetworkImage(ImageHelper.getSecureUrl(_existingPhotoUrl!));
    }
    return null;
  }

  IconData _roleIcon(AuthState auth) {
    if (auth.role == UserRole.clinic) return Icons.business_rounded;
    if (auth.role == UserRole.receptionist) return Icons.support_agent_rounded;
    return Icons.person_rounded;
  }

  String _pageTitle(AuthState auth) {
    if (auth.role == UserRole.clinic) return 'Edit Clinic Profile';
    if (auth.role == UserRole.receptionist) return 'Edit Receptionist Profile';
    return 'Edit Doctor Profile';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isClinic = auth.role == UserRole.clinic;
    final isReceptionist = auth.role == UserRole.receptionist;
    final isDoctor = auth.role == UserRole.doctor;
    final avatarImage = _resolveAvatarImage(isClinic);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            },
          ),
          title: Text(_pageTitle(auth), style: context.textStyles.h4),
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
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 104,
                              height: 104,
                              decoration: BoxDecoration(
                                color: context.colors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.colors.primary.withValues(alpha: 0.2),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colors.shadowColor.withValues(alpha: 0.1),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: avatarImage != null
                                    ? Image(
                                        image: avatarImage,
                                        width: 104,
                                        height: 104,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Icon(
                                          _roleIcon(auth),
                                          size: 44,
                                          color: context.colors.primary.withValues(alpha: 0.6),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: context.colors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: context.colors.background, width: 2.5),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ══════════════════════════════════════════
                    //  RECEPTIONIST FIELDS
                    // ══════════════════════════════════════════
                    if (isReceptionist) ...[
                      _sectionLabel('Front Desk Staff Profile'),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        prefixIcon: Icon(Icons.badge_rounded, color: context.colors.textHint),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        hint: 'e.g. 9876543210',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icon(Icons.phone_outlined, color: context.colors.textHint),
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel('Account Details'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.colors.cardBackgroundAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Column(
                          children: [
                            _readOnlyFieldRow(
                              icon: Icons.alternate_email_rounded,
                              label: 'Username',
                              value: '@${auth.receptionist?.username ?? '—'}',
                            ),
                            Divider(height: 16, color: context.colors.divider),
                            _readOnlyFieldRow(
                              icon: Icons.tag_rounded,
                              label: 'Staff ID',
                              value: auth.receptionist?.receptionistId ?? '—',
                            ),
                            Divider(height: 16, color: context.colors.divider),
                            _readOnlyFieldRow(
                              icon: Icons.shield_rounded,
                              label: 'Role',
                              value: 'Front Desk / Receptionist',
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ══════════════════════════════════════════
                    //  CLINIC FIELDS
                    // ══════════════════════════════════════════
                    if (isClinic) ...[
                      _sectionLabel('Clinic Information'),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Clinic Name',
                        prefixIcon: Icon(Icons.business_rounded, color: context.colors.textHint),
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
                      AppTextField(
                        controller: _phoneCtrl,
                        label: 'Clinic Phone Number',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icon(Icons.phone_outlined, color: context.colors.textHint),
                      ),
                      const SizedBox(height: 14),
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
                    ],

                    // ══════════════════════════════════════════
                    //  DOCTOR FIELDS
                    // ══════════════════════════════════════════
                    if (isDoctor) ...[
                      _sectionLabel('Doctor Information'),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Doctor Name',
                        prefixIcon: Icon(Icons.person_rounded, color: context.colors.textHint),
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
                        controller: _phoneCtrl,
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
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Container(
                        padding: const EdgeInsets.all(36),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: context.colors.border.withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: context.colors.shadowColor.withValues(alpha: 0.15),
                              blurRadius: 32,
                              spreadRadius: 2,
                              offset: const Offset(0, 12),
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

  Widget _readOnlyFieldRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: context.textStyles.caption.copyWith(fontWeight: FontWeight.w500),
        ),
        const Spacer(),
        Text(
          value,
          style: context.textStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: context.colors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: context.textStyles.h4),
      ],
    );
  }
}
