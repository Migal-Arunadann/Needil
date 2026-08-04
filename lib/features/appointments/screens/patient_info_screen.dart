import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/patient_details_form.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/features/appointments/models/appointment_model.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';
import 'package:pms_app/features/patients/screens/family_member_selection_screen.dart';
import 'package:pms_app/core/utils/validators.dart';


/// Screen shown when a call-by patient arrives — uses the shared
/// [PatientDetailsForm] to collect full details and link the patient
/// record to the appointment.
class PatientInfoScreen extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final bool allowSkipRetroactive;
  final VoidCallback? onSkipRetroactive;

  const PatientInfoScreen({
    super.key,
    required this.appointment,
    this.allowSkipRetroactive = false,
    this.onSkipRetroactive,
  });

  @override
  ConsumerState<PatientInfoScreen> createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends ConsumerState<PatientInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _dataConsentGiven = false;
  bool _privacyPolicyAccepted = false;
  String? _selectedGender;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();       // YYYY-MM-DD
  final _pincodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _personalNotesCtrl = TextEditingController();

  String? _howDidYouHear;
  bool _isNewFamilyMember = false;
  String? _selectedRelation;

  PatientModel? _existingPatient;
  bool _isRegisteredPatient = false;
  String _selectedPhoneCode = '+91';
  List<PatientModel> _matchingPatients = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.appointment.patientName ?? '';
    
    final parsed = PhoneParser.parse(widget.appointment.patientPhone);
    _selectedPhoneCode = parsed.$1;
    _phoneCtrl.text = parsed.$2;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final clinic = ref.read(authProvider).clinic;
      if (clinic?.city != null &&
          clinic!.city!.isNotEmpty &&
          _cityCtrl.text.isEmpty) {
        _cityCtrl.text = clinic.city!;
      }
      if (clinic?.pin != null &&
          clinic!.pin!.isNotEmpty &&
          _pincodeCtrl.text.isEmpty) {
        _pincodeCtrl.text = clinic.pin!;
      }

      // Check existing patients registered under this phone number on screen load
      await _checkExistingPatients();

      if (!mounted) return;
      // Mark form as partially opened
      if (!widget.appointment.patientDetailsSaved) {
        try {
          final service = ref.read(appointmentServiceProvider);
          await service.markPatientDetailsPartial(widget.appointment.id);
        } catch (_) {}
      }
    });
  }

  void _applySelectedPatient(PatientModel existing) {
    _nameCtrl.text = existing.fullName;
    final parsed = PhoneParser.parse(existing.phone);
    _selectedPhoneCode = parsed.$1;
    _phoneCtrl.text = parsed.$2;
    if (existing.dateOfBirth != null && existing.dateOfBirth!.isNotEmpty) _dobCtrl.text = existing.dateOfBirth!;
    if (existing.city != null && existing.city!.isNotEmpty) _cityCtrl.text = existing.city!;
    if (existing.area != null && existing.area!.isNotEmpty) _areaCtrl.text = existing.area!;
    if (existing.occupation != null && existing.occupation!.isNotEmpty) _occupationCtrl.text = existing.occupation!;
    if (existing.email != null && existing.email!.isNotEmpty) _emailCtrl.text = existing.email!;
    if (existing.personalNotes != null && existing.personalNotes!.isNotEmpty) _personalNotesCtrl.text = existing.personalNotes!;
    if (existing.gender != null && existing.gender!.isNotEmpty) _selectedGender = existing.gender;
    setState(() {
      _existingPatient = existing;
      _isRegisteredPatient = true;
      _isNewFamilyMember = false;
      _selectedRelation = null;
    });
  }

  void _applyNewFamilyMemberMode(PatientModel primary, {bool preserveName = false}) {
    if (primary.city != null && primary.city!.isNotEmpty) _cityCtrl.text = primary.city!;
    if (primary.area != null && primary.area!.isNotEmpty) _areaCtrl.text = primary.area!;
    if (primary.pincode != null && primary.pincode!.isNotEmpty) _pincodeCtrl.text = primary.pincode!;
    if (!preserveName) _nameCtrl.clear();
    _dobCtrl.clear();
    _occupationCtrl.clear();
    _emailCtrl.clear();
    setState(() {
      _existingPatient = null;
      _isRegisteredPatient = false;
      _isNewFamilyMember = true;
      _selectedRelation = null;
      _selectedGender = null;
    });
  }

  Future<void> _checkExistingPatients() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;

    final combined = '$_selectedPhoneCode$phone';
    final service = ref.read(appointmentServiceProvider);
    final allPatients = await service.findAllPatientsByPhone(
      combined,
      widget.appointment.doctorId,
      clinicId: widget.appointment.clinicId,
    );

    if (!mounted) return;
    
    setState(() {
      _matchingPatients = allPatients;
    });

    if (allPatients.isEmpty) return;

    // If the appointment already captured the intent to add a new family member,
    // apply it directly without showing the selection screen.
    if (widget.appointment.isNewFamilyMember) {
      _applyNewFamilyMemberMode(allPatients.first, preserveName: true);
      setState(() {
        _selectedRelation = widget.appointment.intendedRelation;
      });
      return;
    }

    // Show family member selection screen
    final result = await Navigator.push<FamilySelectionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => FamilyMemberSelectionScreen(
          patients: allPatients,
          phone: phone,
        ),
      ),
    );

    if (!mounted) return;

    if (result == null) {
      // User dismissed the dialog — close this screen to prevent inconsistent state
      Navigator.pop(context);
      return;
    }

    if (result.isNew) {
      _applyNewFamilyMemberMode(allPatients.first);
    } else if (result.selected != null) {
      _applySelectedPatient(result.selected!);
    }
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
    _occupationCtrl.dispose();
    _emailCtrl.dispose();
    _referenceCtrl.dispose();
    _personalNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture navigator before async gap — fixes Vivo/iQOO devices where
    // context-based navigation silently fails after await calls.
    final navigator = Navigator.of(context);

    if (_selectedGender == null) {
      AppToast.show('Please select gender.', type: ToastType.error);
      return;
    }

    if (_dobCtrl.text.isEmpty) {
      AppToast.show('Date of birth is required.', type: ToastType.error);
      return;
    }

    if (!_dataConsentGiven || !_privacyPolicyAccepted) {
      AppToast.show('Both consent checkboxes are required to proceed.', type: ToastType.error);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(appointmentServiceProvider);
      final phone = '$_selectedPhoneCode${_phoneCtrl.text.trim()}';

      // Auto-calculate age from DoB
      final dob = DateTime.tryParse(_dobCtrl.text);
      int? calculatedAge;
      if (dob != null) {
        final today = DateTime.now();
        calculatedAge = today.year - dob.year;
        if (today.month < dob.month ||
            (today.month == dob.month && today.day < dob.day)) {
          calculatedAge--;
        }
        if (calculatedAge < 0) calculatedAge = null;
      }

      final PatientModel? existingPatient = _existingPatient;

      final PatientModel patient;
      if (existingPatient != null) {
        patient = existingPatient;
        if (mounted) {
          AppToast.show('Returning patient "${existingPatient.fullName}" linked ✓');
        }
      } else {
        patient = await service.createPatient(
          fullName: _nameCtrl.text.trim(),
          phone: phone,
          doctorId: widget.appointment.doctorId,
          clinicId: widget.appointment.clinicId,
          dateOfBirth: _dobCtrl.text,
          gender: _selectedGender,
          city: _cityCtrl.text.isNotEmpty ? _cityCtrl.text : null,
          area: _areaCtrl.text.isNotEmpty ? _areaCtrl.text : null,
          pincode: _pincodeCtrl.text.isNotEmpty ? _pincodeCtrl.text : null,
          occupation: _occupationCtrl.text.isNotEmpty ? _occupationCtrl.text : null,
          email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
          age: calculatedAge,
          reference: _referenceCtrl.text.isNotEmpty ? _referenceCtrl.text : null,
          personalNotes: _personalNotesCtrl.text.trim(),
          relationToPrimary: _isNewFamilyMember ? _selectedRelation : null,
          howDidYouHear: _howDidYouHear,
          photoPath: null,
          consentGiven: _dataConsentGiven,
          privacyPolicyAccepted: _privacyPolicyAccepted,
        );

        // ── Consent Audit Logging ──────────────────────────────────────────
        // Log each consent type to consent_records for a full audit trail
        try {
          final pb = ref.read(pocketbaseProvider);
          final now = DateTime.now().toUtc().toIso8601String();
          const dataConsentText =
              'I consent to the collection, storage, processing, and management of '
              'my personal and health information by the clinic through Needil for '
              'appointment scheduling, consultations, treatment planning, medical '
              'record maintenance, communication regarding my care, and other '
              'healthcare-related services.';
          const privacyPolicyText =
              'I have read and agree to the Privacy Policy and Terms of Service.';
          // Simple hash using string length + checksum (no crypto dependency needed)
          String textHash(String text) {
            final bytes = text.codeUnits;
            int hash = 0;
            for (final b in bytes) { hash = (hash * 31 + b) & 0x7FFFFFFF; }
            return 'v1.0:${hash.toRadixString(16).padLeft(8, '0')}';
          }
          await pb.collection('consent_records').create(body: {
            'patient_id': patient.id,
            'clinic_id': widget.appointment.clinicId ?? '',
            'consent_type': 'data_processing',
            'granted': true,
            'version': '1.0',
            'text_hash': textHash(dataConsentText),
            'taken_by_staff_id': ref.read(authProvider).userId ?? '',
            'timestamp': now,
            // Legacy fields (keep for backwards compat with ConsentScreen)
            'user_id': patient.id,
            'purpose': 'Patient health data consent — DPDP Act 2023',
            'withdrawn': false,
          });
          await pb.collection('consent_records').create(body: {
            'patient_id': patient.id,
            'clinic_id': widget.appointment.clinicId ?? '',
            'consent_type': 'privacy_policy',
            'granted': true,
            'version': '1.0',
            'text_hash': textHash(privacyPolicyText),
            'taken_by_staff_id': ref.read(authProvider).userId ?? '',
            'timestamp': now,
            'user_id': patient.id,
            'purpose': 'Privacy Policy & Terms of Service acceptance',
            'withdrawn': false,
          });
        } catch (_) {
          // Non-fatal: audit logging failure should not block patient registration
        }
        // ── End Consent Audit Logging ────────────────────────────────────────
      }

      await service.linkPatient(widget.appointment.id, patient.id);
      await service.markPatientDetailsSaved(widget.appointment.id);
      
      // Clear the requires_patient_details_update flag since they just saved the details
      try {
        final pb = ref.read(pocketbaseProvider);
        await pb.collection('patients').update(patient.id, body: {'requires_patient_details_update': false});
      } catch (_) {}

      ref.read(appointmentListProvider.notifier).loadAppointments();

      if (mounted) {
        if (existingPatient == null) {
          AppToast.show('Patient registered!', type: ToastType.error);
        }
        navigator.pop();
      }
    } catch (e) {
      AppToast.show('Error: $e', type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            final header = Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 20, color: context.colors.textPrimary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Patient Details', style: context.textStyles.h2),
                ),
              ],
            );

            final infoBanner = Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: context.colors.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Collect patient information as they arrive for their appointment.',
                      style: context.textStyles.caption
                          .copyWith(color: context.colors.info, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );

            final formContent = Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 24),
                  infoBanner,
                  const SizedBox(height: 24),
                  PatientDetailsForm(
                    nameCtrl: _nameCtrl,
                    phoneCtrl: _phoneCtrl,
                    dobCtrl: _dobCtrl,
                    pincodeCtrl: _pincodeCtrl,
                    countryCtrl: _countryCtrl,
                    stateCtrl: _stateCtrl,
                    cityCtrl: _cityCtrl,
                    areaCtrl: _areaCtrl,
                    occupationCtrl: _occupationCtrl,
                    emailCtrl: _emailCtrl,
                    referenceCtrl: _referenceCtrl,
                    personalNotesCtrl: _personalNotesCtrl,
                    selectedGender: _selectedGender,
                    onGenderChanged: (v) => setState(() => _selectedGender = v),
                    consentGiven: _dataConsentGiven,
                    onConsentChanged: (v) => setState(() => _dataConsentGiven = v),
                    privacyPolicyAccepted: _privacyPolicyAccepted,
                    onPrivacyPolicyChanged: (v) => setState(() => _privacyPolicyAccepted = v),

                    howDidYouHear: _howDidYouHear,
                    onHowDidYouHearChanged: (v) => setState(() => _howDidYouHear = v),
                    nameLocked: _isRegisteredPatient || (widget.appointment.patientName ?? '').isNotEmpty,
                    phoneLocked: (widget.appointment.patientPhone ?? '').isNotEmpty,
                    isNewFamilyMember: _isNewFamilyMember,
                    relationToPrimary: _selectedRelation,
                    onRelationChanged: (v) => setState(() => _selectedRelation = v),
                    selectedPhoneCode: _selectedPhoneCode,
                    onPhoneCodeChanged: (v) => setState(() => _selectedPhoneCode = v),
                    existingPatient: _existingPatient,
                    matchingPatients: _matchingPatients,
                    onAddFamilyMember: _matchingPatients.isNotEmpty
                        ? () => _applyNewFamilyMemberMode(_matchingPatients.first)
                        : null,
                    onChangeFamilyMember: () => _checkExistingPatients(),
                  ),
                  const SizedBox(height: 28),
                  AppButton(
                    label: 'Register',
                    isLoading: _isSubmitting,
                    icon: Icons.how_to_reg_rounded,
                    onPressed: _submit,
                  ),
                  if (widget.allowSkipRetroactive && widget.onSkipRetroactive != null) ...[
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Skip for now',
                      icon: Icons.skip_next_rounded,
                      isOutlined: true,
                      onPressed: () {
                        widget.onSkipRetroactive!();
                      },
                    ),
                  ],
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
                      child: formContent,
                    ),
                  ),
                ),
              );
            } else {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: formContent,
              );
            }
          },
        ),
      ),
    );
  }
}
