import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/date_picker_helper.dart';
import 'package:pms_app/core/utils/validators.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/core/widgets/location_fields.dart';
import 'package:pms_app/core/widgets/patient_details_form.dart';
import 'package:pms_app/features/appointments/providers/appointment_provider.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';
import 'package:pms_app/features/patients/providers/patient_provider.dart';

const List<String> kHowDidYouHearOptions = [
  'Doctor Referral',
  'Google / Online Search',
  'Social Media (Instagram/Facebook)',
  'Friends / Family',
  'Walk-in / Signboard',
  'Newspaper / Advertisement',
  'Other',
];

const List<String> kRelationOptions = [
  'Spouse',
  'Child',
  'Parent',
  'Sibling',
  'Other',
];

/// Full-page Edit Patient Screen for Mobile, also adaptable as a modal dialog child on Desktop.
class EditPatientScreen extends ConsumerStatefulWidget {
  final PatientModel patient;
  final bool isDialogMode;

  const EditPatientScreen({
    super.key,
    required this.patient,
    this.isDialogMode = false,
  });

  @override
  ConsumerState<EditPatientScreen> createState() => _EditPatientScreenState();
}

class _EditPatientScreenState extends ConsumerState<EditPatientScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _dobCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _countryCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _occupationCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _referenceCtrl;
  late TextEditingController _personalNotesCtrl;
  late TextEditingController _nationalityCtrl;
  late TextEditingController _foreignNumberCtrl;

  String _selectedPhoneCode = '+91';
  String _selectedForeignPhoneCode = '+1';
  String? _selectedGender;
  String? _howDidYouHear;
  String? _relationToPrimary;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.patient;

    _nameCtrl = TextEditingController(text: p.fullName);

    final parsed = PhoneParser.parse(p.phone);
    _selectedPhoneCode = Validators.countryPhoneCodes.containsKey(parsed.$1) ? parsed.$1 : '+91';
    _phoneCtrl = TextEditingController(text: parsed.$2);

    _dobCtrl = TextEditingController(text: p.dateOfBirth ?? '');
    _pincodeCtrl = TextEditingController(text: p.pincode ?? '');
    _countryCtrl = TextEditingController(text: 'India');
    _stateCtrl = TextEditingController();
    _cityCtrl = TextEditingController(text: p.city ?? '');
    _areaCtrl = TextEditingController(text: p.area ?? '');
    _occupationCtrl = TextEditingController(text: p.occupation ?? '');
    _emailCtrl = TextEditingController(text: p.email ?? '');
    _referenceCtrl = TextEditingController(text: p.reference ?? '');
    _personalNotesCtrl = TextEditingController(text: p.personalNotes ?? '');
    _nationalityCtrl = TextEditingController(
      text: (p.nationality != null && p.nationality!.isNotEmpty) ? p.nationality! : 'India',
    );
    _foreignNumberCtrl = TextEditingController(text: p.foreignNumber ?? '');
    if (_nationalityCtrl.text.isNotEmpty && _nationalityCtrl.text.toLowerCase() != 'india') {
      _selectedForeignPhoneCode = kCountryDialCodes[_nationalityCtrl.text] ?? '+1';
    }
    _nationalityCtrl.addListener(_onNationalityChanged);

    final rawGender = p.gender?.trim();
    if (rawGender != null && rawGender.isNotEmpty) {
      _selectedGender = ['Male', 'Female', 'Other'].firstWhere(
        (g) => g.toLowerCase() == rawGender.toLowerCase(),
        orElse: () => 'Other',
      );
    } else {
      _selectedGender = null;
    }

    final rawHear = p.howDidYouHear?.trim();
    if (rawHear != null && rawHear.isNotEmpty) {
      _howDidYouHear = kHowDidYouHearOptions.firstWhere(
        (opt) => opt.toLowerCase() == rawHear.toLowerCase(),
        orElse: () => 'Other',
      );
    } else {
      _howDidYouHear = null;
    }

    final rawRelation = p.relationToPrimary?.trim();
    if (rawRelation != null && rawRelation.isNotEmpty) {
      _relationToPrimary = kRelationOptions.firstWhere(
        (r) => r.toLowerCase() == rawRelation.toLowerCase(),
        orElse: () => 'Other',
      );
    } else {
      _relationToPrimary = null;
    }
  }

  void _onNationalityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nationalityCtrl.removeListener(_onNationalityChanged);
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
    _nationalityCtrl.dispose();
    _foreignNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    DateTime initial = DateTime(1990);
    if (_dobCtrl.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_dobCtrl.text);
      if (parsed != null) initial = parsed;
    }
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  int? _calculateAge() {
    if (_dobCtrl.text.isEmpty) return null;
    final dob = DateTime.tryParse(_dobCtrl.text);
    if (dob == null) return null;
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null || _selectedGender!.isEmpty) {
      AppToast.show('Please select gender', type: ToastType.error);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final aptService = ref.read(appointmentServiceProvider);
      final patientService = ref.read(patientServiceProvider);
      final clinicId = widget.patient.clinicId;
      final doctorId = widget.patient.doctorId;

      final rawEntered = _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final newPhoneFull = '$_selectedPhoneCode$rawEntered';

      final oldClean = widget.patient.phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final oldParsed = PhoneParser.parse(oldClean);
      final newParsed = PhoneParser.parse(newPhoneFull);

      // Check if actual phone digits or country code changed
      final isPhoneChanged = (newParsed.$1 != oldParsed.$1) || (newParsed.$2 != oldParsed.$2);

      String? targetRelation = _relationToPrimary;

      // ── PHONE NUMBER VALIDATION & FAMILY INTEGRITY ──
      if (isPhoneChanged) {
        // 1. Check if patient is primary and has family members linked to OLD phone
        final oldFamilyPatients = await aptService.findAllPatientsByPhone(
          widget.patient.phone,
          doctorId,
          clinicId: clinicId,
        );
        final otherOldMembers =
            oldFamilyPatients.where((p) => p.id != widget.patient.id).toList();

        final isLinkedFamilyMember = widget.patient.relationToPrimary != null &&
            widget.patient.relationToPrimary!.trim().isNotEmpty &&
            widget.patient.relationToPrimary!.trim().toLowerCase() != 'self';

        if (!isLinkedFamilyMember && otherOldMembers.isNotEmpty) {
          // This is a PRIMARY patient with other family members linked to this number.
          // BLOCK IT COMPLETELY.
          setState(() => _isSaving = false);
          if (!mounted) return;

          final memberNames =
              otherOldMembers.map((m) => m.fullName).join(', ');
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: context.colors.error, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Primary Number Locked',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ],
              ),
              content: Text(
                '${widget.patient.fullName} is the primary patient for a family account with ${otherOldMembers.length} linked member(s):\n• $memberNames\n\nChanging the primary phone number would break the family tree. If this patient needs a new number, please create a separate profile or update family members first.',
                style: context.textStyles.bodyMedium,
              ),
              actions: [
                AppButton(
                  label: 'Understood',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
          return;
        }

        // 2. Check if new phone belongs to another existing family/patient in clinic
        final existingUnderNew = await aptService.findAllPatientsByPhone(
          newPhoneFull,
          doctorId,
          clinicId: clinicId,
        );
        final otherUnderNew =
            existingUnderNew.where((p) => p.id != widget.patient.id).toList();

        if (otherUnderNew.isNotEmpty) {
          // 2A. Check for duplicate name under this phone number
          final enteredName = _nameCtrl.text.trim().toLowerCase();
          final hasDuplicateName = otherUnderNew.any((r) =>
              r.fullName.trim().toLowerCase() == enteredName);

          if (hasDuplicateName) {
            setState(() => _isSaving = false);
            if (!mounted) return;
            AppToast.show(
              'A patient with name "${_nameCtrl.text.trim()}" is already registered under this phone number.',
              type: ToastType.error,
            );
            return;
          }

          // 2B. Prompt to choose relationship to the primary patient of the new phone
          final primaryRecord = otherUnderNew.firstWhere(
            (r) =>
                r.relationToPrimary == null ||
                r.relationToPrimary!.isEmpty ||
                r.relationToPrimary == 'Self',
            orElse: () => otherUnderNew.first,
          );
          final primaryName = primaryRecord.fullName;

          setState(() => _isSaving = false);
          if (!mounted) return;

          final selectedRelation = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => _SelectRelationDialog(primaryName: primaryName),
          );

          if (selectedRelation == null) {
            // User cancelled
            return;
          }

          targetRelation = selectedRelation;
          setState(() => _isSaving = true);
        } else {
          // New phone has no other patients -> Patient is now an independent primary
          targetRelation = '';
        }
      }

      // ── PREPARE UPDATE PAYLOAD ──
      final calculatedAge = _calculateAge();
      final body = {
        'full_name': _nameCtrl.text.trim(),
        'phone': newPhoneFull,
        'gender': _selectedGender,
        'nationality': _nationalityCtrl.text.trim().isNotEmpty ? _nationalityCtrl.text.trim() : 'India',
        'foreign_number': _foreignNumberCtrl.text.trim().isNotEmpty ? _foreignNumberCtrl.text.trim() : '',
        'date_of_birth': _dobCtrl.text.trim(),
        'age': calculatedAge,
        'pincode': _pincodeCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'occupation': _occupationCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'reference': _referenceCtrl.text.trim(),
        'how_did_you_hear': _howDidYouHear ?? '',
        'personal_notes': _personalNotesCtrl.text.trim(),
        'relation_to_primary': targetRelation ?? '',
      };

      final updated =
          await patientService.updatePatient(widget.patient.id, body);

      // Refresh providers
      ref.read(patientListProvider.notifier).loadPatients();
      ref.read(appointmentListProvider.notifier).loadAppointments();

      if (mounted) {
        AppToast.show('Patient details updated successfully',
            type: ToastType.success);
        Navigator.pop(context, updated);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Error saving patient: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDialogMode) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: context.colors.background,
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 650,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildFormContent(context, isMobile: false),
                ),
              ),
              _buildFooter(context),
            ],
          ),
        ),
      );
    }

    // Full-page screen for mobile
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          'Edit Patient Details',
          style: context.textStyles.h3.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildFormContent(context, isMobile: true),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(
            top: BorderSide(
              color: context.colors.border.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: AppButton(
          label: 'Save Changes',
          icon: Icons.check_circle_outline_rounded,
          isLoading: _isSaving,
          onPressed: _save,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(
            color: context.colors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.edit_rounded,
              color: context.colors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Patient Details',
                  style: context.textStyles.h3.copyWith(fontWeight: FontWeight.w700),
                ),
                if (widget.patient.patientId != null &&
                    widget.patient.patientId!.isNotEmpty)
                  Text(
                    'ID: ${widget.patient.patientId}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: context.colors.textSecondary),
            onPressed: _isSaving ? null : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent(BuildContext context, {required bool isMobile}) {
    final age = _calculateAge();
    final isForeign = _nationalityCtrl.text.trim().isNotEmpty &&
        _nationalityCtrl.text.trim().toLowerCase() != 'india';

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Section 1: Personal Info ──
          _buildSectionHeader(
            context,
            icon: Icons.person_rounded,
            title: 'Personal Information',
          ),
          const SizedBox(height: 14),

          if (isMobile) ...[
            AppTextField(
              controller: _nameCtrl,
              label: 'Full Name *',
              hint: 'e.g. Rahul Sharma',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Full name is required' : null,
            ),
            const SizedBox(height: 14),
            _buildPhoneInput(context),
            const SizedBox(height: 14),
            _buildGenderDropdown(context),
            const SizedBox(height: 14),
            _buildDobField(context, age: age),
            const SizedBox(height: 14),
            _buildNationalitySection(context),
            if (isForeign) ...[
              const SizedBox(height: 14),
              _buildForeignNumberSection(context),
            ],
            const SizedBox(height: 14),
            AppTextField(
              controller: _emailCtrl,
              label: 'Email',
              hint: 'e.g. rahul@example.com',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _occupationCtrl,
              label: 'Occupation',
              hint: 'e.g. Software Engineer, Business',
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _nameCtrl,
                    label: 'Full Name *',
                    hint: 'e.g. Rahul Sharma',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Full name is required'
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: _buildPhoneInput(context)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildGenderDropdown(context)),
                const SizedBox(width: 14),
                Expanded(child: _buildDobField(context, age: age)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildNationalitySection(context)),
                const SizedBox(width: 14),
                if (isForeign)
                  Expanded(child: _buildForeignNumberSection(context))
                else
                  const Spacer(),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'e.g. rahul@example.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField(
                    controller: _occupationCtrl,
                    label: 'Occupation',
                    hint: 'e.g. Software Engineer, Business',
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── Section 2: Location & Address ──
          _buildSectionHeader(
            context,
            icon: Icons.location_on_rounded,
            title: 'Location & Address',
          ),
          const SizedBox(height: 14),

          LocationFields(
            pincodeCtrl: _pincodeCtrl,
            countryCtrl: _countryCtrl,
            stateCtrl: _stateCtrl,
            cityCtrl: _cityCtrl,
            areaCtrl: _areaCtrl,
            allRequired: false,
          ),

          const SizedBox(height: 24),

          // ── Section 3: Referral & Clinic Details ──
          _buildSectionHeader(
            context,
            icon: Icons.campaign_rounded,
            title: 'Referral & Clinic Notes',
          ),
          const SizedBox(height: 14),

          if (isMobile) ...[
            _buildHowDidYouHearDropdown(context),
            const SizedBox(height: 14),
            AppTextField(
              controller: _referenceCtrl,
              label: 'Reference / Referred By',
              hint: 'e.g. Dr. Verma / Friend Name',
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _personalNotesCtrl,
              label: 'Personal Notes (Optional)',
              hint: 'e.g. Prefers morning appointments, VIP patient',
              maxLines: 3,
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildHowDidYouHearDropdown(context)),
                const SizedBox(width: 14),
                Expanded(
                  child: AppTextField(
                    controller: _referenceCtrl,
                    label: 'Reference / Referred By',
                    hint: 'e.g. Dr. Verma / Friend Name',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _personalNotesCtrl,
              label: 'Personal Notes (Optional)',
              hint: 'e.g. Prefers morning appointments, VIP patient',
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: context.colors.border.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(children: [
            TextSpan(text: 'Phone Number ', style: context.textStyles.label),
            const TextSpan(
              text: '*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colors.border.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: Validators.countryPhoneCodes.containsKey(_selectedPhoneCode)
                      ? _selectedPhoneCode
                      : '+91',
                  dropdownColor: context.colors.surface,
                  style: context.textStyles.bodyLarge
                      .copyWith(color: context.colors.textPrimary),
                  items: Validators.countryPhoneCodes.keys
                      .map((code) => DropdownMenuItem(
                            value: code,
                            child: Text(code,
                                style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedPhoneCode = v);
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: context.textStyles.bodyLarge
                    .copyWith(color: context.colors.textPrimary),
                decoration: InputDecoration(
                  hintText: '9876543210',
                  hintStyle: context.textStyles.bodyMedium
                      .copyWith(color: context.colors.textHint),
                  filled: true,
                  fillColor: context.colors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.colors.border.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.colors.border.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.colors.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (v) =>
                    Validators.phone(v, countryCode: _selectedPhoneCode),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderDropdown(BuildContext context) {
    final effectiveGender = (_selectedGender != null &&
            ['Male', 'Female', 'Other'].contains(_selectedGender))
        ? _selectedGender
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(children: [
            TextSpan(text: 'Gender ', style: context.textStyles.label),
            const TextSpan(
              text: '*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.border.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveGender,
              isExpanded: true,
              dropdownColor: context.colors.surface,
              style: context.textStyles.bodyLarge
                  .copyWith(color: context.colors.textPrimary),
              hint: Text('Select Gender',
                  style: context.textStyles.bodyMedium
                      .copyWith(color: context.colors.textHint)),
              items: ['Male', 'Female', 'Other']
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g,
                            style:
                                TextStyle(color: context.colors.textPrimary)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDobField(BuildContext context, {int? age}) {
    String displayDate = '';
    if (_dobCtrl.text.isNotEmpty) {
      final parsed = DateTime.tryParse(_dobCtrl.text);
      if (parsed != null) {
        displayDate = DateFormat('dd/MM/yyyy').format(parsed);
      }
    }

    return AppTextField(
      controller: TextEditingController(
          text: displayDate.isNotEmpty
              ? '$displayDate${age != null ? " ($age yrs)" : ""}'
              : ''),
      label: 'Date of Birth',
      hint: 'DD/MM/YYYY',
      readOnly: true,
      onTap: _pickDob,
      suffixIcon: GestureDetector(
        onTap: _pickDob,
        child: Icon(Icons.calendar_month_rounded, color: context.colors.primary),
      ),
    );
  }

  Widget _buildNationalitySection(BuildContext context) {
    final selected = _nationalityCtrl.text.trim().isEmpty ? 'India' : _nationalityCtrl.text.trim();
    final isIndia = selected.toLowerCase() == 'india';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(children: [
            TextSpan(text: 'Nationality ', style: context.textStyles.label),
            const TextSpan(
              text: '*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => _EditCountrySearchDialog(
                currentSelection: selected,
                onSelect: (country) {
                  setState(() {
                    _nationalityCtrl.text = country;
                    if (country.toLowerCase() != 'india') {
                      _selectedForeignPhoneCode = kCountryDialCodes[country] ?? '+1';
                    } else {
                      _foreignNumberCtrl.clear();
                    }
                  });
                  Navigator.pop(ctx);
                },
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isIndia ? context.colors.border : context.colors.primary.withValues(alpha: 0.8),
                width: isIndia ? 1.0 : 1.2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.public_rounded,
                  size: 20,
                  color: isIndia ? context.colors.textHint : context.colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected,
                    style: context.textStyles.bodyMedium.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: isIndia ? FontWeight.normal : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: context.colors.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForeignNumberSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Foreign Contact Number', style: context.textStyles.label),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Info only',
                style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: kInternationalDialCodes.contains(_selectedForeignPhoneCode)
                      ? _selectedForeignPhoneCode
                      : '+1',
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  items: kInternationalDialCodes.map((code) {
                    return DropdownMenuItem(
                      value: code,
                      child: Text(
                        code,
                        style: context.textStyles.bodyMedium.copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedForeignPhoneCode = val;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppTextField(
                label: '',
                hint: 'e.g. 555-0199 (Optional)',
                controller: _foreignNumberCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icon(Icons.public_rounded, color: context.colors.textHint),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHowDidYouHearDropdown(BuildContext context) {
    final effectiveHear = (_howDidYouHear != null &&
            kHowDidYouHearOptions.contains(_howDidYouHear))
        ? _howDidYouHear
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How Did You Know Us?', style: context.textStyles.label),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.colors.border.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveHear,
              isExpanded: true,
              dropdownColor: context.colors.surface,
              style: context.textStyles.bodyLarge
                  .copyWith(color: context.colors.textPrimary),
              hint: Text('Select source',
                  style: context.textStyles.bodyMedium
                      .copyWith(color: context.colors.textHint)),
              items: kHowDidYouHearOptions
                  .map((opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(opt,
                            style:
                                TextStyle(color: context.colors.textPrimary)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _howDidYouHear = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          top: BorderSide(
            color: context.colors.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.colors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Dialog prompted when a patient is assigned to an existing family's phone number.
class _SelectRelationDialog extends StatefulWidget {
  final String primaryName;

  const _SelectRelationDialog({required this.primaryName});

  @override
  State<_SelectRelationDialog> createState() => _SelectRelationDialogState();
}

class _SelectRelationDialogState extends State<_SelectRelationDialog> {
  String _selected = 'Spouse';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.family_restroom_rounded, color: context.colors.primary),
          const SizedBox(width: 10),
          const Text('Link to Family Account'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This phone number belongs to ${widget.primaryName}\'s family account.',
            style: context.textStyles.bodyMedium,
          ),
          const SizedBox(height: 14),
          Text(
            'Select relationship to ${widget.primaryName}:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: kRelationOptions.contains(_selected)
                    ? _selected
                    : kRelationOptions.first,
                isExpanded: true,
                items: kRelationOptions
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selected = v);
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Cancel',
              style: TextStyle(color: context.colors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Confirm & Link'),
        ),
      ],
    );
  }
}

class _EditCountrySearchDialog extends StatefulWidget {
  final String currentSelection;
  final ValueChanged<String> onSelect;

  const _EditCountrySearchDialog({
    required this.currentSelection,
    required this.onSelect,
  });

  @override
  State<_EditCountrySearchDialog> createState() => _EditCountrySearchDialogState();
}

class _EditCountrySearchDialogState extends State<_EditCountrySearchDialog> {
  final _searchCtrl = TextEditingController();
  List<String> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(kNationalities);
    _searchCtrl.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filterList() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.from(kNationalities);
      } else {
        _filtered = kNationalities
            .where((c) => c.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final hasExactMatch = _filtered.any((c) => c.toLowerCase() == query.toLowerCase());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: context.colors.surface,
      child: Container(
        width: 420,
        constraints: const BoxConstraints(maxHeight: 520),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded, color: context.colors.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Select Nationality',
                  style: context.textStyles.h4.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: '',
              controller: _searchCtrl,
              hint: 'Search country or nationality...',
              prefixIcon: Icon(Icons.search_rounded, color: context.colors.textHint),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  ..._filtered.map((country) {
                    final isSelected = country.toLowerCase() == widget.currentSelection.toLowerCase();
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: isSelected ? context.colors.primary.withValues(alpha: 0.1) : null,
                      leading: Icon(
                        country == 'India' ? Icons.home_rounded : Icons.flight_takeoff_rounded,
                        size: 18,
                        color: isSelected ? context.colors.primary : context.colors.textSecondary,
                      ),
                      title: Text(
                        country,
                        style: context.textStyles.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? context.colors.primary : context.colors.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: context.colors.primary, size: 18)
                          : (kCountryDialCodes.containsKey(country)
                              ? Text(
                                  kCountryDialCodes[country]!,
                                  style: context.textStyles.caption.copyWith(color: context.colors.textHint),
                                )
                              : null),
                      onTap: () => widget.onSelect(country),
                    );
                  }),
                  if (query.isNotEmpty && !hasExactMatch) ...[
                    const Divider(height: 16),
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      leading: Icon(Icons.add_location_alt_outlined, color: context.colors.accent, size: 18),
                      title: Text(
                        'Use custom: "$query"',
                        style: context.textStyles.bodyMedium.copyWith(
                          color: context.colors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => widget.onSelect(query),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
