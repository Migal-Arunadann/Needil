import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/validators.dart';
import '../providers/appointment_provider.dart';
import '../models/appointment_model.dart';

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

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill from call-by placeholder
    _nameCtrl.text = widget.appointment.patientName ?? '';
    _phoneCtrl.text = widget.appointment.patientPhone ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    _allergiesCtrl.dispose();
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
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Patient consent is required to proceed.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(appointmentServiceProvider);

      // Create patient record
      final patient = await service.createPatient(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        doctorId: widget.appointment.doctorId,
        clinicId: widget.appointment.clinicId,
        dateOfBirth: _dobCtrl.text.isNotEmpty ? _dobCtrl.text : null,
        address: _addressCtrl.text.isNotEmpty ? _addressCtrl.text : null,
        emergencyContact:
            _emergencyCtrl.text.isNotEmpty ? _emergencyCtrl.text : null,
        allergiesConditions:
            _allergiesCtrl.text.isNotEmpty ? _allergiesCtrl.text : null,
      );

      // Link patient to appointment and set in_progress
      await service.linkPatient(widget.appointment.id, patient.id);

      // Refresh appointment list
      ref.read(appointmentListProvider.notifier).loadAppointments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Patient registered & appointment started!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
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
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child:
                            Text('Patient Details', style: AppTextStyles.h2)),
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
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.info, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Collect patient information as they arrive for their appointment.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.info, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Required fields
                Text('Required Information',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textSecondary)),
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

                const SizedBox(height: 24),

                // Optional fields
                Text('Optional Information',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _pickDob,
                  child: AbsorbPointer(
                    child: AppTextField(
                      controller: _dobCtrl,
                      label: 'Date of Birth',
                      prefixIcon: Icon(Icons.cake_outlined, color: AppColors.textHint),
                      hint: 'YYYY-MM-DD',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _addressCtrl,
                  label: 'Address',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.textHint),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _emergencyCtrl,
                  label: 'Emergency Contact',
                  prefixIcon: Icon(Icons.emergency_outlined, color: AppColors.textHint),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _allergiesCtrl,
                  label: 'Allergies / Conditions',
                  prefixIcon: Icon(Icons.warning_amber_rounded, color: AppColors.textHint),
                  maxLines: 2,
                ),

                const SizedBox(height: 24),

                // Consent checkbox
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _consentGiven
                            ? AppColors.success
                            : AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _consentGiven,
                        onChanged: (v) =>
                            setState(() => _consentGiven = v ?? false),
                        activeColor: AppColors.success,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
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

                // Submit
                AppButton(
                  label: 'Register & Start Session',
                  isLoading: _isSubmitting,
                  icon: Icons.check_circle_outline_rounded,
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
