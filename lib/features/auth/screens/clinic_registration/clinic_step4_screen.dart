import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pms_app/core/constants/app_colors.dart';
import 'package:pms_app/core/constants/app_text_styles.dart';
import 'package:pms_app/core/widgets/app_button.dart';
import 'package:pms_app/core/widgets/time_slot_picker.dart';
import 'package:pms_app/core/utils/time_utils.dart';
import 'dart:async';
import 'package:pms_app/features/auth/providers/registration_cache_provider.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import 'clinic_step3_screen.dart' show BreakTime, DayOverride;
import 'package:pms_app/core/theme/app_theme.dart';
import 'package:pms_app/core/utils/image_helper.dart';


// Full doctor data model used within step 4
class _WorkingDoctorData {
  // Text controllers for fields that don't need setState on every keystroke
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  Timer? debounce;
  bool isCheckingUsername = false;
  String? usernameError;

  DateTime? dateOfBirth;
  File? photoFile;

  // Working schedule
  Map<String, bool> selectedDays;
  TimeOfDay? workFrom;
  TimeOfDay? workTo;
  List<BreakTime> globalBreaks;
  Map<String, DayOverride?> dayOverrides;

  // Treatments
  Map<String, bool> selectedTreatments;
  Map<String, TextEditingController> durationControllers;
  Map<String, TextEditingController> feeControllers;

  _WorkingDoctorData()
      : selectedDays = {
          'Monday': false, 'Tuesday': false, 'Wednesday': false,
          'Thursday': false, 'Friday': false, 'Saturday': false, 'Sunday': false,
        },
        globalBreaks = [],
        dayOverrides = {},
        selectedTreatments = {},
        durationControllers = {},
        feeControllers = {};

  void dispose() {
    debounce?.cancel();
    nameCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
  }
}

/// Clinic Registration — Step 4 of 5: Add Working Doctors.
class ClinicStep4Screen extends ConsumerStatefulWidget {
  final Map<String, dynamic> clinicData;
  const ClinicStep4Screen({super.key, required this.clinicData});

  @override
  ConsumerState<ClinicStep4Screen> createState() => _ClinicStep4ScreenState();
}

class _ClinicStep4ScreenState extends ConsumerState<ClinicStep4Screen> {
  static const List<String> _allDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const List<String> _availableTreatments = [
    'Acupuncture', 'Acupressure', 'Cupping Therapy', 'Physiotherapy', 'Foot Reflexology',
  ];

  final List<_WorkingDoctorData> _doctors = [];
  int? _expandedIndex;

  late final RegistrationCacheNotifier _cacheNotifier;

  @override
  void initState() {
    super.initState();
    _cacheNotifier = ref.read(registrationCacheProvider.notifier);
    _restoreFromCache(ref.read(registrationCacheProvider));
  }

  void _restoreFromCache(RegistrationCacheState cache) {
    if (!cache.hasWorkingDoctors) return;
    final restored = <_WorkingDoctorData>[];
    for (final cached in cache.workingDoctors) {
      final doc = _WorkingDoctorData();
      doc.nameCtrl.text = cached.name;
      doc.usernameCtrl.text = cached.username;
      doc.passwordCtrl.text = cached.password;
      doc.dateOfBirth = cached.dob;
      doc.photoFile = cached.photoPath != null ? File(cached.photoPath!) : null;
      if (cached.selectedDays.isNotEmpty) {
        for (final e in cached.selectedDays.entries) doc.selectedDays[e.key] = e.value;
      }
      doc.workFrom = cached.workFrom;
      doc.workTo = cached.workTo;
      doc.globalBreaks = cached.globalBreaks.map((b) => BreakTime(from: b.from, to: b.to)).toList();
      for (final e in cached.dayOverrides.entries) {
        doc.dayOverrides[e.key] = e.value == null ? null : DayOverride(
          workFrom: e.value!.workFrom,
          workTo: e.value!.workTo,
          breaks: e.value!.breaks.map((b) => BreakTime(from: b.from, to: b.to)).toList(),
        );
      }
      for (final t in _availableTreatments) {
        doc.selectedTreatments[t] = cached.selectedTreatments[t] ?? false;
        doc.durationControllers[t] = TextEditingController(text: cached.treatmentDurations[t] ?? '30');
        doc.feeControllers[t] = TextEditingController(text: cached.treatmentFees[t] ?? '');
      }
      restored.add(doc);
    }
    _doctors.addAll(restored);
  }

  void _saveToCache() {
    final cached = _doctors.map((doc) => CachedWorkingDoctor(
      name: doc.nameCtrl.text,
      username: doc.usernameCtrl.text,
      password: doc.passwordCtrl.text,
      dob: doc.dateOfBirth,
      photoPath: doc.photoFile?.path,
      selectedDays: Map.from(doc.selectedDays),
      workFrom: doc.workFrom,
      workTo: doc.workTo,
      globalBreaks: doc.globalBreaks.map((b) => CachedBreak(from: b.from, to: b.to)).toList(),
      dayOverrides: {
        for (final e in doc.dayOverrides.entries)
          e.key: e.value == null ? null : CachedDayOverride(
            workFrom: e.value!.workFrom,
            workTo: e.value!.workTo,
            breaks: e.value!.breaks.map((b) => CachedBreak(from: b.from, to: b.to)).toList(),
          )
      },
      selectedTreatments: Map.from(doc.selectedTreatments),
      treatmentDurations: {for (final e in doc.durationControllers.entries) e.key: e.value.text},
      treatmentFees: {for (final e in doc.feeControllers.entries) e.key: e.value.text},
    )).toList();
    _cacheNotifier.saveWorkingDoctors(cached);
  }

  void _addDoctor() {
    final doc = _WorkingDoctorData();
    for (final t in _availableTreatments) {
      doc.selectedTreatments[t] = false;
      doc.durationControllers[t] = TextEditingController(text: '30');
      doc.feeControllers[t] = TextEditingController(text: ''); // null default
    }
    setState(() {
      _doctors.add(doc);
      _expandedIndex = _doctors.length - 1;
    });
  }

  void _removeDoctor(int index) {
    final doc = _doctors[index];
    for (final c in doc.durationControllers.values) c.dispose();
    for (final c in doc.feeControllers.values) c.dispose();
    setState(() {
      _doctors.removeAt(index);
      if (_expandedIndex == index) _expandedIndex = null;
      else if (_expandedIndex != null && _expandedIndex! > index) _expandedIndex = _expandedIndex! - 1;
    });
  }

  @override
  void dispose() {
    _saveToCache();
    for (final doc in _doctors) {
      doc.dispose(); // disposes nameCtrl, usernameCtrl, passwordCtrl
      for (final c in doc.durationControllers.values) c.dispose();
      for (final c in doc.feeControllers.values) c.dispose();
    }
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();

    final usedUsernames = <String>{widget.clinicData['username']};

    // Validate all doctors
    for (int i = 0; i < _doctors.length; i++) {
      final doc = _doctors[i];
      final label = 'Doctor ${i + 1}';
      final username = doc.usernameCtrl.text.trim();

      if (doc.nameCtrl.text.trim().isEmpty) { _showSnack('$label: Name is required'); return; }
      if (username.isEmpty) { _showSnack('$label: Username is required'); return; }
      if (usedUsernames.contains(username)) { _showSnack('$label: Username "$username" is already assigned within this clinic'); return; }
      usedUsernames.add(username);

      if (doc.usernameError != null) { _showSnack('$label: ${doc.usernameError}'); return; }
      if (doc.passwordCtrl.text.trim().length < 8) { _showSnack('$label: Password must be at least 8 characters'); return; }
      if (doc.dateOfBirth == null) { _showSnack('$label: Date of birth required'); return; }

      final selectedDays = doc.selectedDays.entries.where((e) => e.value).toList();
      if (selectedDays.isEmpty) { _showSnack('$label: Select at least one working day'); return; }
      if (doc.workFrom == null || doc.workTo == null) { _showSnack('$label: Set working hours'); return; }
      if (!_isAfter(doc.workTo!, doc.workFrom!)) { _showSnack('$label: "To" must be after "From"'); return; }

      for (int j = 0; j < doc.globalBreaks.length; j++) {
        final b = doc.globalBreaks[j];
        if (b.from == null || b.to == null) { _showSnack('$label: Complete break ${j + 1}'); return; }
        if (!_isAfter(b.to!, b.from!)) { _showSnack('$label: Break ${j + 1} "To" must be after "From"'); return; }
        if (!_isWithin(b.from!, doc.workFrom!, doc.workTo!) || !_isWithin(b.to!, doc.workFrom!, doc.workTo!)) {
          _showSnack('$label: Break ${j + 1} must be within working hours'); return;
        }
      }

      final selectedTreatments = doc.selectedTreatments.entries.where((e) => e.value).toList();
      if (selectedTreatments.isEmpty) { _showSnack('$label: Select at least one treatment'); return; }

      for (final t in selectedTreatments) {
        final dur = doc.durationControllers[t.key]!.text.trim();
        final fee = doc.feeControllers[t.key]!.text.trim();
        if (dur.isEmpty || fee.isEmpty) {
          _showSnack('$label: Please enter fee and duration for ${t.key}');
          return;
        }
      }
    }

    // Build doctor data list
    final additionalDoctors = _doctors.map((doc) {
      final selectedDays = doc.selectedDays.entries.where((e) => e.value).toList();
      final dob = '${doc.dateOfBirth!.year}-${doc.dateOfBirth!.month.toString().padLeft(2, '0')}-${doc.dateOfBirth!.day.toString().padLeft(2, '0')}';

      final schedule = selectedDays.map((dayInfo) {
        final override = doc.dayOverrides[dayInfo.key];
        final wFrom = override?.workFrom ?? doc.workFrom!;
        final wTo = override?.workTo ?? doc.workTo!;
        final breaks = (override != null ? override.breaks : doc.globalBreaks)
            .where((b) => b.from != null && b.to != null)
            .map((b) => {'start': _fmtTime(b.from!), 'end': _fmtTime(b.to!)})
            .toList();

        return <String, dynamic>{
          'day': dayInfo.key,
          'start': _fmtTime(wFrom),
          'end': _fmtTime(wTo),
          if (breaks.isNotEmpty) 'breaks': breaks,
        };
      }).toList();

      final treatments = doc.selectedTreatments.entries
          .where((e) => e.value)
          .map((t) => {
                'type': t.key,
                'duration_min': int.tryParse(doc.durationControllers[t.key]!.text) ?? 30,
                'fee': double.tryParse(doc.feeControllers[t.key]!.text) ?? 500,
              })
          .toList();

      return {
        'name': doc.nameCtrl.text,
        'username': doc.usernameCtrl.text,
        'password': doc.passwordCtrl.text,
        'date_of_birth': dob,
        'working_schedule': schedule,
        'treatments': treatments,
        'photo_path': doc.photoFile?.path,
      };
    }).toList();

    Navigator.of(context).pushNamed('/register/clinic/step5', arguments: {
      ...widget.clinicData,
      'additional_doctors': additionalDoctors.isNotEmpty ? additionalDoctors : null,
    });
  }

  bool _isAfter(TimeOfDay a, TimeOfDay b) =>
      a.hour > b.hour || (a.hour == b.hour && a.minute > b.minute);

  bool _isWithin(TimeOfDay t, TimeOfDay from, TimeOfDay to) {
    final tMin = t.hour * 60 + t.minute;
    return tMin >= from.hour * 60 + from.minute && tMin <= to.hour * 60 + to.minute;
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: context.colors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
            onPressed: () { FocusScope.of(context).unfocus(); Navigator.of(context).pop(); },
          ),
          title: Text('Clinic Registration', style: context.textStyles.h4),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _buildStepIndicator(4, 5),
                const SizedBox(height: 24),
                Text('Working Doctors', style: context.textStyles.h2),
                const SizedBox(height: 6),
                Text('Add doctors who work at your clinic. They get their own login.',
                  style: context.textStyles.bodyMedium.copyWith(color: context.colors.textSecondary)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.info.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.info.withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, color: context.colors.info, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Optional — You can also add doctors later from Settings.',
                      style: context.textStyles.caption.copyWith(color: context.colors.info))),
                  ]),
                ),
                const SizedBox(height: 24),

                // Doctor cards
                ..._doctors.asMap().entries.map((entry) {
                  final i = entry.key;
                  final doc = entry.value;
                  return _buildDoctorCard(i, doc);
                }),

                // Add Doctor button
                GestureDetector(
                  onTap: _addDoctor,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: context.colors.accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_circle_outline_rounded, color: context.colors.accent, size: 22),
                      const SizedBox(width: 10),
                      Text('Add Working Doctor',
                        style: context.textStyles.bodyMedium.copyWith(color: context.colors.accent, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),

                AppButton(
                  label: _doctors.isEmpty ? 'Skip — No Working Doctors' : 'Next: Receptionist',
                  onPressed: _next,
                  icon: Icons.arrow_forward_rounded,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoctorCard(int index, _WorkingDoctorData doc) {
    final isExpanded = _expandedIndex == index;
    final hasName = doc.nameCtrl.text.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.accent.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: context.colors.accent.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () { FocusScope.of(context).unfocus(); setState(() => _expandedIndex = isExpanded ? null : index); },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: context.colors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  image: !kIsWeb && doc.photoFile != null
                      ? DecorationImage(image: FileImage(doc.photoFile!), fit: BoxFit.cover)
                      : null,
                ),
                child: (kIsWeb || doc.photoFile == null) ? Icon(Icons.person_rounded, color: context.colors.accent, size: 22) : null,
              ),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hasName ? doc.nameCtrl.text : 'Doctor ${index + 1}',
                  style: context.textStyles.label.copyWith(fontSize: 15, color: hasName ? context.colors.textPrimary : context.colors.textHint)),
                if (doc.usernameCtrl.text.isNotEmpty)
                  Text('@${doc.usernameCtrl.text}', style: context.textStyles.caption.copyWith(color: context.colors.textHint, fontSize: 11)),
              ])),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: context.colors.error, size: 20),
                onPressed: () => _removeDoctor(index),
              ),
              Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: context.colors.textHint),
            ]),
          ),
        ),

        if (isExpanded) ...[
          Divider(height: 1, color: context.colors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Photo
              if (kIsWeb) ...[
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_outline_rounded, color: context.colors.textHint, size: 48),
                      const SizedBox(height: 6),
                      Text(
                        'Doctor photo upload is available on the mobile app.',
                        style: context.textStyles.caption.copyWith(color: context.colors.textHint),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Center(child: GestureDetector(
                  onTap: () => _pickPhoto(doc),
                  child: Stack(children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: doc.photoFile == null ? context.colors.heroGradient : null,
                        borderRadius: BorderRadius.circular(22),
                        image: doc.photoFile != null
                            ? DecorationImage(image: FileImage(doc.photoFile!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: doc.photoFile == null
                          ? const Icon(Icons.person_rounded, color: Colors.white, size: 36) : null,
                    ),
                    Positioned(bottom: 0, right: 0,
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                      )),
                  ]),
                )),
                const SizedBox(height: 6),
                Center(child: Text('Photo (Optional)', style: context.textStyles.caption.copyWith(color: context.colors.textSecondary))),
                const SizedBox(height: 16),
              ],

              // Name
              _field('Doctor Name', 'e.g. Dr. Vijayan', Icons.person_outline_rounded, controller: doc.nameCtrl),
              SizedBox(height: 12),

              // Username
              _field('Username', 'Login username', Icons.alternate_email_rounded,
                controller: doc.usernameCtrl,
                errorText: doc.usernameError,
                suffixIcon: doc.isCheckingUsername
                    ? Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary),
                        ),
                      )
                    : null,
                onChanged: (val) {
                  if (doc.debounce?.isActive ?? false) doc.debounce!.cancel();
                  if (val.length < 3) {
                    setState(() => doc.usernameError = null);
                    return;
                  }
                  setState(() => doc.isCheckingUsername = true);
                  doc.debounce = Timer(const Duration(milliseconds: 600), () async {
                    final authService = ref.read(authProvider.notifier).authService;
                    final exists = await authService.checkUsernameExists(val);
                    if (mounted) {
                      setState(() {
                        doc.isCheckingUsername = false;
                        doc.usernameError = exists ? 'Username is already taken' : null;
                      });
                    }
                  });
                },
              ),
              const SizedBox(height: 12),

              // Password
              _field('Password', 'Min 8 characters', Icons.lock_outline_rounded, controller: doc.passwordCtrl, obscure: true),
              const SizedBox(height: 16),

              // DOB
              GestureDetector(
                onTap: () async {
                  FocusManager.instance.primaryFocus?.unfocus();
                  await Future.delayed(Duration.zero);
                  if (!mounted) return;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: doc.dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
                    firstDate: DateTime(1940),
                    lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                    locale: const Locale('en', 'IN'),
                  );
                  if (!mounted) return;
                  FocusManager.instance.primaryFocus?.unfocus();
                  if (picked != null) setState(() => doc.dateOfBirth = picked);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.colors.surface, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.cake_outlined, color: context.colors.textHint, size: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text(
                      doc.dateOfBirth == null
                          ? 'Date of Birth'
                          : '${doc.dateOfBirth!.day.toString().padLeft(2, '0')}/${doc.dateOfBirth!.month.toString().padLeft(2, '0')}/${doc.dateOfBirth!.year}',
                      style: context.textStyles.bodyMedium.copyWith(
                        color: doc.dateOfBirth == null ? context.colors.textHint : context.colors.textPrimary),
                    )),
                    Icon(Icons.calendar_today_rounded, size: 16, color: context.colors.textHint),
                  ]),
                ),
              ),
              const SizedBox(height: 20),

              // Working schedule
              Text('Working Schedule', style: context.textStyles.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 10),
              _buildDayChips(doc),

              if (doc.selectedDays.values.any((v) => v)) ...[
                const SizedBox(height: 14),
                _buildDoctorHoursCard(doc),
                const SizedBox(height: 12),
                _buildDoctorBreaksCard(doc),
              ],
              const SizedBox(height: 20),

              // Treatments
              Text('Treatments Offered', style: context.textStyles.h3.copyWith(fontSize: 16)),
              const SizedBox(height: 10),
              ..._availableTreatments.map((t) => _buildTreatmentTile(doc, t)),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _field(String label, String hint, IconData icon, {required TextEditingController controller, bool obscure = false, String? errorText, void Function(String)? onChanged, Widget? suffixIcon}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      validator: (v) {
        if (errorText != null) return errorText;
        return null;
      },
      style: context.textStyles.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        hintStyle: context.textStyles.bodyMedium.copyWith(color: context.colors.textHint),
        labelStyle: context.textStyles.caption.copyWith(color: context.colors.textHint),
        prefixIcon: Icon(icon, color: context.colors.textHint, size: 20),
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.colors.primary)),
        filled: true, fillColor: context.colors.surface,
      ),
    );
  }

  void _pickPhoto(_WorkingDoctorData doc) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Doctor Photo', style: context.textStyles.h3),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.photo_library_rounded, color: context.colors.primary),
            title: const Text('Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: Icon(Icons.camera_alt_rounded, color: context.colors.accent),
            title: const Text('Camera'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 60);
      if (picked != null && mounted) {
        final compressed = await ImageHelper.compressToWebP(picked);
        if (compressed != null && mounted) {
          setState(() => doc.photoFile = File(compressed.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: context.colors.error,
        ));
      }
    }
  }

  Widget _buildDayChips(_WorkingDoctorData doc) {
    final allSelected = doc.selectedDays.values.every((v) => v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Wrap(
            spacing: 8, runSpacing: 8,
            children: _allDays.map((day) {
              final selected = doc.selectedDays[day] ?? false;
              return GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    doc.selectedDays[day] = !selected;
                    if (selected) doc.dayOverrides.remove(day);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: selected ? context.colors.heroGradient : null,
                    color: selected ? null : context.colors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? Colors.transparent : context.colors.border),
                  ),
                  child: Text(day.substring(0, 3), style: context.textStyles.label.copyWith(
                    color: selected ? Colors.white : context.colors.textSecondary, fontSize: 13)),
                ),
              );
            }).toList(),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _dayShortcut('Weekdays', () {
            setState(() {
              for (final k in doc.selectedDays.keys) {
                final isWeekday = k != 'Saturday' && k != 'Sunday';
                doc.selectedDays[k] = isWeekday;
                if (!isWeekday) doc.dayOverrides.remove(k);
              }
            });
          }),
          const SizedBox(width: 8),
          _dayShortcut(allSelected ? 'Clear All' : 'All Days', () {
            setState(() {
              for (final k in doc.selectedDays.keys) {
                doc.selectedDays[k] = !allSelected;
                if (allSelected) doc.dayOverrides.remove(k);
              }
            });
          }),
        ]),
      ],
    );
  }

  Widget _dayShortcut(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: context.textStyles.caption.copyWith(color: context.colors.primary, fontSize: 11)),
      ),
    );
  }

  Widget _buildDoctorHoursCard(_WorkingDoctorData doc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Working Hours', style: context.textStyles.label.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _tpTile('From', doc.workFrom, false,
            () => _pickDocTime(doc.workFrom, (t) => doc.workFrom = t, null, null))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded, size: 16, color: context.colors.textHint)),
          Expanded(child: _tpTile('To', doc.workTo, false,
            () => _pickDocTime(doc.workTo, (t) => doc.workTo = t, doc.workFrom, null))),
        ]),
      ]),
    );
  }

  Widget _buildDoctorBreaksCard(_WorkingDoctorData doc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: doc.globalBreaks.isNotEmpty ? context.colors.warning.withValues(alpha: 0.04) : context.colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: doc.globalBreaks.isNotEmpty ? context.colors.warning.withValues(alpha: 0.2) : context.colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Break Times', style: context.textStyles.label.copyWith(fontSize: 13)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => doc.globalBreaks.add(BreakTime())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: context.colors.warning, size: 14),
                const SizedBox(width: 2),
                Text('Add', style: context.textStyles.caption.copyWith(color: context.colors.warning, fontSize: 11)),
              ]),
            ),
          ),
        ]),
        ...doc.globalBreaks.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Break ${i + 1}', style: context.textStyles.caption.copyWith(color: context.colors.warning, fontWeight: FontWeight.w600, fontSize: 11)),
                const Spacer(),
                GestureDetector(onTap: () => setState(() => doc.globalBreaks.removeAt(i)),
                  child: Icon(Icons.close_rounded, size: 16, color: context.colors.error)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _tpTile('From', b.from, true,
                  () => _pickDocTime(b.from, (t) => b.from = t, doc.workFrom, doc.workTo))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, size: 16, color: context.colors.textHint)),
                Expanded(child: _tpTile('To', b.to, true,
                  () => _pickDocTime(b.to, (t) => b.to = t, b.from ?? doc.workFrom, doc.workTo))),
              ]),
            ]),
          );
        }),
        if (doc.globalBreaks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No breaks added. Tap + Add.', style: context.textStyles.caption.copyWith(color: context.colors.textHint)),
          ),
      ]),
    );
  }

  Widget _tpTile(String label, TimeOfDay? value, bool isBreak, VoidCallback onTap) {
    final color = isBreak ? context.colors.warning : context.colors.primary;
    return GestureDetector(
      onTap: () { FocusScope.of(context).unfocus(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: value != null ? color.withValues(alpha: 0.06) : context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: value != null ? color.withValues(alpha: 0.25) : context.colors.border),
        ),
        child: Column(children: [
          Text(label, style: context.textStyles.caption.copyWith(fontSize: 10, color: context.colors.textHint)),
          const SizedBox(height: 3),
          Text(value == null ? 'Set' : TimeUtils.formatTimeOfDay(value),
            style: context.textStyles.label.copyWith(color: value != null ? color : context.colors.textHint, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Future<void> _pickDocTime(TimeOfDay? current, ValueChanged<TimeOfDay> onSelect, TimeOfDay? minTime, TimeOfDay? maxTime) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    final picked = await TimeSlotPicker.show(
      context,
      initialTime: current ?? const TimeOfDay(hour: 9, minute: 0),
      intervalMinutes: 30,
      startHour: minTime?.hour ?? 5,
      startMinute: minTime?.minute ?? 0,
      endHour: maxTime?.hour ?? 23,
      minTime: minTime,
    );
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (picked != null) setState(() => onSelect(picked));
  }

  Widget _buildTreatmentTile(_WorkingDoctorData doc, String treatment) {
    final selected = doc.selectedTreatments[treatment] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? context.colors.accent.withValues(alpha: 0.05) : context.colors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? context.colors.accent : context.colors.border),
      ),
      child: Column(children: [
        Row(children: [
          Checkbox(
            value: selected,
            onChanged: (v) { FocusScope.of(context).unfocus(); setState(() => doc.selectedTreatments[treatment] = v ?? false); },
            activeColor: context.colors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(child: Text(treatment, style: context.textStyles.label.copyWith(fontSize: 14))),
        ]),
        if (selected) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _miniField('Duration (min)', doc.durationControllers[treatment]!)),
            const SizedBox(width: 10),
            Expanded(child: _miniField('Fee (₹)', doc.feeControllers[treatment]!)),
          ]),
        ],
      ]),
    );
  }

  Widget _miniField(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: context.textStyles.caption.copyWith(fontSize: 11)),
      SizedBox(height: 3),
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        autofocus: false,
        style: context.textStyles.bodyMedium.copyWith(fontSize: 13),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.colors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.colors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.colors.accent)),
        ),
      ),
    ]);
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final step = i + 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: step < total ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: step <= current ? context.colors.primary : context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
