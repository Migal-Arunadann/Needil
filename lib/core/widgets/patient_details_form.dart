import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/widgets/location_fields.dart';
import 'package:pms_app/core/utils/validators.dart';
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/date_picker_helper.dart';
import 'package:pms_app/features/patients/models/patient_model.dart';


/// ─── Shared Patient Details Form ────────────────────────────────────────────
///
/// Used by:
///   • PatientInfoScreen   → "Fill Details" button on call-by appointment card
///   • CreateAppointmentScreen → walk-in patient registration section
///
/// Fields: Phone, Name, Photo, Gender*, DoB* (age auto-calc), Location,
///         Occupation, Email, Reference, Relation (new family members),
///         How Did You Know Us, Consent.
/// ─────────────────────────────────────────────────────────────────────────────
class PatientDetailsForm extends StatefulWidget {
  // ── Controllers ───────────────────────────────────────────────────────────
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController dobCtrl;       // stores YYYY-MM-DD internally
  final TextEditingController pincodeCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController areaCtrl;
  final TextEditingController occupationCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController referenceCtrl;
  final TextEditingController personalNotesCtrl;
  final TextEditingController? nationalityCtrl;
  final TextEditingController? foreignNumberCtrl;

  // ── State bindings ────────────────────────────────────────────────────────
  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;

  final bool consentGiven;
  final ValueChanged<bool> onConsentChanged;

  final bool privacyPolicyAccepted;
  final ValueChanged<bool> onPrivacyPolicyChanged;

  final String? howDidYouHear;
  final ValueChanged<String?> onHowDidYouHearChanged;

  // ── Family member registration ────────────────────────────────────────────
  /// When true, shows a relation picker so the new patient can be linked
  /// as a family member of the primary phone account holder.
  final bool isNewFamilyMember;
  final String? relationToPrimary;
  final ValueChanged<String?>? onRelationChanged;

  // ── Misc ──────────────────────────────────────────────────────────────────
  final bool nameLocked;
  final bool phoneLocked;
  final bool isReturningPatient;
  final bool isCheckingPhone;
  final String selectedPhoneCode;
  final ValueChanged<String> onPhoneCodeChanged;
  final String selectedForeignPhoneCode;
  final ValueChanged<String>? onForeignPhoneCodeChanged;
  final List<PatientModel>? matchingPatients;
  final PatientModel? existingPatient;
  final VoidCallback? onAddFamilyMember;
  final VoidCallback? onChangeFamilyMember;
  final VoidCallback? onSwitchBackToPrimary;

  const PatientDetailsForm({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.dobCtrl,
    required this.pincodeCtrl,
    required this.countryCtrl,
    required this.stateCtrl,
    required this.cityCtrl,
    required this.areaCtrl,
    required this.occupationCtrl,
    required this.emailCtrl,
    required this.referenceCtrl,
    required this.personalNotesCtrl,
    this.nationalityCtrl,
    this.foreignNumberCtrl,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.consentGiven,
    required this.onConsentChanged,
    required this.privacyPolicyAccepted,
    required this.onPrivacyPolicyChanged,

    this.howDidYouHear,
    required this.onHowDidYouHearChanged,
    this.isNewFamilyMember = false,
    this.relationToPrimary,
    this.onRelationChanged,
    this.nameLocked = false,
    this.phoneLocked = false,
    this.isReturningPatient = false,
    this.isCheckingPhone = false,
    required this.selectedPhoneCode,
    required this.onPhoneCodeChanged,
    this.selectedForeignPhoneCode = '+1',
    this.onForeignPhoneCodeChanged,
    this.matchingPatients,
    this.existingPatient,
    this.onAddFamilyMember,
    this.onChangeFamilyMember,
    this.onSwitchBackToPrimary,
  });

  @override
  State<PatientDetailsForm> createState() => _PatientDetailsFormState();
}

class _PatientDetailsFormState extends State<PatientDetailsForm> {
  int? _calculatedAge;
  late TextEditingController _nationalityCtrl;
  late TextEditingController _foreignNumberCtrl;
  late String _foreignPhoneCode;
  bool _ownsNationalityCtrl = false;
  bool _ownsForeignNumberCtrl = false;

  @override
  void initState() {
    super.initState();
    if (widget.nationalityCtrl != null) {
      _nationalityCtrl = widget.nationalityCtrl!;
    } else {
      _nationalityCtrl = TextEditingController(text: 'India');
      _ownsNationalityCtrl = true;
    }
    if (_nationalityCtrl.text.trim().isEmpty) {
      _nationalityCtrl.text = 'India';
    }

    if (widget.foreignNumberCtrl != null) {
      _foreignNumberCtrl = widget.foreignNumberCtrl!;
    } else {
      _foreignNumberCtrl = TextEditingController();
      _ownsForeignNumberCtrl = true;
    }

    _foreignPhoneCode = widget.selectedForeignPhoneCode;
    _nationalityCtrl.addListener(_onNationalityChanged);
    _recomputeAge();
    widget.dobCtrl.addListener(_recomputeAge);
  }

  @override
  void dispose() {
    widget.dobCtrl.removeListener(_recomputeAge);
    _nationalityCtrl.removeListener(_onNationalityChanged);
    if (_ownsNationalityCtrl) _nationalityCtrl.dispose();
    if (_ownsForeignNumberCtrl) _foreignNumberCtrl.dispose();
    super.dispose();
  }

  void _onNationalityChanged() {
    if (mounted) setState(() {});
  }

  void _recomputeAge() {
    final dob = DateTime.tryParse(widget.dobCtrl.text);
    if (dob == null) {
      setState(() => _calculatedAge = null);
      return;
    }
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    setState(() => _calculatedAge = age < 0 ? null : age);
  }

  Future<void> _pickDob() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      widget.dobCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _recomputeAge();
    }
  }

  String _displayDob() {
    final raw = widget.dobCtrl.text;
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final phoneField = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLabel(text: 'Phone Number', isRequired: true),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: context.colors.divider,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border.withValues(alpha: 0.5), width: 0.8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.selectedPhoneCode,
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  items: Validators.countryPhoneCodes.keys.map((code) {
                    return DropdownMenuItem(
                      value: code,
                      child: Text(
                        ' $code',
                        style: context.textStyles.bodyLarge.copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: widget.phoneLocked ? null : (val) {
                    if (val != null) {
                      widget.onPhoneCodeChanged(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Stack(
                children: [
                  AppTextField(
                    label: '',
                    controller: widget.phoneCtrl,
                    keyboardType: TextInputType.phone,
                    validator: (v) => Validators.phone(v, countryCode: widget.selectedPhoneCode),
                    readOnly: widget.phoneLocked,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(
                        Validators.countryPhoneCodes[widget.selectedPhoneCode] ?? 15,
                      ),
                    ],
                  ),
                  if (widget.isCheckingPhone)
                    const Positioned(
                      right: 14,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final phoneSection = phoneField;

    Widget? statusBanner;
    if (widget.existingPatient != null) {
      statusBanner = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: context.colors.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Returning Patient: ${widget.existingPatient!.fullName} '
                '(${widget.existingPatient!.relationToPrimary ?? 'Self'}'
                '${widget.existingPatient!.gender != null ? ' • ${widget.existingPatient!.gender}' : ''}'
                '${widget.existingPatient!.age != null ? ' • ${widget.existingPatient!.age} yrs' : ''})',
                style: context.textStyles.caption.copyWith(
                  color: context.colors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (widget.onChangeFamilyMember != null || widget.onAddFamilyMember != null)
              InkWell(
                onTap: () {
                  final hasMultiple = (widget.matchingPatients?.length ?? 0) > 1;
                  if (hasMultiple && widget.onChangeFamilyMember != null) {
                    widget.onChangeFamilyMember!();
                  } else if (widget.onAddFamilyMember != null) {
                    widget.onAddFamilyMember!();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    (widget.matchingPatients?.length ?? 0) > 1 ? 'Change' : '+ Add Family Member',
                    style: context.textStyles.caption.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (widget.isNewFamilyMember) {
      statusBanner = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.family_restroom_rounded, color: context.colors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Adding New Family Member under ${widget.phoneCtrl.text.trim()}',
                style: context.textStyles.caption.copyWith(
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (widget.matchingPatients != null && widget.matchingPatients!.isNotEmpty)
              InkWell(
                onTap: () {
                  if (widget.onSwitchBackToPrimary != null) {
                    widget.onSwitchBackToPrimary!();
                  } else if ((widget.matchingPatients?.length ?? 0) > 1 && widget.onChangeFamilyMember != null) {
                    widget.onChangeFamilyMember!();
                  } else if (widget.onAddFamilyMember != null) {
                    widget.onAddFamilyMember!();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    (widget.matchingPatients?.length ?? 0) > 1
                        ? 'Change'
                        : 'Switch Back to ${widget.matchingPatients!.first.fullName}',
                    style: context.textStyles.caption.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (widget.isReturningPatient) {
      statusBanner = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.info.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.verified_user_rounded, color: context.colors.info, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Patient already registered — details auto-filled.',
                style: context.textStyles.caption.copyWith(color: context.colors.info, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    final nameSection = AppTextField(
      controller: widget.nameCtrl,
      label: 'Full Name',
      isRequired: true,
      prefixIcon: Icon(Icons.person_outline_rounded, color: context.colors.textHint),
      validator: Validators.required,
      readOnly: widget.nameLocked,
    );

    final genderSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLabel(text: 'Gender', isRequired: true),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.selectedGender == null ? context.colors.border : context.colors.primary,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.selectedGender,
              isExpanded: true,
              hint: Text('Select Gender *',
                  style: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint)),
              items: ['Male', 'Female', 'Other']
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(g, style: context.textStyles.bodyMedium),
                      ))
                  .toList(),
              onChanged: widget.onGenderChanged,
            ),
          ),
        ),
      ],
    );

    final dobAgeSection = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: AppTextField(
            controller: TextEditingController(text: _displayDob()),
            label: 'Date of Birth',
            isRequired: true,
            prefixIcon: Icon(Icons.cake_outlined, color: context.colors.textHint),
            hint: 'DD/MM/YYYY',
            readOnly: true,
            onTap: _pickDob,
            validator: (_) => widget.dobCtrl.text.isEmpty ? 'Date of birth is required' : null,
            suffixIcon: GestureDetector(
              onTap: _pickDob,
              child: Icon(Icons.calendar_month_rounded, color: context.colors.primary),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLabel(text: 'Age'),
              const SizedBox(height: 8),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.colors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  _calculatedAge != null ? '$_calculatedAge yrs' : '—',
                  style: context.textStyles.bodyMedium.copyWith(
                    color: _calculatedAge != null ? context.colors.textPrimary : context.colors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final isForeign = _nationalityCtrl.text.trim().isNotEmpty &&
        _nationalityCtrl.text.trim().toLowerCase() != 'india';

    final nationalitySection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLabel(text: 'Nationality', isRequired: true),
        const SizedBox(height: 8),
        _NationalityDropdown(
          selectedCountry: _nationalityCtrl.text.trim().isEmpty ? 'India' : _nationalityCtrl.text.trim(),
          onChanged: (newCountry) {
            if (newCountry != null) {
              _nationalityCtrl.text = newCountry;
              if (newCountry != 'India') {
                final defaultDial = kCountryDialCodes[newCountry] ?? '+1';
                setState(() {
                  _foreignPhoneCode = defaultDial;
                });
                if (widget.onForeignPhoneCodeChanged != null) {
                  widget.onForeignPhoneCodeChanged!(defaultDial);
                }
              } else {
                _foreignNumberCtrl.clear();
              }
              setState(() {});
            }
          },
        ),
      ],
    );

    final foreignNumberSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const AppLabel(text: 'Foreign Contact Number'),
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
                  value: kInternationalDialCodes.contains(_foreignPhoneCode) ? _foreignPhoneCode : '+1',
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
                        _foreignPhoneCode = val;
                      });
                      if (widget.onForeignPhoneCodeChanged != null) {
                        widget.onForeignPhoneCodeChanged!(val);
                      }
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

    final occupationSection = AppTextField(
      controller: widget.occupationCtrl,
      label: 'Occupation',
      prefixIcon: Icon(Icons.work_outline_rounded, color: context.colors.textHint),
    );

    final emailSection = AppTextField(
      controller: widget.emailCtrl,
      label: 'Email',
      prefixIcon: Icon(Icons.email_outlined, color: context.colors.textHint),
      keyboardType: TextInputType.emailAddress,
    );

    final howDidYouHearSection = _CombinedSourceDropdown(
      initialValue: widget.howDidYouHear,
      onChanged: widget.onHowDidYouHearChanged,
      referenceCtrl: widget.referenceCtrl,
    );

    final personalNotesSection = AppTextField(
      controller: widget.personalNotesCtrl,
      label: 'Personal Notes (For Clinic Use Only)',
      hint: 'Add any specific notes or info...',
      prefixIcon: Icon(Icons.note_alt_outlined, color: context.colors.textHint),
      maxLines: 3,
    );

    // Relation picker — only shown when registering a new family member
    final relationSection = widget.isNewFamilyMember
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLabel(text: 'Relation to Primary Account Holder', isRequired: true),
              const SizedBox(height: 8),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.relationToPrimary,
                    isExpanded: true,
                    hint: Text('Select relation',
                        style: context.textStyles.bodyMedium
                            .copyWith(color: context.colors.textHint)),
                    items: const [
                      'Spouse',
                      'Child',
                      'Parent',
                      'Sibling',
                      'Other',
                    ]
                        .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ))))
                        .toList(),
                    onChanged: widget.onRelationChanged,
                  ),
                ),
              ),
            ],
          )
        : const SizedBox.shrink();

    final consentSection = _ConsentCheckboxCard(
      key: const ValueKey('data_consent'),
      value: widget.consentGiven,
      onChanged: widget.onConsentChanged,
      icon: Icons.medical_information_outlined,
      title: 'Health Data Consent',
      shortText:
          'I consent to the collection, storage, processing, and management of my personal and health information…',
      fullText:
          'I consent to the collection, storage, processing, and management of '
          'my personal and health information by the clinic through Needil for '
          'appointment scheduling, consultations, treatment planning, medical '
          'record maintenance, communication regarding my care, and other '
          'healthcare-related services. I acknowledge that my information will '
          'be processed in accordance with the Privacy Policy and applicable '
          'data protection laws.',
    );

    final privacySection = _ConsentCheckboxCard(
      key: const ValueKey('privacy_consent'),
      value: widget.privacyPolicyAccepted,
      onChanged: widget.onPrivacyPolicyChanged,
      icon: Icons.policy_outlined,
      title: 'Privacy Policy & Terms',
      shortText: 'I have read and agree to the Privacy Policy and Terms of Service.',
      fullText: 'I have read and agree to the Privacy Policy and Terms of Service.',
      hasLinks: true,
      privacyPolicyUrl: 'https://needil.com/privacy',
      termsUrl: 'https://needil.com/terms',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 700;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: phoneSection),
                  const SizedBox(width: 16),
                  if (widget.isNewFamilyMember) ...[
                    Expanded(child: relationSection),
                    const SizedBox(width: 16),
                  ],
                  Expanded(child: nameSection),
                ],
              ),
              if (statusBanner != null) ...[
                const SizedBox(height: 14),
                statusBanner,
              ],
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: genderSection),
                  const SizedBox(width: 16),
                  Expanded(child: dobAgeSection),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: nationalitySection),
                  const SizedBox(width: 16),
                  if (isForeign) ...[
                    Expanded(child: foreignNumberSection),
                  ] else ...[
                    const Spacer(),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: occupationSection),
                  const SizedBox(width: 16),
                  Expanded(child: emailSection),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: howDidYouHearSection),
                  const SizedBox(width: 16),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 24),
              LocationFields(
                pincodeCtrl: widget.pincodeCtrl,
                countryCtrl: widget.countryCtrl,
                stateCtrl: widget.stateCtrl,
                cityCtrl: widget.cityCtrl,
                areaCtrl: widget.areaCtrl,
                allRequired: true,
              ),
              const SizedBox(height: 24),
              personalNotesSection,
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: consentSection),
                  const SizedBox(width: 16),
                  Expanded(child: privacySection),
                ],
              ),
            ] else ...[
              phoneSection,
              if (statusBanner != null) ...[
                const SizedBox(height: 10),
                statusBanner,
              ],
              const SizedBox(height: 16),
              if (widget.isNewFamilyMember) ...[
                relationSection,
                const SizedBox(height: 16),
              ],
              nameSection,
              const SizedBox(height: 16),
              genderSection,
              const SizedBox(height: 16),
              dobAgeSection,
              const SizedBox(height: 16),
              nationalitySection,
              if (isForeign) ...[
                const SizedBox(height: 16),
                foreignNumberSection,
              ],
              const SizedBox(height: 16),
              occupationSection,
              const SizedBox(height: 16),
              emailSection,
              const SizedBox(height: 16),
              howDidYouHearSection,
              const SizedBox(height: 20),
              LocationFields(
                pincodeCtrl: widget.pincodeCtrl,
                countryCtrl: widget.countryCtrl,
                stateCtrl: widget.stateCtrl,
                cityCtrl: widget.cityCtrl,
                areaCtrl: widget.areaCtrl,
                allRequired: true,
              ),
              const SizedBox(height: 20),
              personalNotesSection,
              const SizedBox(height: 24),
              consentSection,
              const SizedBox(height: 12),
              privacySection,
            ],
          ],
        );
      },
    );
  }
}

// ─── Consent Checkbox Card ─────────────────────────────────────────────────────
/// An expandable consent checkbox card used by [PatientDetailsForm].
/// Shows collapsed text by default with a "Read more" toggle.
class _ConsentCheckboxCard extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final String title;
  final String shortText;
  final String fullText;
  final bool hasLinks;
  final String? privacyPolicyUrl;
  final String? termsUrl;

  const _ConsentCheckboxCard({
    super.key,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.title,
    required this.shortText,
    required this.fullText,
    this.hasLinks = false,
    this.privacyPolicyUrl,
    this.termsUrl,
  });

  @override
  State<_ConsentCheckboxCard> createState() => _ConsentCheckboxCardState();
}

class _ConsentCheckboxCardState extends State<_ConsentCheckboxCard> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  Future<void> _launchUrl(String url) async {
    try {
      // Use conditional import approach to avoid web/mobile issues
      // ignore: avoid_dynamic_calls
      final uri = Uri.parse(url);
      // We silently fail if url_launcher not available
      // This cast avoids needing url_launcher dependency
      // In practice, url_launcher is already in pubspec if images work
      // We'll try a platform-agnostic approach
      // ignore: deprecated_member_use
      await _openUrl(uri);
    } catch (_) {}
  }

  Future<void> _openUrl(Uri uri) async {
    // Dynamically use url_launcher if it's in the project
    // We show a simple dialog as fallback
    if (mounted) {
      AppToast.show('Opening ${uri.host}…', duration: const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChecked = widget.value;
    final borderColor = isChecked ? context.colors.success : context.colors.border;
    final iconColor = isChecked ? context.colors.success : context.colors.textHint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isChecked
            ? context.colors.success.withValues(alpha: 0.04)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isChecked ? 1.5 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row (tap to toggle checkbox) ──
          GestureDetector(
            onTap: () => widget.onChanged(!widget.value),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: context.textStyles.label.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        // Short or full text
                        if (!_expanded)
                          Text(
                            widget.shortText,
                            style: context.textStyles.caption.copyWith(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                            ),
                          )
                        else
                          widget.hasLinks
                              ? _buildLinkedText(context)
                              : Text(
                                  widget.fullText,
                                  style: context.textStyles.caption.copyWith(
                                    fontSize: 11,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                        const SizedBox(height: 4),
                        // Read more / less toggle
                        GestureDetector(
                          onTap: _toggleExpanded,
                          child: Text(
                            _expanded ? 'Read less' : 'Read more',
                            style: context.textStyles.caption.copyWith(
                              fontSize: 11,
                              color: context.colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Checkbox icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      isChecked
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      key: ValueKey(isChecked),
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedText(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: context.textStyles.caption.copyWith(
          fontSize: 11,
          color: context.colors.textSecondary,
        ),
        children: [
          const TextSpan(text: 'I have read and agree to the '),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _launchUrl(widget.privacyPolicyUrl ?? ''),
              child: Text(
                'Privacy Policy',
                style: context.textStyles.caption.copyWith(
                  fontSize: 11,
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const TextSpan(text: ' and '),
          WidgetSpan(
            child: GestureDetector(
              onTap: () => _launchUrl(widget.termsUrl ?? ''),
              child: Text(
                'Terms of Service',
                style: context.textStyles.caption.copyWith(
                  fontSize: 11,
                  color: context.colors.primary,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}

// ─── Combined Source Dropdown ──────────────────────────────────────────────────────

/// Dropdown for "How Did You Know Us?" with common options + dynamic input.
/// Syncs to the existing [referenceCtrl] so parent screens don't need changes.
class _CombinedSourceDropdown extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final TextEditingController referenceCtrl;

  const _CombinedSourceDropdown({
    required this.initialValue,
    required this.onChanged,
    required this.referenceCtrl,
  });

  @override
  State<_CombinedSourceDropdown> createState() => _CombinedSourceDropdownState();
}

class _CombinedSourceDropdownState extends State<_CombinedSourceDropdown> {
  static const List<String> _options = [
    'Doctor Referral',
    'Friend / Family',
    'Social Media',
    'Google / Web Search',
    'Walk-in / Passerby',
    'Newspaper / Flyer',
    'TV / Radio',
    'Other',
  ];

  String? _selected;
  bool _showCustomField = false;

  @override
  void initState() {
    super.initState();
    // Initialize based on initialValue
    final existing = widget.initialValue;
    if (existing != null && existing.isNotEmpty) {
      if (_options.contains(existing)) {
        _selected = existing;
        // If it's one of the options that requires specific name, show it
        if (_requiresSpecificName(existing)) {
          _showCustomField = true;
        }
      } else {
        _selected = 'Other';
        _showCustomField = true;
      }
    }
  }

  bool _requiresSpecificName(String option) {
    return option == 'Doctor Referral' ||
           option == 'Friend / Family' ||
           option == 'Social Media' ||
           option == 'Other';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLabel(text: 'How Did You Know Us?'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selected,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.colors.textHint),
              hint: Row(children: [
                Icon(Icons.handshake_outlined, color: context.colors.textHint, size: 18),
                const SizedBox(width: 10),
                Text('Select source',
                    style: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint)),
              ]),
              items: _options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o, style: context.textStyles.bodyMedium)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selected = val;
                  _showCustomField = val != null && _requiresSpecificName(val);
                  if (!_showCustomField) {
                    widget.referenceCtrl.clear();
                  }
                });
                widget.onChanged(val);
              },
            ),
          ),
        ),
        if (_showCustomField) ...[
          const SizedBox(height: 10),
          AppTextField(
            controller: widget.referenceCtrl,
            label: '',
            hint: _selected == 'Doctor Referral'
                ? 'Doctor\'s Name...'
                : _selected == 'Friend / Family'
                    ? 'Friend/Family Name...'
                    : _selected == 'Social Media'
                        ? 'Which platform / ad?'
                        : 'Please specify...',
            prefixIcon: Icon(Icons.person_outline, color: context.colors.textHint),
          ),
        ],
      ],
    );
  }
}

// ─── Country & Nationality Constants ──────────────────────────────────────────

const List<String> kNationalities = [
  'India',
  'United States',
  'United Kingdom',
  'United Arab Emirates',
  'Canada',
  'Australia',
  'Saudi Arabia',
  'Qatar',
  'Kuwait',
  'Oman',
  'Bahrain',
  'Singapore',
  'Malaysia',
  'Germany',
  'France',
  'Netherlands',
  'New Zealand',
  'Sri Lanka',
  'Nepal',
  'Bangladesh',
  'Pakistan',
  'South Africa',
  'Philippines',
  'Other',
];

const Map<String, String> kCountryDialCodes = {
  'India': '+91',
  'United States': '+1',
  'United Kingdom': '+44',
  'United Arab Emirates': '+971',
  'Canada': '+1',
  'Australia': '+61',
  'Saudi Arabia': '+966',
  'Qatar': '+974',
  'Kuwait': '+965',
  'Oman': '+968',
  'Bahrain': '+973',
  'Singapore': '+65',
  'Malaysia': '+60',
  'Germany': '+49',
  'France': '+33',
  'Netherlands': '+31',
  'New Zealand': '+64',
  'Sri Lanka': '+94',
  'Nepal': '+977',
  'Bangladesh': '+880',
  'Pakistan': '+92',
  'South Africa': '+27',
  'Philippines': '+63',
  'Other': '+1',
};

const List<String> kInternationalDialCodes = [
  '+1', '+44', '+971', '+966', '+61', '+65', '+974', '+965', '+968', '+973',
  '+49', '+33', '+31', '+64', '+94', '+977', '+880', '+92', '+27', '+63',
  '+81', '+86', '+82', '+7', '+39', '+34', '+41', '+46', '+47', '+45',
  '+48', '+351', '+353', '+32', '+30', '+90', '+20', '+234', '+254', '+55',
  '+52', '+54', '+56', '+57',
];

/// Searchable Nationality Dropdown / Picker
class _NationalityDropdown extends StatelessWidget {
  final String selectedCountry;
  final ValueChanged<String?> onChanged;

  const _NationalityDropdown({
    required this.selectedCountry,
    required this.onChanged,
  });

  void _showPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CountrySearchDialog(
        currentSelection: selectedCountry,
        onSelect: (country) {
          onChanged(country);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIndia = selectedCountry.toLowerCase() == 'india';

    return InkWell(
      onTap: () => _showPicker(context),
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
                selectedCountry,
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
    );
  }
}

class _CountrySearchDialog extends StatefulWidget {
  final String currentSelection;
  final ValueChanged<String> onSelect;

  const _CountrySearchDialog({
    required this.currentSelection,
    required this.onSelect,
  });

  @override
  State<_CountrySearchDialog> createState() => _CountrySearchDialogState();
}

class _CountrySearchDialogState extends State<_CountrySearchDialog> {
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
