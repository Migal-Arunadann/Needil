import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/location_fields.dart';
import '../../../core/utils/validators.dart';
import '../providers/appointment_provider.dart';
import '../models/appointment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patients/models/patient_model.dart';

/// Screen shown when a call-by patient arrives — collect full details
/// and link the patient record to the appointment.
class PatientInfoScreen extends ConsumerStatefulWidget {
  final AppointmentModel appointment;

  const PatientInfoScreen({super.key, required this.appointment});

  @override
  ConsumerState<PatientInfoScreen> createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends ConsumerState<PatientInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _consentGiven = false;
  String? _selectedGender;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.appointment.patientName ?? '';
    _phoneCtrl.text = widget.appointment.patientPhone ?? '';
    // Pre-fill city from clinic profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final clinic = ref.read(authProvider).clinic;
      if (clinic?.city != null && clinic!.city!.isNotEmpty && _cityCtrl.text.isEmpty) {
        _cityCtrl.text = clinic.city!;
      }
      if (clinic?.pin != null && clinic!.pin!.isNotEmpty && _pincodeCtrl.text.isEmpty) {
        _pincodeCtrl.text = clinic.pin!;
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _pincodeCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dobCtrl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select gender.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Patient consent is required to proceed.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(appointmentServiceProvider);
      final phone = _phoneCtrl.text.trim();

      String? dobForStorage;
      if (_dobCtrl.text.isNotEmpty) {
        final parts = _dobCtrl.text.split('/');
        if (parts.length == 3) {
          dobForStorage = '${parts[2]}-${parts[1]}-${parts[0]}';
        } else {
          dobForStorage = _dobCtrl.text;
        }
      }

      // ── Dedup: reuse existing patient with the same phone number ──
      PatientModel? existingPatient;
      try {
        final pb = ref.read(pocketbaseProvider);
        final result = await pb.collection(PBCollections.patients).getList(
          filter: 'phone = "$phone"',
          perPage: 1,
        );
        if (result.items.isNotEmpty) {
          existingPatient = PatientModel.fromRecord(result.items.first);
        }
      } catch (_) {}

      final PatientModel patient;
      if (existingPatient != null) {
        patient = existingPatient;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Returning patient "${existingPatient.fullName}" linked ✓'),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } else {
        patient = await service.createPatient(
          fullName: _nameCtrl.text.trim(),
          phone: phone,
          doctorId: widget.appointment.doctorId,
          clinicId: widget.appointment.clinicId,
          dateOfBirth: dobForStorage,
          gender: _selectedGender,
          city: _cityCtrl.text.isNotEmpty ? _cityCtrl.text : null,
          area: _areaCtrl.text.isNotEmpty ? _areaCtrl.text : null,
          address: _addressCtrl.text.isNotEmpty ? _addressCtrl.text : null,
          pincode: _pincodeCtrl.text.isNotEmpty ? _pincodeCtrl.text : null,
          emergencyContact:
              _emergencyCtrl.text.isNotEmpty ? _emergencyCtrl.text : null,
        );
      }

      await service.linkPatient(widget.appointment.id, patient.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();

      if (mounted) {
        if (existingPatient == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Patient registered!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
        }
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Patient Details', style: AppTextStyles.h2)),
                  ],
                ),
                const SizedBox(height: 24),

                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Collect patient information as they arrive for their appointment.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.info, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Required ──────────────────────────────────────────────
                Text('Required Information',
                    style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),

                AppTextField(
                  controller: _nameCtrl,
                  label: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textHint),
                  validator: Validators.required,
                ),
                const SizedBox(height: 14),

                AppTextField(
                  controller: _phoneCtrl,
                  label: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textHint),
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 14),

                // Gender — mandatory
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gender *', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedGender == null ? AppColors.border : AppColors.primary,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedGender,
                          isExpanded: true,
                          hint: Text('Select Gender *',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint)),
                          items: ['Male', 'Female', 'Other']
                              .map((g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g, style: AppTextStyles.bodyMedium),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedGender = v),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Location fields (pincode auto-fill) ──
                LocationFields(
                  pincodeCtrl: _pincodeCtrl,
                  countryCtrl: _countryCtrl,
                  stateCtrl: _stateCtrl,
                  cityCtrl: _cityCtrl,
                  areaCtrl: _areaCtrl,
                  allRequired: true,
                ),
                const SizedBox(height: 14),

                // Full address — optional
                AppTextField(
                  controller: _addressCtrl,
                  label: 'Full Address (Optional)',
                  prefixIcon: Icon(Icons.home_outlined, color: AppColors.textHint),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // ── Optional ──────────────────────────────────────────────
                Text('Optional Information',
                    style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),

                AppTextField(
                  controller: _dobCtrl,
                  label: 'Date of Birth (Optional)',
                  prefixIcon: Icon(Icons.cake_outlined, color: AppColors.textHint),
                  hint: 'DD/MM/YYYY',
                  keyboardType: TextInputType.number,
                  inputFormatters: [_DateInputFormatter()],
                  suffixIcon: GestureDetector(
                    onTap: _pickDob,
                    child: Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 14),

                AppTextField(
                  controller: _emergencyCtrl,
                  label: 'Emergency Contact (Optional)',
                  prefixIcon: Icon(Icons.emergency_outlined, color: AppColors.textHint),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                const SizedBox(height: 24),

                // Consent
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _consentGiven ? AppColors.success : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _consentGiven,
                        onChanged: (v) => setState(() => _consentGiven = v ?? false),
                        activeColor: AppColors.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      Expanded(
                        child: Text(
                          'Patient consents to collection and processing of their health data as per DPDP Act.',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                AppButton(
                  label: 'Register',
                  isLoading: _isSubmitting,
                  icon: Icons.how_to_reg_rounded,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    final trimmed = digitsOnly.length > 8 ? digitsOnly.substring(0, 8) : digitsOnly;
    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(trimmed[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
