import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pms_app/core/widgets/app_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/time_slot_picker.dart';
import '../../../../core/utils/time_utils.dart';
import 'package:pms_app/features/auth/providers/auth_provider.dart';
import '../../auth/screens/clinic_registration/clinic_step3_screen.dart' show BreakTime, DayOverride;
import 'package:pms_app/core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';


class AddStaffDoctorScreen extends ConsumerStatefulWidget {
  const AddStaffDoctorScreen({super.key});

  @override
  ConsumerState<AddStaffDoctorScreen> createState() => _AddStaffDoctorScreenState();
}

class _AddStaffDoctorScreenState extends ConsumerState<AddStaffDoctorScreen> {
  static const List<String> _allDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const List<String> _availableTreatments = [
    'Acupuncture', 'Acupressure', 'Cupping Therapy', 'Physiotherapy', 'Foot Reflexology',
  ];

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  Timer? debounce;
  bool isCheckingUsername = false;
  String? usernameError;

  DateTime? dateOfBirth;
  File? photoFile;

  // Working schedule
  Map<String, bool> selectedDays = {
    'Monday': false, 'Tuesday': false, 'Wednesday': false,
    'Thursday': false, 'Friday': false, 'Saturday': false, 'Sunday': false,
  };
  TimeOfDay? workFrom;
  TimeOfDay? workTo;
  List<BreakTime> globalBreaks = [];
  Map<String, DayOverride?> dayOverrides = {};

  // Treatments
  Map<String, bool> selectedTreatments = {};
  Map<String, TextEditingController> durationControllers = {};
  Map<String, TextEditingController> feeControllers = {};

  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    for (final t in _availableTreatments) {
      selectedTreatments[t] = false;
      durationControllers[t] = TextEditingController(text: '30');
      feeControllers[t] = TextEditingController();
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    nameCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    for (final c in durationControllers.values) c.dispose();
    for (final c in feeControllers.values) c.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool error = true}) {
    if (!mounted) return;
    AppToast.show(msg, type: ToastType.error);
  }

  bool _isAfter(TimeOfDay a, TimeOfDay b) {
    if (a.hour > b.hour) return true;
    if (a.hour == b.hour && a.minute > b.minute) return true;
    return false;
  }

  bool _isWithin(TimeOfDay t, TimeOfDay start, TimeOfDay end) {
    if (_isAfter(start, t)) return false;
    if (_isAfter(t, end)) return false;
    return true;
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (nameCtrl.text.trim().isEmpty) { _showSnack('Name is required'); return; }
    if (usernameCtrl.text.trim().isEmpty) { _showSnack('Username is required'); return; }
    if (usernameError != null) { _showSnack(usernameError!); return; }
    if (passwordCtrl.text.trim().length < 8) { _showSnack('Password must be at least 8 characters'); return; }
    if (dateOfBirth == null) { _showSnack('Date of birth required'); return; }

    final days = selectedDays.entries.where((e) => e.value).toList();
    if (days.isEmpty) { _showSnack('Select at least one working day'); return; }
    if (workFrom == null || workTo == null) { _showSnack('Set working hours'); return; }
    if (!_isAfter(workTo!, workFrom!)) { _showSnack('"To" must be after "From"'); return; }

    for (int j = 0; j < globalBreaks.length; j++) {
      final b = globalBreaks[j];
      if (b.from == null || b.to == null) { _showSnack('Complete break ${j + 1}'); return; }
      if (!_isAfter(b.to!, b.from!)) { _showSnack('Break ${j + 1} "To" must be after "From"'); return; }
      if (!_isWithin(b.from!, workFrom!, workTo!) || !_isWithin(b.to!, workFrom!, workTo!)) {
        _showSnack('Break ${j + 1} must be within working hours'); return;
      }
    }

    final treatments = selectedTreatments.entries.where((e) => e.value).toList();
    if (treatments.isEmpty) { _showSnack('Select at least one treatment'); return; }

    for (final t in treatments) {
      final dur = durationControllers[t.key]!.text.trim();
      final fee = feeControllers[t.key]!.text.trim();
      if (dur.isEmpty || fee.isEmpty) {
        _showSnack('Please enter fee and duration for ${t.key}');
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final dob = '${dateOfBirth!.year}-${dateOfBirth!.month.toString().padLeft(2, '0')}-${dateOfBirth!.day.toString().padLeft(2, '0')}';
      final schedule = days.map((dayInfo) {
        final override = dayOverrides[dayInfo.key];
        final wFrom = override?.workFrom ?? workFrom!;
        final wTo = override?.workTo ?? workTo!;
        final breaks = (override != null ? override.breaks : globalBreaks)
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

      final mappedTreatments = selectedTreatments.entries
          .where((e) => e.value)
          .map((t) => {
                'type': t.key,
                'duration_min': int.tryParse(durationControllers[t.key]!.text) ?? 30,
                'fee': double.tryParse(feeControllers[t.key]!.text) ?? 0.0,
              })
          .toList();

      final docData = <String, dynamic>{
        'name': nameCtrl.text.trim(),
        'username': usernameCtrl.text.trim(),
        'password': passwordCtrl.text,
        'date_of_birth': dob,
        if (photoFile != null) 'photo_path': photoFile!.path,
        'working_schedule': schedule,
        'treatments': mappedTreatments,
      };

      final authService = ref.read(authProvider.notifier).authService;
      await authService.addDoctor(docData);
      
      _showSnack('Doctor added successfully!', error: false);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Failed to add doctor: ${e.toString()}');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800);
    if (picked != null) {
      final compressed = await ImageHelper.compressToWebP(picked);
      if (compressed != null) {
        setState(() => photoFile = File(compressed.path));
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = dateOfBirth ?? DateTime(now.year - 30);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 18), // Must be at least 18
    );
    if (picked != null) {
      setState(() => dateOfBirth = picked);
    }
  }

  Widget _responsiveRow(Widget left, Widget right, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 16),
          Expanded(child: right),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          left,
          const SizedBox(height: 12),
          right,
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: context.colors.textPrimary),
            onPressed: () => Navigator.pop(context, false),
          ),
          title: Text('Add Working Doctor', style: context.textStyles.h4),
          centerTitle: true,
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;

              final mainBody = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
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
                    const SizedBox(height: 24),
                  ] else ...[
                    Center(child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            gradient: photoFile == null ? context.colors.heroGradient : null,
                            borderRadius: BorderRadius.circular(22),
                            image: photoFile != null
                                ? DecorationImage(image: FileImage(photoFile!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: photoFile == null
                              ? Icon(Icons.person_rounded, color: context.colors.textPrimary, size: 36) : null,
                        ),
                        Positioned(bottom: 0, right: 0,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(color: context.colors.primary, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.textPrimary, width: 2)),
                            child: Icon(Icons.camera_alt_rounded, color: context.colors.textPrimary, size: 14),
                          )),
                      ]),
                    )),
                    const SizedBox(height: 24),
                  ],

                  // Name & Username
                  _responsiveRow(
                    _field('Full Name', 'e.g. Dr. John Doe', Icons.person_outline_rounded, controller: nameCtrl),
                    _field('Username', 'Login username', Icons.alternate_email_rounded,
                      controller: usernameCtrl,
                      errorText: usernameError,
                      suffixIcon: isCheckingUsername
                          ? Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.primary),
                              ),
                            )
                          : null,
                      onChanged: (val) {
                        if (debounce?.isActive ?? false) debounce!.cancel();
                        if (val.length < 3) {
                          setState(() => usernameError = null);
                          return;
                        }
                        setState(() => isCheckingUsername = true);
                        debounce = Timer(const Duration(milliseconds: 600), () async {
                          final authService = ref.read(authProvider.notifier).authService;
                          final exists = await authService.checkUsernameExists(val);
                          if (mounted) {
                            setState(() {
                              isCheckingUsername = false;
                              usernameError = exists ? 'Username is already taken' : null;
                            });
                          }
                        });
                      },
                    ),
                    isDesktop,
                  ),
                  const SizedBox(height: 12),

                  // Password & DOB
                  _responsiveRow(
                    _field('Password', 'Min 8 characters', Icons.lock_outline_rounded,
                      controller: passwordCtrl,
                      obscure: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: context.colors.textHint, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cake_outlined, color: context.colors.textHint, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              dateOfBirth == null ? 'Date of Birth' : '${dateOfBirth!.day}/${dateOfBirth!.month}/${dateOfBirth!.year}',
                              style: context.textStyles.bodyMedium.copyWith(color: dateOfBirth == null ? context.colors.textHint : context.colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    isDesktop,
                  ),
                  const SizedBox(height: 24),

                  // Schedule
                  Text('Working Schedule', style: context.textStyles.h3.copyWith(fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildDoctorHoursCard(),
                  const SizedBox(height: 12),
                  _buildDoctorBreaksCard(),
                  const SizedBox(height: 24),

                  // Treatments
                  Text('Treatments Offered', style: context.textStyles.h3.copyWith(fontSize: 16)),
                  const SizedBox(height: 10),
                  ..._availableTreatments.map((t) => _buildTreatmentTile(t)),
                  
                  const SizedBox(height: 40),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isDesktop ? 320 : double.infinity),
                      child: AppButton(
                        label: 'Add Doctor',
                        onPressed: _submit,
                        isLoading: _loading,
                        icon: Icons.add_circle_outline_rounded,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
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
                        child: mainBody,
                      ),
                    ),
                  ),
                );
              } else {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: mainBody,
                );
              }
            },
          ),
        ),
      ),
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
        filled: true,
        fillColor: context.colors.surface,
      ),
    );
  }

  Widget _buildDoctorHoursCard() {
    return Container(
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.colors.border)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Icon(Icons.date_range_rounded, size: 18, color: context.colors.primary),
              const SizedBox(width: 8),
              Text('Working Days & Hours', style: context.textStyles.label.copyWith(fontSize: 14)),
            ]),
          ),
          Divider(height: 1, color: context.colors.border, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: _allDays.map((day) {
                final isSelected = selectedDays[day] == true;
                return GestureDetector(
                  onTap: () => setState(() {
                    selectedDays[day] = !isSelected;
                    if (!selectedDays[day]!) dayOverrides.remove(day);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? context.colors.primary : context.colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isSelected ? context.colors.primary : context.colors.border),
                    ),
                    child: Text(day.substring(0, 3), style: context.textStyles.caption.copyWith(
                      color: isSelected ? Colors.white : context.colors.textHint,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    )),
                  ),
                );
              }).toList()),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _timeField('From', workFrom, (t) => setState(() => workFrom = t))),
                const SizedBox(width: 12),
                Expanded(child: _timeField('To', workTo, (t) => setState(() => workTo = t))),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorBreaksCard() {
    return Container(
      decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.colors.border)),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.coffee_rounded, size: 18, color: context.colors.warning),
                  const SizedBox(width: 8),
                  Text('Break Times', style: context.textStyles.label.copyWith(fontSize: 14)),
                ]),
                GestureDetector(
                  onTap: () => setState(() => globalBreaks.add(BreakTime())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: context.colors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text('+ Add Break', style: context.textStyles.caption.copyWith(color: context.colors.warning, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          if (globalBreaks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(child: Text('No breaks added.', style: context.textStyles.caption.copyWith(color: context.colors.textHint))),
            ),
          ...globalBreaks.asMap().entries.map((entry) {
            final idx = entry.key;
            final br = entry.value;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                Expanded(child: _timeField('Start', br.from, (t) => setState(() => br.from = t))),
                SizedBox(width: 8),
                Expanded(child: _timeField('End', br.to, (t) => setState(() => br.to = t))),
                IconButton(
                  icon: Icon(Icons.remove_circle_outline, color: context.colors.error, size: 20),
                  onPressed: () => setState(() => globalBreaks.removeAt(idx)),
                ),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTreatmentTile(String treatment) {
    final isSelected = selectedTreatments[treatment] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? context.colors.primary.withValues(alpha: 0.05) : context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? context.colors.primary.withValues(alpha: 0.3) : context.colors.border),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            title: Text(treatment, style: context.textStyles.label.copyWith(fontSize: 14)),
            value: isSelected,
            onChanged: (val) => setState(() => selectedTreatments[treatment] = val ?? false),
            activeColor: context.colors.primary,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            visualDensity: VisualDensity.compact,
          ),
          if (isSelected)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(child: _smallField('Duration (min)', durationControllers[treatment]!, TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _smallField('Fee (₹)', feeControllers[treatment]!, TextInputType.number)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? time, ValueChanged<TimeOfDay> onChanged) {
    return GestureDetector(
      onTap: () async {
        final t = await TimeSlotPicker.show(context, initialTime: time);
        if (t != null) onChanged(t);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(color: context.colors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: context.colors.border)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(time == null ? label : TimeUtils.formatTimeOfDay(time), style: context.textStyles.caption.copyWith(color: time == null ? context.colors.textHint : context.colors.textPrimary)),
            Icon(Icons.access_time_rounded, size: 16, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _smallField(String label, TextEditingController controller, TextInputType type) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: context.textStyles.caption,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: context.textStyles.caption.copyWith(color: context.colors.textHint, fontSize: 10),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.colors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: context.colors.primary)),
          filled: true, fillColor: context.colors.surface,
        ),
      ),
    );
  }
}
