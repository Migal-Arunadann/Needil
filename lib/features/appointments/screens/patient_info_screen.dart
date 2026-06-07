import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/pb_collections.dart';
import '../../../core/providers/pocketbase_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/patient_details_form.dart';
import '../providers/appointment_provider.dart';
import '../models/appointment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patients/models/patient_model.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/providers/pocketbase_provider.dart';


/// Screen shown when a call-by patient arrives — uses the shared
/// [PatientDetailsForm] to collect full details and link the patient
/// record to the appointment.
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
  final _dobCtrl = TextEditingController();       // YYYY-MM-DD
  final _pincodeCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  File? _patientPhoto;
  List<Map<String, String>> _familyMembers = [];
  String? _howDidYouHear;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.appointment.patientName ?? '';
    _phoneCtrl.text = widget.appointment.patientPhone ?? '';

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
      // Mark form as partially opened
      if (!widget.appointment.patientDetailsSaved) {
        try {
          final service = ref.read(appointmentServiceProvider);
          await service.markPatientDetailsPartial(widget.appointment.id);
        } catch (_) {}
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
    _occupationCtrl.dispose();
    _emailCtrl.dispose();
    _referenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture navigator before async gap — fixes Vivo/iQOO devices where
    // context-based navigation silently fails after await calls.
    final navigator = Navigator.of(context);

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Please select gender.'),
        backgroundColor: context.colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    if (_dobCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Date of birth is required.'),
        backgroundColor: context.colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Patient consent is required to proceed.'),
        backgroundColor: context.colors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final service = ref.read(appointmentServiceProvider);
      final phone = _phoneCtrl.text.trim();

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

      // Dedup: reuse existing patient with same phone in this clinic
      PatientModel? existingPatient;
      try {
        final pb = ref.read(pocketbaseProvider);
        final clinicId = widget.appointment.clinicId;
        final doctorId = widget.appointment.doctorId;
        final filter = clinicId != null && clinicId.isNotEmpty
            ? 'phone = "$phone" && clinic = "$clinicId"'
            : 'phone = "$phone" && doctor = "$doctorId"';

        final result = await pb
            .collection(PBCollections.patients)
            .getList(filter: filter, perPage: 1);
        if (result.items.isNotEmpty) {
          existingPatient = PatientModel.fromRecord(result.items.first);
        }
      } catch (_) {}

      final PatientModel patient;
      if (existingPatient != null) {
        patient = existingPatient;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Returning patient "${existingPatient.fullName}" linked ✓'),
            backgroundColor: context.colors.info,
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
          dateOfBirth: _dobCtrl.text,
          gender: _selectedGender,
          city: _cityCtrl.text.isNotEmpty ? _cityCtrl.text : null,
          area: _areaCtrl.text.isNotEmpty ? _areaCtrl.text : null,
          pincode: _pincodeCtrl.text.isNotEmpty ? _pincodeCtrl.text : null,
          occupation: _occupationCtrl.text.isNotEmpty ? _occupationCtrl.text : null,
          email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
          age: calculatedAge,
          reference: _referenceCtrl.text.isNotEmpty ? _referenceCtrl.text : null,
          familyMembers: _familyMembers.isNotEmpty
              ? _familyMembers.map((fm) => '${fm['name']} (${fm['relation']})').toList()
              : null,
          howDidYouHear: _howDidYouHear,
          photoPath: _patientPhoto?.path,
        );
      }

      await service.linkPatient(widget.appointment.id, patient.id);
      await service.markPatientDetailsSaved(widget.appointment.id);
      ref.read(appointmentListProvider.notifier).loadAppointments();

      if (mounted) {
        if (existingPatient == null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Patient registered!'),
            backgroundColor: context.colors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
        navigator.pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: context.colors.error,
      ));
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
                    selectedGender: _selectedGender,
                    onGenderChanged: (v) => setState(() => _selectedGender = v),
                    consentGiven: _consentGiven,
                    onConsentChanged: (v) => setState(() => _consentGiven = v),
                    photoFile: _patientPhoto,
                    onPhotoChanged: (f) => setState(() => _patientPhoto = f),
                    familyMembers: _familyMembers,
                    onFamilyMembersChanged: (fm) => setState(() => _familyMembers = fm),
                    howDidYouHear: _howDidYouHear,
                    onHowDidYouHearChanged: (v) => setState(() => _howDidYouHear = v),
                    nameLocked: (widget.appointment.patientName ?? '').isNotEmpty,
                    phoneLocked: (widget.appointment.patientPhone ?? '').isNotEmpty,
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