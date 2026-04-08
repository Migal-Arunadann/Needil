import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/time_slot_picker.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/time_utils.dart';
import '../../providers/registration_cache_provider.dart';

// A break time range
class BreakTime {
  TimeOfDay? from;
  TimeOfDay? to;
  BreakTime({this.from, this.to});
}

class DayOverride {
  TimeOfDay? workFrom;
  TimeOfDay? workTo;
  List<BreakTime> breaks;

  DayOverride({
    this.workFrom,
    this.workTo,
    List<BreakTime>? breaks,
  }) : breaks = breaks ?? [];
}

/// Clinic Registration — Step 3 of 5: Primary Doctor details.
class ClinicStep3Screen extends ConsumerStatefulWidget {
  final Map<String, dynamic> clinicData;

  const ClinicStep3Screen({super.key, required this.clinicData});

  @override
  ConsumerState<ClinicStep3Screen> createState() => _ClinicStep3ScreenState();
}

class _ClinicStep3ScreenState extends ConsumerState<ClinicStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorNameController = TextEditingController();
  File? _doctorPhotoFile;
  DateTime? _dateOfBirth;

  // ── Working schedule ──
  final List<String> _allDays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  final Map<String, bool> _selectedDays = {
    'Monday': false, 'Tuesday': false, 'Wednesday': false,
    'Thursday': false, 'Friday': false, 'Saturday': false, 'Sunday': false,
  };

  TimeOfDay? _workFrom;
  TimeOfDay? _workTo;
  List<BreakTime> _globalBreaks = [];
  final Map<String, DayOverride?> _dayOverrides = {};
  String? _expandedDayOverride;

  // Treatments
  final List<String> _availableTreatments = [
    'Acupuncture', 'Acupressure', 'Cupping Therapy', 'Physiotherapy', 'Foot Reflexology',
  ];
  final Map<String, bool> _selectedTreatments = {};
  final Map<String, TextEditingController> _durationControllers = {};
  final Map<String, TextEditingController> _feeControllers = {};

  // Cache notifier saved early so we can call it safely in dispose()
  late final RegistrationCacheNotifier _cacheNotifier;

  @override
  void initState() {
    super.initState();
    _cacheNotifier = ref.read(registrationCacheProvider.notifier);
    final cache = ref.read(registrationCacheProvider);

    // Restore treatments (with cached values or defaults)
    for (final t in _availableTreatments) {
      _selectedTreatments[t] = cache.selectedTreatments[t] ?? false;
      _durationControllers[t] = TextEditingController(text: cache.treatmentDurations[t] ?? '30');
      _feeControllers[t] = TextEditingController(text: cache.treatmentFees[t] ?? '500');
    }

    // Restore simple fields
    if (cache.doctorName.isNotEmpty) _doctorNameController.text = cache.doctorName;
    _dateOfBirth = cache.doctorDob;
    if (cache.doctorPhotoPath != null) _doctorPhotoFile = File(cache.doctorPhotoPath!);

    // Restore schedule
    _workFrom = cache.workFrom;
    _workTo = cache.workTo;
    if (cache.selectedDays.isNotEmpty) {
      for (final e in cache.selectedDays.entries) {
        _selectedDays[e.key] = e.value;
      }
    }
    if (cache.globalBreaks.isNotEmpty) {
      _globalBreaks = cache.globalBreaks.map((b) => BreakTime(from: b.from, to: b.to)).toList();
    }
    if (cache.dayOverrides.isNotEmpty) {
      for (final e in cache.dayOverrides.entries) {
        _dayOverrides[e.key] = e.value == null ? null : DayOverride(
          workFrom: e.value!.workFrom,
          workTo: e.value!.workTo,
          breaks: e.value!.breaks.map((b) => BreakTime(from: b.from, to: b.to)).toList(),
        );
      }
    }
  }

  @override
  void dispose() {
    // Save all current state to cache before this screen is disposed
    _cacheNotifier.savePrimaryDoctor(
      name: _doctorNameController.text,
      dob: _dateOfBirth,
      photoPath: _doctorPhotoFile?.path,
      selectedDays: Map.from(_selectedDays),
      workFrom: _workFrom,
      workTo: _workTo,
      globalBreaks: _globalBreaks.map((b) => CachedBreak(from: b.from, to: b.to)).toList(),
      dayOverrides: {
        for (final e in _dayOverrides.entries)
          e.key: e.value == null ? null : CachedDayOverride(
            workFrom: e.value!.workFrom,
            workTo: e.value!.workTo,
            breaks: e.value!.breaks.map((b) => CachedBreak(from: b.from, to: b.to)).toList(),
          )
      },
      selectedTreatments: Map.from(_selectedTreatments),
      treatmentDurations: {for (final e in _durationControllers.entries) e.key: e.value.text},
      treatmentFees: {for (final e in _feeControllers.entries) e.key: e.value.text},
    );
    _doctorNameController.dispose();
    for (final c in _durationControllers.values) c.dispose();
    for (final c in _feeControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _pickDoctorPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Doctor Photo', style: AppTextStyles.h3),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
            ),
            title: const Text('Choose from Gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.camera_alt_rounded, color: AppColors.accent),
            ),
            title: const Text('Take a Photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) setState(() => _doctorPhotoFile = File(picked.path));
  }

  Future<void> _pickTime({
    required TimeOfDay? currentValue,
    required ValueChanged<TimeOfDay> onSelect,
    TimeOfDay? minTime,
    TimeOfDay? maxTime,
  }) async {
    // Dismiss keyboard and remove focus before showing picker
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(Duration.zero); // let unfocus settle
    final picked = await TimeSlotPicker.show(
      context,
      initialTime: currentValue ?? const TimeOfDay(hour: 9, minute: 0),
      intervalMinutes: 30,
      startHour: minTime?.hour ?? 5,
      endHour: maxTime?.hour ?? 23,
      minTime: minTime,
    );
    // Prevent focus restoration after modal closes
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    if (picked != null && mounted) setState(() => onSelect(picked));
  }

  String _fmt(TimeOfDay? t) => t == null ? 'Set' : TimeUtils.formatTimeOfDay(t);
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _toggleSelectAll() {
    FocusScope.of(context).unfocus();
    final allSelected = _selectedDays.values.every((v) => v);
    setState(() {
      for (final key in _selectedDays.keys) {
        _selectedDays[key] = !allSelected;
        if (allSelected) _dayOverrides.remove(key);
      }
    });
  }

  void _selectWeekdays() {
    FocusScope.of(context).unfocus();
    setState(() {
      for (final key in _selectedDays.keys) {
        final isWeekday = key != 'Saturday' && key != 'Sunday';
        _selectedDays[key] = isWeekday;
        if (!isWeekday) _dayOverrides.remove(key);
      }
    });
  }

  void _toggleDay(String day) {
    FocusScope.of(context).unfocus();
    setState(() {
      final wasSelected = _selectedDays[day] ?? false;
      _selectedDays[day] = !wasSelected;
      if (wasSelected) {
        _dayOverrides.remove(day);
        if (_expandedDayOverride == day) _expandedDayOverride = null;
      }
    });
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_dateOfBirth == null) { _showSnack('Please select date of birth'); return; }

    final selectedDays = _selectedDays.entries.where((e) => e.value).toList();
    if (selectedDays.isEmpty) { _showSnack('Please select at least one working day'); return; }
    if (_workFrom == null || _workTo == null) { _showSnack('Please set global working hours'); return; }

    if (!_isAfter(_workTo!, _workFrom!)) {
      _showSnack('Working "To" time must be after "From" time'); return;
    }

    // Validate global breaks
    for (int i = 0; i < _globalBreaks.length; i++) {
      final b = _globalBreaks[i];
      if (b.from == null || b.to == null) {
        _showSnack('Please complete Break ${i + 1} times'); return;
      }
      if (!_isAfter(b.to!, b.from!)) {
        _showSnack('Break ${i + 1} "To" must be after "From"'); return;
      }
      if (!_isWithin(b.from!, _workFrom!, _workTo!) || !_isWithin(b.to!, _workFrom!, _workTo!)) {
        _showSnack('Break ${i + 1} must be within working hours'); return;
      }
    }

    // Validate day overrides
    for (final dayInfo in selectedDays) {
      final override = _dayOverrides[dayInfo.key];
      if (override != null) {
        if (override.workFrom == null || override.workTo == null) {
          _showSnack('Please set override hours for ${dayInfo.key}'); return;
        }
        if (!_isAfter(override.workTo!, override.workFrom!)) {
          _showSnack('${dayInfo.key} "To" must be after "From"'); return;
        }
        for (int i = 0; i < override.breaks.length; i++) {
          final b = override.breaks[i];
          if (b.from == null || b.to == null) {
            _showSnack('Complete ${dayInfo.key} break ${i + 1}'); return;
          }
          if (!_isAfter(b.to!, b.from!)) {
            _showSnack('${dayInfo.key} break ${i + 1} "To" must be after "From"'); return;
          }
          if (!_isWithin(b.from!, override.workFrom!, override.workTo!) ||
              !_isWithin(b.to!, override.workFrom!, override.workTo!)) {
            _showSnack('${dayInfo.key} break ${i + 1} must be within its working hours'); return;
          }
        }
      }
    }

    final selectedTreatments = _selectedTreatments.entries.where((e) => e.value).toList();
    if (selectedTreatments.isEmpty) { _showSnack('Please select at least one treatment'); return; }

    // Build schedule
    final dob = '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}';

    final schedule = selectedDays.map((dayInfo) {
      final override = _dayOverrides[dayInfo.key];
      final wFrom = override?.workFrom ?? _workFrom!;
      final wTo = override?.workTo ?? _workTo!;
      final breaks = (override != null ? override.breaks : _globalBreaks)
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

    final treatments = selectedTreatments.map((t) => {
      'type': t.key,
      'duration_min': int.tryParse(_durationControllers[t.key]!.text) ?? 30,
      'fee': double.tryParse(_feeControllers[t.key]!.text) ?? 500,
    }).toList();

    Navigator.of(context).pushNamed('/register/clinic/step4', arguments: {
      ...widget.clinicData,
      'primary_doctor': {
        'name': _doctorNameController.text.trim(),
        'date_of_birth': dob,
        'working_schedule': schedule,
        'treatments': treatments,
        'photo_path': _doctorPhotoFile?.path,
      },
    });
  }

  bool _isAfter(TimeOfDay a, TimeOfDay b) {
    return a.hour > b.hour || (a.hour == b.hour && a.minute > b.minute);
  }

  bool _isWithin(TimeOfDay t, TimeOfDay from, TimeOfDay to) {
    final tMin = t.hour * 60 + t.minute;
    final fromMin = from.hour * 60 + from.minute;
    final toMin = to.hour * 60 + to.minute;
    return tMin >= fromMin && tMin <= toMin;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () { FocusScope.of(context).unfocus(); Navigator.of(context).pop(); },
          ),
          title: Text('Clinic Registration', style: AppTextStyles.h4),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildStepIndicator(3, 5),
                  const SizedBox(height: 24),
                  Text('Primary Doctor', style: AppTextStyles.h2),
                  const SizedBox(height: 6),
                  Text('Set up the primary doctor (clinic owner)',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),

                  // Photo
                  Center(child: GestureDetector(
                    onTap: _pickDoctorPhoto,
                    child: Stack(children: [
                      Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          gradient: _doctorPhotoFile == null ? AppColors.heroGradient : null,
                          borderRadius: BorderRadius.circular(28),
                          image: _doctorPhotoFile != null
                              ? DecorationImage(image: FileImage(_doctorPhotoFile!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _doctorPhotoFile == null
                            ? const Icon(Icons.person_rounded, color: Colors.white, size: 42) : null,
                      ),
                      Positioned(bottom: 0, right: 0,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 6),
                  Center(child: Text('Doctor Photo (Optional)',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))),
                  const SizedBox(height: 20),

                  // Name
                  AppTextField(
                    label: 'Doctor Name', hint: 'e.g. Dr. Sharma',
                    controller: _doctorNameController,
                    validator: (v) => Validators.required(v, 'Name'),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 16),

                  // DOB
                  GestureDetector(
                    onTap: () async {
                      FocusManager.instance.primaryFocus?.unfocus();
                      await Future.delayed(Duration.zero);
                      if (!mounted) return;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
                        firstDate: DateTime(1940),
                        lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: ColorScheme.light(primary: AppColors.primary, onPrimary: Colors.white, surface: AppColors.surface),
                          ),
                          child: child!,
                        ),
                      );
                      if (!mounted) return;
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (picked != null) setState(() => _dateOfBirth = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.cake_outlined, color: AppColors.textHint, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(
                          _dateOfBirth == null
                              ? 'Date of Birth'
                              : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: _dateOfBirth == null ? AppColors.textHint : AppColors.textPrimary),
                        )),
                        const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textHint),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const SizedBox(height: 32),

                  // Working Schedule
                  _buildScheduleSection(),
                  const SizedBox(height: 32),

                  // Treatments
                  Text('Treatments Offered', style: AppTextStyles.h3),
                  const SizedBox(height: 12),
                  ..._availableTreatments.map((t) => _buildTreatmentTile(t)),
                  const SizedBox(height: 32),

                  AppButton(
                    label: 'Next: Add Working Doctors',
                    onPressed: _next,
                    icon: Icons.arrow_forward_rounded,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    final selectedCount = _selectedDays.values.where((v) => v).length;
    final selectedDayNames = _selectedDays.entries.where((e) => e.value).map((e) => e.key).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Working Schedule', style: AppTextStyles.h3),
          const Spacer(),
          _quickAction('Weekdays', _selectWeekdays),
          const SizedBox(width: 8),
          _quickAction(_selectedDays.values.every((v) => v) ? 'Clear' : 'All', _toggleSelectAll),
        ]),
        const SizedBox(height: 6),
        Text('Select working days, then set global or day-specific hours.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 16),

        // Day chips
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _allDays.map((day) {
            final selected = _selectedDays[day] ?? false;
            return GestureDetector(
              onTap: () => _toggleDay(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.heroGradient : null,
                  color: selected ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? Colors.transparent : AppColors.border),
                  boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
                ),
                child: Text(day.substring(0, 3),
                  style: AppTextStyles.label.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text('$selectedCount day${selectedCount != 1 ? 's' : ''} selected',
          style: AppTextStyles.caption.copyWith(
            color: selectedCount > 0 ? AppColors.primary : AppColors.textHint)),

        if (selectedCount > 0) ...[
          const SizedBox(height: 20),

          // Global Working Hours
          _buildGlobalHoursCard(),
          const SizedBox(height: 14),

          // Global Break Times
          _buildGlobalBreaksCard(),

          const SizedBox(height: 24),
          Text('Day-Specific Overrides', style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text('Need half-days on weekends? Customize specific days here.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ...selectedDayNames.map((day) => _buildDayOverrideCard(day)),
        ],
      ],
    );
  }

  Widget _buildGlobalHoursCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.schedule_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Global Working Hours', style: AppTextStyles.label.copyWith(fontSize: 15)),
            Text('Applies to all selected days by default', style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _timePickerTile(
            label: 'From', value: _workFrom,
            onTap: () => _pickTime(currentValue: _workFrom, onSelect: (t) => _workFrom = t),
          )),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textHint)),
          Expanded(child: _timePickerTile(
            label: 'To', value: _workTo,
            onTap: () => _pickTime(currentValue: _workTo, onSelect: (t) => _workTo = t, minTime: _workFrom),
          )),
        ]),
      ]),
    );
  }

  Widget _buildGlobalBreaksCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _globalBreaks.isNotEmpty ? AppColors.warning.withValues(alpha: 0.04) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _globalBreaks.isNotEmpty ? AppColors.warning.withValues(alpha: 0.2) : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.coffee_rounded, color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Global Break Times', style: AppTextStyles.label.copyWith(fontSize: 15)),
            Text('Add one or more breaks applied to all days', style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ])),
          GestureDetector(
            onTap: () => setState(() => _globalBreaks.add(BreakTime())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: AppColors.warning, size: 16),
                const SizedBox(width: 4),
                Text('Add', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        ..._globalBreaks.asMap().entries.map((entry) {
          final i = entry.key;
          final b = entry.value;
          return _buildBreakRow(
            index: i,
            breakTime: b,
            workFrom: _workFrom,
            workTo: _workTo,
            onRemove: () => setState(() => _globalBreaks.removeAt(i)),
          );
        }),
        if (_globalBreaks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('No breaks added. Tap + Add to add a break.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          ),
      ]),
    );
  }

  Widget _buildBreakRow({
    required int index,
    required BreakTime breakTime,
    required TimeOfDay? workFrom,
    required TimeOfDay? workTo,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Break ${index + 1}', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 18, color: AppColors.error),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _timePickerTile(
            label: 'From', value: breakTime.from, isBreak: true,
            onTap: () => _pickTime(
              currentValue: breakTime.from,
              onSelect: (t) => breakTime.from = t,
              minTime: workFrom,
              maxTime: workTo,
            ),
          )),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textHint)),
          Expanded(child: _timePickerTile(
            label: 'To', value: breakTime.to, isBreak: true,
            onTap: () => _pickTime(
              currentValue: breakTime.to,
              onSelect: (t) => breakTime.to = t,
              minTime: breakTime.from ?? workFrom,
              maxTime: workTo,
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _buildDayOverrideCard(String day) {
    final hasOverride = _dayOverrides.containsKey(day) && _dayOverrides[day] != null;
    final isExpanded = _expandedDayOverride == day;
    final override = _dayOverrides[day];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasOverride ? AppColors.primary : AppColors.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() => _expandedDayOverride = isExpanded ? null : day);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Text(day, style: AppTextStyles.label.copyWith(fontSize: 15)),
              const Spacer(),
              if (hasOverride)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text('Customized', style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontSize: 11)),
                )
              else
                Text('Global Hours', style: AppTextStyles.caption.copyWith(color: AppColors.textHint, fontSize: 12)),
              const SizedBox(width: 12),
              Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AppColors.textHint),
            ]),
          ),
        ),
        if (isExpanded) ...[
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Use Custom Hours', style: AppTextStyles.label),
                Switch(
                  value: hasOverride,
                  onChanged: (v) {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      if (v) {
                        _dayOverrides[day] = DayOverride(
                          workFrom: _workFrom,
                          workTo: _workTo,
                          breaks: _globalBreaks.map((b) => BreakTime(from: b.from, to: b.to)).toList(),
                        );
                      } else {
                        _dayOverrides.remove(day);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                ),
              ]),
              if (hasOverride && override != null) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _timePickerTile(
                    label: 'From', value: override.workFrom,
                    onTap: () => _pickTime(currentValue: override.workFrom, onSelect: (t) => override.workFrom = t),
                  )),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textHint)),
                  Expanded(child: _timePickerTile(
                    label: 'To', value: override.workTo,
                    onTap: () => _pickTime(currentValue: override.workTo, onSelect: (t) => override.workTo = t, minTime: override.workFrom),
                  )),
                ]),
                const SizedBox(height: 16),
                // Override breaks
                Row(children: [
                  Text('Break Times', style: AppTextStyles.label.copyWith(fontSize: 13)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => override.breaks.add(BreakTime())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_rounded, color: AppColors.warning, size: 14),
                        const SizedBox(width: 2),
                        Text('Add', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontSize: 11)),
                      ]),
                    ),
                  ),
                ]),
                ...override.breaks.asMap().entries.map((entry) {
                  final i = entry.key;
                  return _buildBreakRow(
                    index: i,
                    breakTime: entry.value,
                    workFrom: override.workFrom,
                    workTo: override.workTo,
                    onRemove: () => setState(() => override.breaks.removeAt(i)),
                  );
                }),
                if (override.breaks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('No breaks added', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                  ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _timePickerTile({required String label, required TimeOfDay? value, required VoidCallback onTap, bool isBreak = false}) {
    final color = isBreak ? AppColors.warning : AppColors.primary;
    return GestureDetector(
      onTap: () { FocusScope.of(context).unfocus(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: value != null ? color.withValues(alpha: 0.06) : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: value != null ? color.withValues(alpha: 0.25) : AppColors.border),
        ),
        child: Column(children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 4),
          Text(_fmt(value), style: AppTextStyles.label.copyWith(
            color: value != null ? color : AppColors.textHint, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _quickAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontSize: 11)),
      ),
    );
  }

  Widget _buildTreatmentTile(String treatment) {
    final selected = _selectedTreatments[treatment] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AppColors.accent : AppColors.border),
      ),
      child: Column(children: [
        Row(children: [
          Checkbox(
            value: selected,
            onChanged: (v) { FocusScope.of(context).unfocus(); setState(() => _selectedTreatments[treatment] = v ?? false); },
            activeColor: AppColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          Expanded(child: Text(treatment, style: AppTextStyles.label)),
        ]),
        if (selected) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _miniField('Duration (min)', _durationControllers[treatment]!)),
            const SizedBox(width: 12),
            Expanded(child: _miniField('Fee (₹)', _feeControllers[treatment]!)),
          ]),
        ],
      ]),
    );
  }

  Widget _miniField(String label, TextEditingController controller) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.caption),
      const SizedBox(height: 4),
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
        ),
      ),
    ]);
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final step = i + 1;
        final isActive = step <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: step < total ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
