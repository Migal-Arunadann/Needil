import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/time_slot_picker.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/time_utils.dart';
import '../../providers/auth_provider.dart';

class DayOverride {
  TimeOfDay? workFrom;
  TimeOfDay? workTo;
  bool hasBreak;
  TimeOfDay? breakFrom;
  TimeOfDay? breakTo;

  DayOverride({
    this.workFrom,
    this.workTo,
    this.hasBreak = true,
    this.breakFrom,
    this.breakTo,
  });
}

/// Clinic Registration — Step 3: Primary Doctor details.
class ClinicStep3Screen extends ConsumerStatefulWidget {
  final Map<String, dynamic> clinicData;

  const ClinicStep3Screen({super.key, required this.clinicData});

  @override
  ConsumerState<ClinicStep3Screen> createState() => _ClinicStep3ScreenState();
}

class _ClinicStep3ScreenState extends ConsumerState<ClinicStep3Screen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorNameController = TextEditingController();
  final _doctorUsernameController = TextEditingController();
  final _doctorPasswordController = TextEditingController();
  final _doctorConfirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  DateTime? _dateOfBirth;

  // ── Working schedule ──
  final List<String> _allDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final Map<String, bool> _selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };

  // Unified working hours (same for all selected days)
  TimeOfDay? _workFrom;
  TimeOfDay? _workTo;

  // Unified break time (applied to all selected days)
  bool _hasBreak = true;
  TimeOfDay? _breakFrom;
  TimeOfDay? _breakTo;

  // Specific Day Overrides (e.g., half days on weekends)
  final Map<String, DayOverride?> _dayOverrides = {};
  String? _expandedDayOverride;

  // Treatments
  final List<String> _availableTreatments = [
    'Acupuncture',
    'Acupressure',
    'Cupping Therapy',
    'Physiotherapy',
    'Foot Reflexology',
  ];
  final Map<String, bool> _selectedTreatments = {};
  final Map<String, TextEditingController> _durationControllers = {};
  final Map<String, TextEditingController> _feeControllers = {};

  @override
  void initState() {
    super.initState();
    for (final t in _availableTreatments) {
      _selectedTreatments[t] = false;
      _durationControllers[t] = TextEditingController(text: '30');
      _feeControllers[t] = TextEditingController(text: '500');
    }
  }

  @override
  void dispose() {
    _doctorNameController.dispose();
    _doctorUsernameController.dispose();
    _doctorPasswordController.dispose();
    _doctorConfirmPasswordController.dispose();
    for (final c in _durationControllers.values) {
      c.dispose();
    }
    for (final c in _feeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime({
    required String label,
    required TimeOfDay? currentValue,
    required ValueChanged<TimeOfDay> onSelect,
    TimeOfDay? minTime,
  }) async {
    // Unfocus keyword before showing time picker
    FocusScope.of(context).unfocus();

    final picked = await TimeSlotPicker.show(
      context,
      initialTime: currentValue ?? const TimeOfDay(hour: 9, minute: 0),
      intervalMinutes: 30,
      startHour: 5,
      endHour: 23,
      minTime: minTime,
    );
    if (picked != null) {
      setState(() => onSelect(picked));
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Set';
    return TimeUtils.formatTimeOfDay(time);
  }

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

  void _submit() async {
    FocusScope.of(context).unfocus();
    
    if (!_formKey.currentState!.validate()) return;

    if (_dateOfBirth == null) {
      _showSnack('Please select the doctor\'s date of birth');
      return;
    }

    final selectedDays = _selectedDays.entries.where((e) => e.value).toList();
    if (selectedDays.isEmpty) {
      _showSnack('Please select at least one working day');
      return;
    }

    if (_workFrom == null || _workTo == null) {
      _showSnack('Please set global working hours (From and To)');
      return;
    }

    if (_workFrom!.hour > _workTo!.hour ||
        (_workFrom!.hour == _workTo!.hour &&
            _workFrom!.minute >= _workTo!.minute)) {
      _showSnack('Global working "To" time must be after "From" time');
      return;
    }

    if (_hasBreak) {
      if (_breakFrom == null || _breakTo == null) {
        _showSnack('Please set global break times or disable break');
        return;
      }
      if (_breakFrom!.hour > _breakTo!.hour ||
          (_breakFrom!.hour == _breakTo!.hour &&
              _breakFrom!.minute >= _breakTo!.minute)) {
        _showSnack('Global break "To" time must be after "From" time');
        return;
      }
    }

    // Validate specific overrides
    for (final dayInfo in selectedDays) {
      final override = _dayOverrides[dayInfo.key];
      if (override != null) {
        if (override.workFrom == null || override.workTo == null) {
          _showSnack('Please set override hours for ${dayInfo.key}');
          return;
        }
        if (override.workFrom!.hour > override.workTo!.hour ||
            (override.workFrom!.hour == override.workTo!.hour &&
                override.workFrom!.minute >= override.workTo!.minute)) {
          _showSnack('${dayInfo.key} "To" time must be after "From" time');
          return;
        }
        if (override.hasBreak) {
          if (override.breakFrom == null || override.breakTo == null) {
            _showSnack('Please set override break for ${dayInfo.key}');
            return;
          }
          if (override.breakFrom!.hour > override.breakTo!.hour ||
              (override.breakFrom!.hour == override.breakTo!.hour &&
                  override.breakFrom!.minute >= override.breakTo!.minute)) {
            _showSnack('${dayInfo.key} break "To" time must be after "From" time');
            return;
          }
        }
      }
    }

    final selectedTreatments =
        _selectedTreatments.entries.where((e) => e.value).toList();
    if (selectedTreatments.isEmpty) {
      _showSnack('Please select at least one treatment');
      return;
    }

    final dob =
        '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}';

    final schedule = selectedDays.map((dayInfo) {
      final override = _dayOverrides[dayInfo.key];
      final wFrom = override?.workFrom ?? _workFrom!;
      final wTo = override?.workTo ?? _workTo!;
      final hBreak = override?.hasBreak ?? _hasBreak;
      final bFrom = override?.breakFrom ?? _breakFrom;
      final bTo = override?.breakTo ?? _breakTo;

      final map = <String, dynamic>{
        'day': dayInfo.key,
        'start': _fmtTime(wFrom),
        'end': _fmtTime(wTo),
      };
      if (hBreak && bFrom != null && bTo != null) {
        map['break_start'] = _fmtTime(bFrom);
        map['break_end'] = _fmtTime(bTo);
      }
      return map;
    }).toList();

    final treatments = selectedTreatments.map((t) {
      return {
        'type': t.key,
        'duration_min': int.tryParse(_durationControllers[t.key]!.text) ?? 30,
        'fee': double.tryParse(_feeControllers[t.key]!.text) ?? 500,
      };
    }).toList();

    final primaryDoctorData = {
      'name': _doctorNameController.text.trim(),
      'date_of_birth': dob,
      'username': _doctorUsernameController.text.trim(),
      'password': _doctorPasswordController.text,
      'working_schedule': schedule,
      'treatments': treatments,
    };

    await ref.read(authProvider.notifier).registerClinic(
          clinicName: widget.clinicData['clinic_name'],
          username: widget.clinicData['username'],
          password: widget.clinicData['password'],
          bedCount: widget.clinicData['bed_count'],
          primaryDoctorData: primaryDoctorData,
        );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.error != null) {
        _showSnack(next.error!);
        ref.read(authProvider.notifier).clearError();
      }
      if (next.isAuthenticated) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/dashboard', (route) => false);
      }
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textPrimary),
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Clinic Registration', style: AppTextStyles.h4),
          centerTitle: true,
        ),
        body: LoadingOverlay(
          isLoading: authState.isLoading,
          message: 'Creating your clinic...',
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildStepIndicator(3, 3),
                    const SizedBox(height: 24),
                    Text('Primary Doctor', style: AppTextStyles.h2),
                    const SizedBox(height: 8),
                    Text(
                      'Set up the primary doctor for your clinic',
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),

                    // ── Doctor basic info ───────────────────────────
                    AppTextField(
                      label: 'Doctor Name',
                      hint: 'e.g. Dr. Sharma',
                      controller: _doctorNameController,
                      validator: (v) => Validators.required(v, 'Name'),
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          color: AppColors.textHint),
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth picker
                    GestureDetector(
                      onTap: () async {
                        FocusScope.of(context).unfocus();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dateOfBirth ??
                              DateTime.now()
                                  .subtract(const Duration(days: 365 * 30)),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now()
                              .subtract(const Duration(days: 365 * 18)),
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
                          setState(() => _dateOfBirth = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined,
                                color: AppColors.textHint, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _dateOfBirth == null
                                    ? 'Date of Birth'
                                    : '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: _dateOfBirth == null
                                      ? AppColors.textHint
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_rounded,
                                size: 16, color: AppColors.textHint),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      label: 'Doctor Username',
                      hint: 'Login username for doctor',
                      controller: _doctorUsernameController,
                      validator: (v) => Validators.minLength(v, 3, 'Username'),
                      prefixIcon: const Icon(Icons.alternate_email_rounded,
                          color: AppColors.textHint),
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      label: 'Doctor Password',
                      hint: 'Min. 8 characters',
                      controller: _doctorPasswordController,
                      obscureText: _obscurePassword,
                      validator: Validators.password,
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.textHint),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textHint,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      label: 'Confirm Doctor Password',
                      hint: 'Re-enter password',
                      controller: _doctorConfirmPasswordController,
                      obscureText: _obscureConfirm,
                      validator: (v) => Validators.confirmPassword(
                          v, _doctorPasswordController.text),
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          color: AppColors.textHint),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textHint,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Working Schedule ────────────────────────────
                    _buildScheduleSection(),
                    const SizedBox(height: 32),

                    // ── Treatments ──────────────────────────────────
                    Text('Treatments Offered', style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    ..._availableTreatments.map((t) => _buildTreatmentTile(t)),
                    const SizedBox(height: 32),

                    AppButton(
                      label: 'Create Clinic',
                      onPressed: _submit,
                      isLoading: authState.isLoading,
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Schedule Section ─────────────────────────────────────────
  Widget _buildScheduleSection() {
    final selectedCount = _selectedDays.values.where((v) => v).length;
    final selectedDayNames = _selectedDays.entries.where((e) => e.value).map((e) => e.key).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Working Schedule', style: AppTextStyles.h3),
            const Spacer(),
            _quickAction('Weekdays', _selectWeekdays),
            const SizedBox(width: 8),
            _quickAction(
              _selectedDays.values.every((v) => v) ? 'Clear' : 'All',
              _toggleSelectAll,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Select working days, then set global or day-specific hours.',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),

        // ── Day Chips ──
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allDays.map((day) {
            final selected = _selectedDays[day] ?? false;
            return GestureDetector(
              onTap: () => _toggleDay(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected ? AppColors.heroGradient : null,
                  color: selected ? null : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        selected ? Colors.transparent : AppColors.border,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  day.substring(0, 3),
                  style: AppTextStyles.label.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          '$selectedCount day${selectedCount != 1 ? 's' : ''} selected',
          style: AppTextStyles.caption.copyWith(
            color: selectedCount > 0
                ? AppColors.primary
                : AppColors.textHint,
          ),
        ),

        if (selectedCount > 0) ...[
          const SizedBox(height: 20),

          // ── Global Working Hours ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.schedule_rounded,
                          color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Global Working Hours',
                            style: AppTextStyles.label.copyWith(fontSize: 15)),
                        Text('Applies to all days by default',
                            style: AppTextStyles.caption.copyWith(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _timePickerTile(
                        label: 'From',
                        value: _workFrom,
                        onTap: () => _pickTime(
                          label: 'From',
                          currentValue: _workFrom,
                          onSelect: (t) => _workFrom = t,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 18, color: AppColors.textHint),
                    ),
                    Expanded(
                      child: _timePickerTile(
                        label: 'To',
                        value: _workTo,
                        onTap: () => _pickTime(
                          label: 'To',
                          currentValue: _workTo,
                          onSelect: (t) => _workTo = t,
                          minTime: _workFrom,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Global Break Time ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hasBreak
                  ? AppColors.warning.withValues(alpha: 0.04)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasBreak
                    ? AppColors.warning.withValues(alpha: 0.2)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.coffee_rounded,
                          color: AppColors.warning, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Global Break Time',
                              style:
                                  AppTextStyles.label.copyWith(fontSize: 15)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _hasBreak,
                      onChanged: (v) => setState(() => _hasBreak = v),
                      activeColor: AppColors.warning,
                    ),
                  ],
                ),
                if (_hasBreak) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _timePickerTile(
                          label: 'From',
                          value: _breakFrom,
                          isBreak: true,
                          onTap: () => _pickTime(
                            label: 'Break From',
                            currentValue: _breakFrom,
                            onSelect: (t) => _breakFrom = t,
                            minTime: _workFrom,
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 18, color: AppColors.textHint),
                      ),
                      Expanded(
                        child: _timePickerTile(
                          label: 'To',
                          value: _breakTo,
                          isBreak: true,
                          onTap: () => _pickTime(
                            label: 'Break To',
                            currentValue: _breakTo,
                            onSelect: (t) => _breakTo = t,
                            minTime: _breakFrom,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text('Day-Specific Overrides', style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(
            'Need half-days on weekends? Customize specific days here.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // ── Day Overrides List ──
          ...selectedDayNames.map((day) => _buildDayOverrideCard(day)),
        ],
      ],
    );
  }

  Widget _buildDayOverrideCard(String day) {
    final hasOverride = _dayOverrides.containsKey(day) && _dayOverrides[day] != null;
    final isExpanded = _expandedDayOverride == day;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: hasOverride ? AppColors.primary : AppColors.border),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                if (isExpanded) {
                  _expandedDayOverride = null;
                } else {
                  _expandedDayOverride = day;
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(day, style: AppTextStyles.label.copyWith(fontSize: 15)),
                  const Spacer(),
                  if (hasOverride)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Customized',
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary, fontSize: 11)),
                    )
                  else
                    Text('Global Hours',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textHint, fontSize: 12)),
                  const SizedBox(width: 12),
                  Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textHint),
                ],
              ),
            ),
          ),
          
          if (isExpanded) ...[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
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
                                hasBreak: _hasBreak,
                                breakFrom: _breakFrom,
                                breakTo: _breakTo,
                              );
                            } else {
                              _dayOverrides.remove(day);
                            }
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  if (hasOverride) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _timePickerTile(
                            label: 'From',
                            value: _dayOverrides[day]!.workFrom,
                            onTap: () => _pickTime(
                              label: 'From',
                              currentValue: _dayOverrides[day]!.workFrom,
                              onSelect: (t) => _dayOverrides[day]!.workFrom = t,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 18, color: AppColors.textHint),
                        ),
                        Expanded(
                          child: _timePickerTile(
                            label: 'To',
                            value: _dayOverrides[day]!.workTo,
                            onTap: () => _pickTime(
                              label: 'To',
                              currentValue: _dayOverrides[day]!.workTo,
                              onSelect: (t) => _dayOverrides[day]!.workTo = t,
                              minTime: _dayOverrides[day]!.workFrom,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Include Break', style: AppTextStyles.label),
                        Switch(
                          value: _dayOverrides[day]!.hasBreak,
                          onChanged: (v) {
                            FocusScope.of(context).unfocus();
                            setState(() => _dayOverrides[day]!.hasBreak = v);
                          },
                          activeColor: AppColors.warning,
                        ),
                      ],
                    ),
                    if (_dayOverrides[day]!.hasBreak) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _timePickerTile(
                              label: 'Break From',
                              value: _dayOverrides[day]!.breakFrom,
                              isBreak: true,
                              onTap: () => _pickTime(
                                label: 'Break From',
                                currentValue: _dayOverrides[day]!.breakFrom,
                                onSelect: (t) => _dayOverrides[day]!.breakFrom = t,
                                minTime: _dayOverrides[day]!.workFrom,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 18, color: AppColors.textHint),
                          ),
                          Expanded(
                            child: _timePickerTile(
                              label: 'Break To',
                              value: _dayOverrides[day]!.breakTo,
                              isBreak: true,
                              onTap: () => _pickTime(
                                label: 'Break To',
                                currentValue: _dayOverrides[day]!.breakTo,
                                onSelect: (t) => _dayOverrides[day]!.breakTo = t,
                                minTime: _dayOverrides[day]!.breakFrom,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timePickerTile({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
    bool isBreak = false,
  }) {
    final color = isBreak ? AppColors.warning : AppColors.primary;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: value != null
              ? color.withValues(alpha: 0.06)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? color.withValues(alpha: 0.25)
                : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Text(label,
                style: AppTextStyles.caption
                    .copyWith(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(height: 4),
            Text(
              _formatTime(value),
              style: AppTextStyles.label.copyWith(
                color: value != null ? color : AppColors.textHint,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.primary, fontSize: 11)),
      ),
    );
  }

  // ── Treatment Tile ─────────────────────────────────────────
  Widget _buildTreatmentTile(String treatment) {
    final selected = _selectedTreatments[treatment] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.accent.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) {
                  FocusScope.of(context).unfocus();
                  setState(() => _selectedTreatments[treatment] = v ?? false);
                },
                activeColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              Expanded(child: Text(treatment, style: AppTextStyles.label)),
            ],
          ),
          if (selected) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniField(
                      'Duration (min)', _durationControllers[treatment]!),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:
                      _miniField('Fee (₹)', _feeControllers[treatment]!),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(int current, int total) {
    return Row(
      children: List.generate(total, (i) {
        final step = i + 1;
        final isActive = step <= current;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: step < total ? 8 : 0),
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
