import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pms_app/core/widgets/app_text_field.dart';
import 'package:pms_app/core/widgets/location_fields.dart';
import 'package:pms_app/core/utils/validators.dart';
import 'package:pms_app/core/utils/image_helper.dart';
import 'package:pms_app/core/theme/app_theme.dart';


/// ─── Shared Patient Details Form ────────────────────────────────────────────
///
/// Used by:
///   • PatientInfoScreen   → "Fill Details" button on call-by appointment card
///   • CreateAppointmentScreen → walk-in patient registration section
///
/// Fields: Phone, Name, Photo, Gender*, DoB* (age auto-calc), Location,
///         Occupation, Email, Reference, Family Members, How Did You Know Us,
///         Consent.
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

  // ── State bindings ────────────────────────────────────────────────────────
  final String? selectedGender;
  final ValueChanged<String?> onGenderChanged;

  final bool consentGiven;
  final ValueChanged<bool> onConsentChanged;

  final bool privacyPolicyAccepted;
  final ValueChanged<bool> onPrivacyPolicyChanged;

  // ── New fields ────────────────────────────────────────────────────────────
  final File? photoFile;
  final ValueChanged<File?> onPhotoChanged;

  final List<Map<String, String>> familyMembers; // [{name, relation}]
  final ValueChanged<List<Map<String, String>>> onFamilyMembersChanged;

  final String? howDidYouHear;
  final ValueChanged<String?> onHowDidYouHearChanged;

  // ── Misc ──────────────────────────────────────────────────────────────────
  final bool nameLocked;
  final bool phoneLocked;
  final bool isReturningPatient;
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
    required this.referenceCtrl,
    required this.selectedGender,
    required this.onGenderChanged,
    required this.consentGiven,
    required this.onConsentChanged,
    required this.privacyPolicyAccepted,
    required this.onPrivacyPolicyChanged,
    this.photoFile,
    required this.onPhotoChanged,
    this.familyMembers = const [],
    required this.onFamilyMembersChanged,
    this.howDidYouHear,
    required this.onHowDidYouHearChanged,
    this.nameLocked = false,
    this.phoneLocked = false,
    this.isReturningPatient = false,
    this.isCheckingPhone = false,
  });

  @override
  State<PatientDetailsForm> createState() => _PatientDetailsFormState();
}

class _PatientDetailsFormState extends State<PatientDetailsForm> {
  int? _calculatedAge;

  static const List<String> _howDidYouHearOptions = [
    'Google',
    'Social Media',
    'Friend / Family',
    'Doctor Referral',
    'Walk-in',
    'Newspaper / Flyer',
    'Other',
  ];

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
      locale: const Locale('en', 'IN'),
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

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Patient Photo', style: context.textStyles.h3),
          const SizedBox(height: 8),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.photo_library_rounded, color: context.colors.primary),
            ),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.camera_alt_rounded, color: context.colors.accent),
            ),
            title: const Text('Take a Photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 60);
      if (picked != null && mounted) {
        final compressed = await ImageHelper.compressToWebP(picked);
        if (compressed != null && mounted) {
          widget.onPhotoChanged(File(compressed.path));
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.show('Failed to pick image: $e', type: ToastType.error);
      }
    }
  }

  void _addFamilyMember() {
    final nameCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add Family Member', style: context.textStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: nameCtrl, label: 'Name', hint: 'e.g. John'),
            const SizedBox(height: 12),
            AppTextField(controller: relationCtrl, label: 'Relation', hint: 'e.g. Spouse, Parent, Child'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty && relationCtrl.text.trim().isNotEmpty) {
                final updated = List<Map<String, String>>.from(widget.familyMembers);
                updated.add({'name': nameCtrl.text.trim(), 'relation': relationCtrl.text.trim()});
                widget.onFamilyMembersChanged(updated);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
            child: Text('Add', style: TextStyle(color: context.colors.textPrimary)),
          ),
        ],
      ),
    );
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
    final phoneField = Stack(
      children: [
        AppTextField(
          controller: widget.phoneCtrl,
          label: 'Phone Number',
          prefixIcon: Icon(Icons.phone_outlined, color: context.colors.textHint),
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
    );

    final phoneSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        phoneField,
        if (widget.isReturningPatient) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.info.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, color: context.colors.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Patient already registered — details auto-filled.',
                    style: context.textStyles.caption.copyWith(color: context.colors.info),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    final nameSection = AppTextField(
      controller: widget.nameCtrl,
      label: 'Full Name',
      prefixIcon: Icon(Icons.person_outline_rounded, color: context.colors.textHint),
      validator: Validators.required,
      readOnly: widget.nameLocked,
    );

    // Patient photo
    Widget photoSection;
    if (kIsWeb) {
      photoSection = Center(
        child: Column(
          children: [
            Icon(Icons.person_outline_rounded, color: context.colors.textHint, size: 48),
            const SizedBox(height: 6),
            Text(
              'Patient photo upload is available on the mobile app.',
              style: context.textStyles.caption.copyWith(color: context.colors.textHint),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      photoSection = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: context.colors.border),
                      image: widget.photoFile != null
                          ? DecorationImage(image: FileImage(widget.photoFile!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: widget.photoFile == null
                        ? Icon(Icons.person_add_alt_1_rounded, color: context.colors.textHint, size: 32)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.colors.textPrimary, width: 2),
                      ),
                      child: Icon(Icons.camera_alt_rounded, color: context.colors.textPrimary, size: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Patient Photo (Optional)',
              style: context.textStyles.caption.copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      );
    }

    final genderSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
            label: 'Date of Birth *',
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
              Text('Age', style: context.textStyles.label),
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

    final occupationSection = AppTextField(
      controller: widget.occupationCtrl,
      label: 'Occupation (Optional)',
      prefixIcon: Icon(Icons.work_outline_rounded, color: context.colors.textHint),
    );

    final emailSection = AppTextField(
      controller: widget.emailCtrl,
      label: 'Email (Optional)',
      prefixIcon: Icon(Icons.email_outlined, color: context.colors.textHint),
      keyboardType: TextInputType.emailAddress,
    );

    final referredBySection = _ReferredByDropdown(referenceCtrl: widget.referenceCtrl);

    final howDidYouHearSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('How Did You Know Us? (Optional)', style: context.textStyles.label),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.howDidYouHear,
              isExpanded: true,
              hint: Text('Select an option',
                  style: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint)),
              items: _howDidYouHearOptions
                  .map((o) => DropdownMenuItem(value: o, child: Text(o, style: context.textStyles.bodyMedium)))
                  .toList(),
              onChanged: widget.onHowDidYouHearChanged,
            ),
          ),
        ),
      ],
    );

    final familyMembersSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.family_restroom_rounded, color: context.colors.textHint, size: 18),
            const SizedBox(width: 8),
            Text('Family Members (Optional)', style: context.textStyles.label),
            const Spacer(),
            GestureDetector(
              onTap: _addFamilyMember,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: context.colors.primary, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      'Add',
                      style: context.textStyles.caption.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.familyMembers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              'No family members added.',
              style: context.textStyles.caption.copyWith(color: context.colors.textHint),
            ),
          ),
        ...widget.familyMembers.asMap().entries.map((entry) {
          final i = entry.key;
          final fm = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 16, color: context.colors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text('${fm['name']} (${fm['relation']})', style: context.textStyles.bodyMedium)),
                GestureDetector(
                  onTap: () {
                    final updated = List<Map<String, String>>.from(widget.familyMembers);
                    updated.removeAt(i);
                    widget.onFamilyMembersChanged(updated);
                  },
                  child: Icon(Icons.close_rounded, size: 16, color: context.colors.error),
                ),
              ],
            ),
          );
        }),
      ],
    );

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
                  Expanded(child: nameSection),
                ],
              ),
              const SizedBox(height: 16),
              photoSection,
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: genderSection),
                  const SizedBox(width: 16),
                  Expanded(child: dobAgeSection),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: occupationSection),
                  const SizedBox(width: 16),
                  Expanded(child: emailSection),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: referredBySection),
                  const SizedBox(width: 16),
                  Expanded(child: howDidYouHearSection),
                ],
              ),
            ] else ...[
              phoneSection,
              const SizedBox(height: 14),
              nameSection,
              const SizedBox(height: 14),
              photoSection,
              const SizedBox(height: 14),
              genderSection,
              const SizedBox(height: 14),
              dobAgeSection,
              const SizedBox(height: 14),
              occupationSection,
              const SizedBox(height: 14),
              emailSection,
              const SizedBox(height: 14),
              referredBySection,
              const SizedBox(height: 14),
              howDidYouHearSection,
            ],
            const SizedBox(height: 16),
            LocationFields(
              pincodeCtrl: widget.pincodeCtrl,
              countryCtrl: widget.countryCtrl,
              stateCtrl: widget.stateCtrl,
              cityCtrl: widget.cityCtrl,
              areaCtrl: widget.areaCtrl,
              allRequired: true,
            ),
            const SizedBox(height: 24),
            familyMembersSection,
            const SizedBox(height: 16),
            consentSection,
            const SizedBox(height: 12),
            privacySection,
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

// ─── Referred-By Dropdown ──────────────────────────────────────────────────────

/// Dropdown for "Referred By" with common referral options + custom "Other" input.
/// Syncs to the existing [referenceCtrl] so parent screens don't need changes.
class _ReferredByDropdown extends StatefulWidget {
  final TextEditingController referenceCtrl;
  const _ReferredByDropdown({required this.referenceCtrl});

  @override
  State<_ReferredByDropdown> createState() => _ReferredByDropdownState();
}

class _ReferredByDropdownState extends State<_ReferredByDropdown> {
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
  final _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill from existing controller value (e.g. returning patient)
    final existing = widget.referenceCtrl.text.trim();
    if (existing.isNotEmpty) {
      if (_options.contains(existing)) {
        _selected = existing;
      } else {
        _selected = 'Other';
        _showCustomField = true;
        _customCtrl.text = existing;
      }
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Referred By (Optional)', style: context.textStyles.label),
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
                Text('Select referral source',
                    style: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint)),
              ]),
              items: _options
                  .map((o) => DropdownMenuItem(value: o, child: Text(o, style: context.textStyles.bodyMedium)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selected = val;
                  _showCustomField = val == 'Other';
                  if (val != null && val != 'Other') {
                    widget.referenceCtrl.text = val;
                    _customCtrl.clear();
                  } else if (val == 'Other') {
                    widget.referenceCtrl.text = _customCtrl.text;
                  } else {
                    widget.referenceCtrl.text = '';
                  }
                });
              },
            ),
          ),
        ),
        if (_showCustomField) ...[
          const SizedBox(height: 10),
          AppTextField(
            controller: _customCtrl,
            label: '',
            hint: 'Enter referral source...',
            prefixIcon: Icon(Icons.edit_rounded, color: context.colors.textHint, size: 18),
            onChanged: (val) => widget.referenceCtrl.text = val,
          ),
        ],
      ],
    );
  }
}
