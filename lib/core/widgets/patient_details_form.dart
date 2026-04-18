import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../widgets/app_text_field.dart';
import '../widgets/location_fields.dart';
import '../utils/validators.dart';

/// ─── Shared Patient Details Form ────────────────────────────────────────────
///
/// Used by:
///   • PatientInfoScreen   → "Fill Details" button on call-by appointment card
///   • CreateAppointmentScreen → walk-in patient registration section
///
/// The caller owns all [TextEditingController]s and state. This widget is
/// purely presentational — it renders the fields and nothing else.
///
/// Changes enforced:
///   • Full address removed
///   • Emergency contact removed
///   • DoB is REQUIRED (not optional) and placed directly under Gender
///   • Age is auto-calculated from DoB (read-only display)
/// ─────────────────────────────────────────────────────────────────────────────
class PatientDetailsForm extends StatefulWidget {
  // ── Required controllers ──────────────────────────────────────────────────
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController dobCtrl;      // stores YYYY-MM-DD internally
  final TextEditingController pincodeCtrl;
  final TextEditingController countryCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController cityCtrl;
  final TextEditingController areaCtrl;
  final TextEditingController occupationCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController allergiesCtrl; // used when  "Others" chronic selected

  // ── State bindings ────────────────────────────────────────────────────────
  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;

  final Set<String> selectedChronicDiseases;
  final ValueChanged<Set<String>> onChronicDiseasesChanged;

  final bool consentGiven;
  final ValueChanged<bool> onConsentChanged;

  // ── Misc ──────────────────────────────────────────────────────────────────
  /// When true, name + phone are read-only (e.g. already set from appointment).
  final bool nameLocked;
  final bool phoneLocked;

  /// True once a matching patient was found by phone — shows "returning patient" banner.
  final bool isReturningPatient;

  /// When the phone field is being looked up.
  final bool isCheckingPhone;

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
    required this.allergiesCtrl,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.selectedChronicDiseases,
    required this.onChronicDiseasesChanged,
    required this.consentGiven,
    required this.onConsentChanged,
    this.nameLocked = false,
    this.phoneLocked = false,
    this.isReturningPatient = false,
    this.isCheckingPhone = false,
  });

  @override
  State<PatientDetailsForm> createState() => _PatientDetailsFormState();
}

class _PatientDetailsFormState extends State<PatientDetailsForm> {
  static const _chronicOptions = [
    'Diabetes',
    'BP',
    'Thyroid',
    'Fatty Liver',
    'No Disease',
    'Others',
  ];

  // ─── Auto-calculated age ─────────────────────────────────────────────────
  int? _calculatedAge;

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
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      // Store as YYYY-MM-DD
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      widget.dobCtrl.text = formatted;
      _recomputeAge();
    }
  }

  String _displayDob() {
    final raw = widget.dobCtrl.text;
    if (raw.isEmpty) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    // Display as DD/MM/YYYY
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  void initState() {
    super.initState();
    _recomputeAge();
    widget.dobCtrl.addListener(_recomputeAge);
  }

  @override
  void dispose() {
    widget.dobCtrl.removeListener(_recomputeAge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Phone ──────────────────────────────────────────────────────────
        Stack(
          children: [
            AppTextField(
              controller: widget.phoneCtrl,
              label: 'Phone Number',
              prefixIcon:
                  const Icon(Icons.phone_outlined, color: AppColors.textHint),
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              readOnly: widget.phoneLocked,
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

        // Returning patient banner
        if (widget.isReturningPatient) ...[
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded,
                    color: AppColors.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Patient already registered — details auto-filled.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // ── Full Name ──────────────────────────────────────────────────────
        AppTextField(
          controller: widget.nameCtrl,
          label: 'Full Name',
          prefixIcon: const Icon(Icons.person_outline_rounded,
              color: AppColors.textHint),
          validator: Validators.required,
          readOnly: widget.nameLocked,
        ),
        const SizedBox(height: 14),

        // ── Gender (required) ──────────────────────────────────────────────
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: 'Gender ', style: AppTextStyles.label),
                const TextSpan(
                    text: '*',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.selectedGender == null
                      ? AppColors.border
                      : AppColors.primary,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.selectedGender,
                  isExpanded: true,
                  hint: Text('Select Gender *',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textHint)),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(
                            value: g,
                            child: Text(g,
                                style: AppTextStyles.bodyMedium),
                          ))
                      .toList(),
                  onChanged: widget.onGenderChanged,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Date of Birth (required) ── placed right under Gender ─────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DoB picker
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: TextEditingController(text: _displayDob()),
                label: 'Date of Birth *',
                prefixIcon: const Icon(Icons.cake_outlined,
                    color: AppColors.textHint),
                hint: 'DD/MM/YYYY',
                readOnly: true,
                onTap: _pickDob,
                validator: (v) {
                  if (widget.dobCtrl.text.isEmpty) {
                    return 'Date of birth is required';
                  }
                  return null;
                },
                suffixIcon: GestureDetector(
                  onTap: _pickDob,
                  child: const Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Auto-calculated age (read-only)
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Age', style: AppTextStyles.label),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _calculatedAge != null
                          ? '$_calculatedAge yrs'
                          : '—',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: _calculatedAge != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Location fields ────────────────────────────────────────────────
        LocationFields(
          pincodeCtrl: widget.pincodeCtrl,
          countryCtrl: widget.countryCtrl,
          stateCtrl: widget.stateCtrl,
          cityCtrl: widget.cityCtrl,
          areaCtrl: widget.areaCtrl,
          allRequired: true,
        ),
        const SizedBox(height: 14),

        // ── Occupation (required) ──────────────────────────────────────────
        AppTextField(
          controller: widget.occupationCtrl,
          label: 'Occupation *',
          prefixIcon: const Icon(Icons.work_outline_rounded,
              color: AppColors.textHint),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Occupation is required' : null,
        ),
        const SizedBox(height: 14),

        // ── Email (optional) ───────────────────────────────────────────────
        AppTextField(
          controller: widget.emailCtrl,
          label: 'Email (Optional)',
          prefixIcon: const Icon(Icons.email_outlined,
              color: AppColors.textHint),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),

        // ── Chronic Diseases ───────────────────────────────────────────────
        Text('Chronic Diseases', style: AppTextStyles.label),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _chronicOptions.map((disease) {
            final isSelected =
                widget.selectedChronicDiseases.contains(disease);
            final isOthers = disease == 'Others';
            final isNoDisease = disease == 'No Disease';
            Color chipColor = AppColors.primary;
            if (isNoDisease && isSelected) chipColor = AppColors.success;
            if (isOthers) chipColor = AppColors.textSecondary;
            return GestureDetector(
              onTap: () {
                final updated =
                    Set<String>.from(widget.selectedChronicDiseases);
                if (isNoDisease) {
                  updated.clear();
                  updated.add(disease);
                } else {
                  updated.remove('No Disease');
                  if (updated.contains(disease)) {
                    updated.remove(disease);
                  } else {
                    updated.add(disease);
                  }
                }
                widget.onChronicDiseasesChanged(updated);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? chipColor : AppColors.border,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.check_rounded,
                            size: 14, color: chipColor),
                      ),
                    Text(
                      disease,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isSelected
                            ? chipColor
                            : AppColors.textSecondary,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        if (widget.selectedChronicDiseases.contains('Others')) ...[
          const SizedBox(height: 10),
          AppTextField(
            controller: widget.allergiesCtrl,
            label: 'Other Conditions (describe)',
            prefixIcon: const Icon(Icons.edit_note_rounded,
                color: AppColors.textHint),
            maxLines: 2,
          ),
        ],

        const SizedBox(height: 24),

        // ── Consent ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.consentGiven
                  ? AppColors.success
                  : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: widget.consentGiven,
                onChanged: (v) => widget.onConsentChanged(v ?? false),
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
      ],
    );
  }
}
